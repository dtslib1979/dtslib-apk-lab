"""Pydantic models for TTS Factory API."""
from typing import List, Literal
from pydantic import BaseModel, Field


class TTSItem(BaseModel):
    """Single TTS unit."""
    id: str
    text: str
    max_chars: int = 1100


class BatchRequest(BaseModel):
    """Batch TTS request."""
    batch_date: str
    preset: str = "neutral"
    language: str = "en"
    items: List[TTSItem] = Field(max_length=25)


class JobResponse(BaseModel):
    """Job creation response."""
    job_id: str
    status: str


class JobStatus(BaseModel):
    """Job status response."""
    status: Literal["queued", "processing", "completed", "failed"]
    progress: int = 0
    total: int = 0
    error: str = ""
