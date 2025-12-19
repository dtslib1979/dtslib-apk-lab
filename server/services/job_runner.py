import os
import tempfile
import shutil
from typing import Dict, List, Any
from models import JobRequest, JobStatus, JobResult
from services.google_tts import synthesize_text
from services.packager import create_zip

jobs: Dict[str, Dict[str, Any]] = {}


def create_job(job_id: str, request: JobRequest):
    jobs[job_id] = {
        "status": JobStatus.QUEUED,
        "progress": 0,
        "total": len(request.items),
        "request": request,
        "work_dir": None,
        "zip_path": None,
        "results": []
    }


def get_job(job_id: str) -> Dict[str, Any]:
    return jobs.get(job_id)


def run_job(job_id: str):
    job = jobs.get(job_id)
    if not job:
        return

    job["status"] = JobStatus.PROCESSING
    request: JobRequest = job["request"]
    results: List[JobResult] = []

    work_dir = tempfile.mkdtemp(prefix=f"tts_{job_id}_")
    job["work_dir"] = work_dir

    audio_dir = os.path.join(work_dir, "audio")
    os.makedirs(audio_dir, exist_ok=True)

    for idx, item in enumerate(request.items):
        try:
            if len(item.text) > item.max_chars:
                results.append(JobResult(
                    item_id=item.id,
                    success=False,
                    error=f"Text exceeds max_chars limit: {len(item.text)} > {item.max_chars}"
                ))
            else:
                audio_bytes = synthesize_text(item.text, request.preset)

                filename = f"{item.id}.mp3"
                file_path = os.path.join(audio_dir, filename)
                with open(file_path, "wb") as f:
                    f.write(audio_bytes)

                results.append(JobResult(
                    item_id=item.id,
                    success=True
                ))
        except Exception as e:
            results.append(JobResult(
                item_id=item.id,
                success=False,
                error=str(e)
            ))

        job["progress"] = idx + 1
        job["results"] = results

    try:
        zip_path = create_zip(work_dir, job_id, results)
        job["zip_path"] = zip_path
        job["status"] = JobStatus.COMPLETED
    except Exception as e:
        job["status"] = JobStatus.FAILED
        job["error"] = str(e)


def cleanup_job(job_id: str):
    job = jobs.get(job_id)
    if job and job.get("work_dir"):
        work_dir = job["work_dir"]
        if os.path.exists(work_dir):
            shutil.rmtree(work_dir)
        del jobs[job_id]
