from pydantic import BaseModel
from typing import List, Optional
from enum import Enum


class JobStatus(str, Enum):
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class TTSItem(BaseModel):
    id: str
    text: str
    max_chars: int = 1100


class JobRequest(BaseModel):
    batch_date: str
    preset: str = "neutral"
    items: List[TTSItem]


class JobCreateResponse(BaseModel):
    job_id: str
    status: JobStatus


class JobStatusResponse(BaseModel):
    status: JobStatus
    progress: int
    total: int


class JobResult(BaseModel):
    item_id: str
    success: bool
    error: Optional[str] = None
