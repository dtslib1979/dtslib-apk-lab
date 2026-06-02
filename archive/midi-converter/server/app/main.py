import os
import uuid
import json
import subprocess
import time
import logging
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict
from typing import Optional

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Request
from fastapi.responses import JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import storage

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

app = FastAPI(title="MIDI Converter API", version="1.2.0")

# CORS - allow Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Config
TMP_DIR = Path("/tmp/jobs")
TMP_DIR.mkdir(exist_ok=True)
BUCKET = os.getenv("GCS_BUCKET", "midi-converter-output")
MAX_SIZE = 20 * 1024 * 1024  # 20MB
MAX_DURATION = 240  # 4 min
RATE_LIMIT_WINDOW = 60  # seconds
RATE_LIMIT_MAX = 10  # requests per window

# Simple in-memory rate limiter
rate_limits: dict[str, list[float]] = defaultdict(list)


def check_rate_limit(client_ip: str) -> bool:
    """Return True if under limit, False if exceeded"""
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    
    # Clean old entries
    rate_limits[client_ip] = [
        t for t in rate_limits[client_ip] if t > window_start
    ]
    
    if len(rate_limits[client_ip]) >= RATE_LIMIT_MAX:
        return False
    
    rate_limits[client_ip].append(now)
    return True


def get_client_ip(request: Request) -> str:
    """Get client IP, handling proxies"""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def get_storage():
    return storage.Client()


def job_path(job_id: str) -> Path:
    return TMP_DIR / f"{job_id}.json"


def save_job(job_id: str, data: dict):
    with open(job_path(job_id), "w") as f:
        json.dump(data, f)


def load_job(job_id: str) -> Optional[dict]:
    p = job_path(job_id)
    if not p.exists():
        return None
    with open(p) as f:
        return json.load(f)


def cleanup_job_dir(job_dir: Path):
    """Remove temp job directory"""
    try:
        import shutil
        if job_dir.exists():
            shutil.rmtree(job_dir)
    except Exception as e:
        logger.warning(f"Cleanup failed: {e}")


# === ENDPOINTS ===

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "1.2.0",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/metrics")
async def metrics():
    """Basic metrics for monitoring"""
    job_count = len(list(TMP_DIR.glob("*.json")))
    return {
        "active_jobs": job_count,
        "rate_limit_clients": len(rate_limits),
        "uptime": "healthy"
    }


@app.post("/convert")
async def convert_sync(request: Request, file: UploadFile = File(...)):
    """
    Synchronous MP3→MIDI conversion.
    Returns MIDI file bytes directly.
    """
    client_ip = get_client_ip(request)
    
    # Rate limit check
    if not check_rate_limit(client_ip):
        logger.warning(f"Rate limit exceeded: {client_ip}")
        raise HTTPException(429, "Rate limit exceeded. Try again later.")
    
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
    
    start_time = time.time()
    logger.info(f"Processing job {job_id} from {client_ip}")
    
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
            logger.error(f"FFmpeg failed: {result.stderr.decode()[:200]}")
            raise HTTPException(500, "Audio preprocessing failed")
        
        # Run basic-pitch
        midi_dir.mkdir(exist_ok=True)
        result = subprocess.run([
            "basic-pitch", str(midi_dir), str(wav_path)
        ], capture_output=True, timeout=120)
        
        if result.returncode != 0:
            logger.error(f"Basic Pitch failed: {result.stderr.decode()[:200]}")
            raise HTTPException(500, "MIDI conversion failed")
        
        # Find output MIDI
        midi_files = list(midi_dir.glob("*.mid"))
        if not midi_files:
            raise HTTPException(500, "No MIDI output generated")
        
        midi_path = midi_files[0]
        
        # Read MIDI bytes
        with open(midi_path, "rb") as f:
            midi_bytes = f.read()
        
        # Log success
        elapsed = time.time() - start_time
        logger.info(f"Job {job_id} completed in {elapsed:.2f}s")
        
        # Cleanup
        cleanup_job_dir(job_dir)
        
        # Return MIDI file directly
        return Response(
            content=midi_bytes,
            media_type="audio/midi",
            headers={
                "Content-Disposition": 'attachment; filename="output.mid"',
                "X-Processing-Time": f"{elapsed:.2f}s"
            }
        )
        
    except subprocess.TimeoutExpired:
        cleanup_job_dir(job_dir)
        logger.error(f"Job {job_id} timeout")
        raise HTTPException(504, "Processing timeout")
    except HTTPException:
        cleanup_job_dir(job_dir)
        raise
    except Exception as e:
        cleanup_job_dir(job_dir)
        logger.exception(f"Job {job_id} failed: {e}")
        raise HTTPException(500, "Conversion failed")


# === ASYNC JOB ENDPOINTS ===

@app.post("/v1/jobs")
async def create_job(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...)
):
    client_ip = get_client_ip(request)
    
    if not check_rate_limit(client_ip):
        raise HTTPException(429, "Rate limit exceeded")
    
    if not file.filename.lower().endswith(".mp3"):
        raise HTTPException(400, "Only MP3 files allowed")
    
    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(400, f"File too large. Max {MAX_SIZE // 1024 // 1024}MB")
    
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
    
    background_tasks.add_task(process_job, job_id)
    logger.info(f"Job {job_id} queued from {client_ip}")
    
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
        update_job(job_id, "processing", "preprocess")
        subprocess.run([
            "ffmpeg", "-y", "-i", str(mp3_path),
            "-ar", "22050", "-ac", "1",
            str(wav_path)
        ], check=True, capture_output=True)
        
        update_job(job_id, "processing", "infer")
        midi_dir.mkdir(exist_ok=True)
        subprocess.run([
            "basic-pitch", str(midi_dir), str(wav_path)
        ], check=True, capture_output=True)
        
        midi_files = list(midi_dir.glob("*.mid"))
        if not midi_files:
            raise Exception("No MIDI output")
        midi_path = midi_files[0]
        
        update_job(job_id, "processing", "upload")
        client = get_storage()
        bucket = client.bucket(BUCKET)
        blob_name = f"{job_id}/output.mid"
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(str(midi_path))
        
        update_job(job_id, "processing", "sign")
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(hours=24),
            method="GET"
        )
        
        data = load_job(job_id)
        data["status"] = "done"
        data["stage"] = "complete"
        data["result"] = {
            "download_url": url,
            "expires_at": (datetime.utcnow() + timedelta(hours=24)).isoformat(),
            "content_type": "audio/midi"
        }
        save_job(job_id, data)
        logger.info(f"Job {job_id} completed")
        
    except Exception as e:
        data = load_job(job_id)
        data["status"] = "error"
        data["error"] = {"code": "processing_failed", "message": str(e)}
        save_job(job_id, data)
        logger.error(f"Job {job_id} failed: {e}")


def update_job(job_id: str, status: str, stage: str):
    data = load_job(job_id)
    data["status"] = status
    data["stage"] = stage
    save_job(job_id, data)
