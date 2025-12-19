import uuid
from datetime import datetime
from fastapi import FastAPI, Header, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from config import APP_SECRET, init_google_credentials
from models import JobRequest, JobCreateResponse, JobStatusResponse, JobStatus
from services.job_runner import create_job, get_job, run_job, cleanup_job

init_google_credentials()

app = FastAPI(title="TTS Factory", version="1.0")

MAX_ITEMS = 25


def verify_secret(x_app_secret: str = Header(...)):
    if x_app_secret != APP_SECRET:
        raise HTTPException(status_code=401, detail="Invalid app secret")


@app.post("/v1/jobs", response_model=JobCreateResponse, status_code=202)
async def create_tts_job(
    request: JobRequest,
    background_tasks: BackgroundTasks,
    x_app_secret: str = Header(...)
):
    verify_secret(x_app_secret)

    if len(request.items) > MAX_ITEMS:
        raise HTTPException(
            status_code=400,
            detail=f"Maximum {MAX_ITEMS} items allowed per batch"
        )

    timestamp = datetime.now().strftime("%Y%m%d")
    short_id = uuid.uuid4().hex[:4]
    job_id = f"job_{timestamp}_{short_id}"

    create_job(job_id, request)
    background_tasks.add_task(run_job, job_id)

    return JobCreateResponse(job_id=job_id, status=JobStatus.QUEUED)


@app.get("/v1/jobs/{job_id}", response_model=JobStatusResponse)
async def get_job_status(job_id: str, x_app_secret: str = Header(...)):
    verify_secret(x_app_secret)

    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    return JobStatusResponse(
        status=job["status"],
        progress=job["progress"],
        total=job["total"]
    )


@app.get("/v1/jobs/{job_id}/download")
async def download_job(job_id: str, x_app_secret: str = Header(...)):
    verify_secret(x_app_secret)

    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job["status"] != JobStatus.COMPLETED:
        raise HTTPException(status_code=400, detail="Job not completed")

    zip_path = job.get("zip_path")
    if not zip_path:
        raise HTTPException(status_code=404, detail="ZIP file not found")

    def iter_file():
        with open(zip_path, "rb") as f:
            while chunk := f.read(8192):
                yield chunk
        cleanup_job(job_id)

    return StreamingResponse(
        iter_file(),
        media_type="application/zip",
        headers={"Content-Disposition": f"attachment; filename={job_id}.zip"}
    )


@app.get("/health")
async def health_check():
    return {"status": "ok"}
