"""TTS Factory Server - FastAPI Application."""
from fastapi import FastAPI, Header, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from pathlib import Path

from config import APP_SECRET, init_google_creds
from models import BatchRequest, JobResponse, JobStatus
from services.job_runner import gen_job_id, run_job, get_job, cleanup_job, JOBS

# Init Google credentials on startup
init_google_creds()

app = FastAPI(title="TTS Factory", version="1.0.0")


def verify_secret(x_app_secret: str = Header(...)):
    """Verify app secret header."""
    if x_app_secret != APP_SECRET:
        raise HTTPException(401, "Invalid secret")


@app.post("/v1/jobs", response_model=JobResponse, status_code=202)
async def create_job(
    req: BatchRequest,
    bg: BackgroundTasks,
    x_app_secret: str = Header(...),
):
    """Create new TTS batch job."""
    verify_secret(x_app_secret)
    
    if len(req.items) > 25:
        raise HTTPException(400, "Max 25 items")
    
    job_id = gen_job_id()
    
    # Queue background task
    JOBS[job_id] = {"status": "queued", "progress": 0, "total": len(req.items)}
    bg.add_task(run_job, job_id, req.model_dump())
    
    return JobResponse(job_id=job_id, status="queued")


@app.get("/v1/jobs/{job_id}", response_model=JobStatus)
async def get_job_status(
    job_id: str,
    x_app_secret: str = Header(...),
):
    """Get job status."""
    verify_secret(x_app_secret)
    
    job = get_job(job_id)
    if job.get("status") == "not_found":
        raise HTTPException(404, "Job not found")
    
    return JobStatus(
        status=job["status"],
        progress=job.get("progress", 0),
        total=job.get("total", 0),
        error=job.get("error", ""),
    )


@app.get("/v1/jobs/{job_id}/download")
async def download_job(
    job_id: str,
    x_app_secret: str = Header(...),
):
    """Download completed job as ZIP, then cleanup."""
    verify_secret(x_app_secret)
    
    job = get_job(job_id)
    if job.get("status") == "not_found":
        raise HTTPException(404, "Job not found")
    
    if job.get("status") != "completed":
        raise HTTPException(400, f"Job status: {job.get('status')}")
    
    zip_path = Path(job.get("zip_path", ""))
    if not zip_path.exists():
        raise HTTPException(404, "ZIP not found")
    
    def stream_and_cleanup():
        """Stream ZIP content then cleanup."""
        with open(zip_path, "rb") as f:
            yield from iter(lambda: f.read(8192), b"")
        # Cleanup after stream complete
        cleanup_job(job_id)
    
    return StreamingResponse(
        stream_and_cleanup(),
        media_type="application/zip",
        headers={"Content-Disposition": f"attachment; filename={job_id}.zip"},
    )


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}
