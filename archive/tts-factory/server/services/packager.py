"""ZIP packager for TTS output."""
import zipfile
from pathlib import Path


def create_zip(work_dir: Path, out_path: Path):
    """Create ZIP with audio/ and logs/ structure."""
    audio_dir = work_dir / "audio"
    logs_dir = work_dir / "logs"
    
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        # Add audio files
        if audio_dir.exists():
            for mp3 in audio_dir.glob("*.mp3"):
                zf.write(mp3, f"audio/{mp3.name}")
        
        # Add logs
        if logs_dir.exists():
            for log in logs_dir.iterdir():
                zf.write(log, f"logs/{log.name}")
