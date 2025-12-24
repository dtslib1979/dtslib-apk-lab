# MIDI Converter Server

> Cloud Run API for MP3 → MIDI conversion using Basic Pitch

## Deploy

```bash
# Build
docker build -t midi-converter .

# Local test
docker run -p 8080:8080 midi-converter

# Deploy to Cloud Run
gcloud run deploy midi-converter \
  --source . \
  --region asia-northeast3 \
  --allow-unauthenticated \
  --memory 4Gi \
  --cpu 2 \
  --concurrency 1 \
  --set-env-vars GCS_BUCKET=midi-converter-output
```

## API

### Create Job
```
POST /v1/jobs
Content-Type: multipart/form-data
file: <mp3 file>
```

### Get Status
```
GET /v1/jobs/{job_id}
```
