import os
import uuid
import json
import asyncio
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from io import BytesIO

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse, Response
from google.cloud import storage

app = FastAPI(title="MIDI Converter API", version="1.1.0")

# Config
TMP_DIR = Path("/tmp/jobs")
TMP_DIR.mkdir(exist_ok=True)
BUCKET = os.getenv("GCS_BUCKET", "midi-converter-output")
MAX_SIZE = 20 * 1024 * 1024  # 20MB
MAX_DURATION = 240  # 4 min


def get_storage():
    return storage.Client()


def job_path(job_id: str) -> Path:
    return TMP_DIR / f"{job_id}.json"


def save_job(job_id: str, data: dict):
    with open(job_path(job_id), "w") as f:
        json.dump(data, f)


def load_job(job_id: str) -> dict:
    p = job_path(job_id)
    if not p.exists():
        return None
    with open(p) as f:
        return json.load(f)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.1.0"}


# =============================================================================
# SYNC ENDPOINT: /convert - Direct MIDI response (for parksy-audio-tools app)
# =============================================================================
@app.post("/convert")
async def convert_sync(file: UploadFile = File(...)):
    """
    Synchronous MP3→MIDI conversion.
    Returns MIDI file bytes directly.
    Used by parksy-audio-tools Flutter app.
    """
    # Validate file type
    if not file.filename.lower().endswith(".mp3"):
        raise HTTPException(400, "Only MP3 files allowed")
    
    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(400, f"File too large. Max {MAX_SIZE // 1024 // 1024}MB")
    
    # Create temp workspace
    job_id = str(uuid.uuid4())
    job_dir = TMP_DIR / job_id
    job_dir.mkdir(exist_ok=True)
    
    mp3_path = job_dir / "input.mp3"
    wav_path = job_dir / "input.wav"
    midi_dir = job_dir / "output"
    
    try:
        # Save uploaded MP3
        with open(mp3_path, "wb") as f:
            f.write(content)
        
        # Convert MP3 → WAV (22050Hz mono for basic-pitch)
        result = subprocess.run([
            "ffmpeg", "-y", "-i", str(mp3_path),
            "-ar", "22050", "-ac", "1",
            str(wav_path)
        ], capture_output=True, timeout=60)
        
        if result.returncode != 0:
            raise HTTPException(500, f"FFmpeg failed: {result.stderr.decode()[:200]}")
        
        # Run basic-pitch
        midi_dir.mkdir(exist_ok=True)
        result = subprocess.run([
            "basic-pitch", str(midi_dir), str(wav_path)
        ], capture_output=True, timeout=120)
        
        if result.returncode != 0:
            raise HTTPException(500, f"Basic Pitch failed: {result.stderr.decode()[:200]}")
        
        # Find output MIDI
        midi_files = list(midi_dir.glob("*.mid"))
        if not midi_files:
            raise HTTPException(500, "No MIDI output generated")
        
        midi_path = midi_files[0]
        
        # Read MIDI bytes
        with open(midi_path, "rb") as f:
            midi_bytes = f.read()
        
        # Cleanup
        cleanup_job_dir(job_dir)
        
        # Return MIDI file directly
        return Response(
            content=midi_bytes,
            media_type="audio/midi",
            headers={
                "Content-Disposition": f'attachment; filename="output.mid"'
            }
        )
        
    except subprocess.TimeoutExpired:
        cleanup_job_dir(job_dir)
        raise HTTPException(504, "Processing timeout")
    except HTTPException:
        cleanup_job_dir(job_dir)
        raise
    except Exception as e:
        cleanup_job_dir(job_dir)
        raise HTTPException(500, f"Conversion failed: {str(e)}")


def cleanup_job_dir(job_dir: Path):
    """Remove temp job directory"""
    try:
        import shutil
        if job_dir.exists():
            shutil.rmtree(job_dir)
    except:
        pass


# =============================================================================
# ASYNC ENDPOINTS: /v1/jobs - Job-based async processing
# =============================================================================
@app.post("/v1/jobs")
async def create_job(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...)
):
    # Validate
    if not file.filename.lower().endswith(".mp3"):
        raise HTTPException(400, "Only MP3 files allowed")
    
    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(400, f"File too large. Max {MAX_SIZE // 1024 // 1024}MB")
    
    # Create job
    job_id = str(uuid.uuid4())
    job_dir = TMP_DIR / job_id
    job_dir.mkdir(exist_ok=True)
    
    mp3_path = job_dir / "input.mp3"
    with open(mp3_path, "wb") as f:
        f.write(content)
    
    job_data = {
        "job_id": job_id,
        "status": "queued",
        "stage": "upload",
        "created_at": datetime.utcnow().isoformat(),
        "filename": file.filename
    }
    save_job(job_id, job_data)
    
    # Start processing
    background_tasks.add_task(process_job, job_id)
    
    return JSONResponse(job_data)


@app.get("/v1/jobs/{job_id}")
async def get_job(job_id: str):
    data = load_job(job_id)
    if not data:
        raise HTTPException(404, "Job not found")
    return data


async def process_job(job_id: str):
    job_dir = TMP_DIR / job_id
    mp3_path = job_dir / "input.mp3"
    wav_path = job_dir / "input.wav"
    midi_dir = job_dir / "output"
    
    try:
        # Stage: preprocess
        update_job(job_id, "processing", "preprocess")
        subprocess.run([
            "ffmpeg", "-y", "-i", str(mp3_path),
            "-ar", "22050", "-ac", "1",
            str(wav_path)
        ], check=True, capture_output=True)
        
        # Stage: infer
        update_job(job_id, "processing", "infer")
        midi_dir.mkdir(exist_ok=True)
        subprocess.run([
            "basic-pitch", str(midi_dir), str(wav_path)
        ], check=True, capture_output=True)
        
        # Find output midi
        midi_files = list(midi_dir.glob("*.mid"))
        if not midi_files:
            raise Exception("No MIDI output")
        midi_path = midi_files[0]
        
        # Stage: upload to GCS
        update_job(job_id, "processing", "upload")
        client = get_storage()
        bucket = client.bucket(BUCKET)
        blob_name = f"{job_id}/output.mid"
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(str(midi_path))
        
        # Stage: sign URL
        update_job(job_id, "processing", "sign")
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(hours=24),
            method="GET"
        )
        
        # Done
        data = load_job(job_id)
        data["status"] = "done"
        data["stage"] = "complete"
        data["result"] = {
            "download_url": url,
            "expires_at": (datetime.utcnow() + timedelta(hours=24)).isoformat(),
            "content_type": "audio/midi"
        }
        save_job(job_id, data)
        
    except Exception as e:
        data = load_job(job_id)
        data["status"] = "error"
        data["error"] = {"code": "processing_failed", "message": str(e)}
        save_job(job_id, data)


def update_job(job_id: str, status: str, stage: str):
    data = load_job(job_id)
    data["status"] = status
    data["stage"] = stage
    save_job(job_id, data)
