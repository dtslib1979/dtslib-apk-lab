import os
import json
import tempfile

APP_SECRET = os.environ.get("APP_SECRET", "")
GOOGLE_APPLICATION_CREDENTIALS_JSON = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON", "")

_credentials_file = None


def init_google_credentials():
    global _credentials_file
    if GOOGLE_APPLICATION_CREDENTIALS_JSON:
        _credentials_file = tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        )
        _credentials_file.write(GOOGLE_APPLICATION_CREDENTIALS_JSON)
        _credentials_file.flush()
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = _credentials_file.name


def get_credentials_path():
    if _credentials_file:
        return _credentials_file.name
    return os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
