"""Job processing logic."""
import csv
import logging
import secrets
import shutil
from pathlib import Path
from typing import Dict, Any
from datetime import datetime

from config import MAX_CHARS, TEMP_DIR
from services.google_tts import GoogleTTS
from services.packager import create_zip

# In-memory job store (stateless per instance)
JOBS: Dict[str, Dict[str, Any]] = {}


def gen_job_id() -> str:
    """Generate unique job ID."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"job_{ts}_{secrets.token_hex(4)}"


def run_job(job_id: str, req: Dict[str, Any]):
    """Process batch TTS job."""
    try:
        items = req["items"]
        preset = req.get("preset", "neutral")
        language = req.get("language", "en")
        total = len(items)

        # Init job state
        JOBS[job_id] = {
            "status": "processing",
            "progress": 0,
            "total": total,
            "error": "",
        }

        # Create work dir
        work_dir = TEMP_DIR / job_id
        audio_dir = work_dir / "audio"
        logs_dir = work_dir / "logs"
        audio_dir.mkdir(parents=True, exist_ok=True)
        logs_dir.mkdir(parents=True, exist_ok=True)

        tts = GoogleTTS()
        results = []

        for i, item in enumerate(items):
            item_id = item["id"]
            text = item["text"]
            char_limit = item.get("max_chars", MAX_CHARS)

            # Check char limit
            if len(text) > char_limit:
                results.append({
                    "id": item_id,
                    "status": "failed",
                    "reason": f"exceeded {char_limit} chars",
                })
                JOBS[job_id]["progress"] = i + 1
                continue

            # Synthesize
            out_path = audio_dir / f"{item_id}.mp3"
            ok = tts.synth(text, preset, language, out_path)

            if ok:
                results.append({"id": item_id, "status": "ok", "reason": ""})
            else:
                results.append({"id": item_id, "status": "failed", "reason": "tts_error"})

            JOBS[job_id]["progress"] = i + 1

        # Write report.csv
        report_path = logs_dir / "report.csv"
        with open(report_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["id", "status", "reason"])
            writer.writeheader()
            writer.writerows(results)

        # Create ZIP
        zip_path = work_dir / f"{job_id}.zip"
        create_zip(work_dir, zip_path)

        JOBS[job_id]["status"] = "completed"
        JOBS[job_id]["zip_path"] = str(zip_path)
    except Exception as e:
        logging.exception(f"Job {job_id} failed: {e}")
        JOBS[job_id] = {
            "status": "failed",
            "progress": 0,
            "total": 0,
            "error": str(e),
        }


def get_job(job_id: str) -> Dict[str, Any]:
    """Get job status."""
    return JOBS.get(job_id, {"status": "not_found"})


def cleanup_job(job_id: str):
    """Remove job files and state."""
    work_dir = TEMP_DIR / job_id
    if work_dir.exists():
        shutil.rmtree(work_dir)
    JOBS.pop(job_id, None)
