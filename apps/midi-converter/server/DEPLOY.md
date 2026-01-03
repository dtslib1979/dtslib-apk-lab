# MIDI Converter Server Deployment

**Cycle 3 - Production Ready**

## Quick Deploy (Cloud Shell)

```bash
cd apps/midi-converter/server
gcloud run deploy midi-converter-prod-uc \
  --source . \
  --region us-central1 \
  --memory 2Gi --cpu 2 \
  --timeout 300s \
  --concurrency 10 \
  --min-instances 0 \
  --max-instances 3 \
  --allow-unauthenticated
```

## GitHub Actions (자동)

Secrets 설정:
- `GCP_PROJECT_ID`
- `GCP_SA_KEY`

## 검증

```bash
curl https://midi-converter-prod-uc.a.run.app/health
# {"status":"ok","version":"1.1.0"}
```

---
*Triggered: 2026-01-03*
