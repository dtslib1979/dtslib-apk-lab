import os
import zipfile
from typing import List
from models import JobResult


def create_zip(work_dir: str, job_id: str, results: List[JobResult]) -> str:
    zip_path = os.path.join(work_dir, f"{job_id}.zip")

    audio_dir = os.path.join(work_dir, "audio")
    logs_dir = os.path.join(work_dir, "logs")

    os.makedirs(logs_dir, exist_ok=True)

    report_path = os.path.join(logs_dir, "report.csv")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("item_id,success,error\n")
        for result in results:
            error = result.error.replace(",", ";") if result.error else ""
            f.write(f"{result.item_id},{result.success},{error}\n")

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        if os.path.exists(audio_dir):
            for filename in sorted(os.listdir(audio_dir)):
                file_path = os.path.join(audio_dir, filename)
                zf.write(file_path, f"audio/{filename}")

        zf.write(report_path, "logs/report.csv")

    return zip_path
