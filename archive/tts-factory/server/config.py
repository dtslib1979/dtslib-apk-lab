"""Configuration module for TTS Factory server."""
import os
import json
import tempfile
from pathlib import Path

# Auth
APP_SECRET = os.getenv("APP_SECRET", "dev-secret-key")

# Google Cloud credentials
GOOGLE_CREDS_JSON = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON", "")

# Limits
MAX_ITEMS = 25
MAX_CHARS = 1100

# Paths
TEMP_DIR = Path(tempfile.gettempdir()) / "tts_factory"
TEMP_DIR.mkdir(exist_ok=True)


def init_google_creds() -> str:
    """Write Google creds JSON to temp file, return path."""
    if not GOOGLE_CREDS_JSON:
        return ""
    
    creds_path = TEMP_DIR / "gcloud_creds.json"
    creds_path.write_text(GOOGLE_CREDS_JSON)
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(creds_path)
    return str(creds_path)
