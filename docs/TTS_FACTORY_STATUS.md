# TTS Factory v1.0 — Implementation Status

> Last updated: 2025-12-20

## ✅ Completed (Code Ready)

### Server (apps/tts-factory/server/)
| File | Purpose |
|------|------|
| `main.py` | FastAPI 3 endpoints |
| `config.py` | Env vars + Google auth |
| `models.py` | Pydantic schemas |
| `services/google_tts.py` | TTS adapter |
| `services/job_runner.py` | Batch processor |
| `services/packager.py` | ZIP builder |
| `requirements.txt` | Python deps |
| `Dockerfile` | Cloud Run image |
| `test_local.sh` | Local dev script |
| `test_api.py` | API test suite |

### Client (apps/tts-factory/)
| File | Purpose |
|------|------|
| `lib/main.dart` | Flutter UI |
| `pubspec.yaml` | v1.0.0 |
| `android/` | Gradle config |

### CI/CD (.github/workflows/)
| File | Purpose |
|------|------|
| `build-tts-factory.yml` | Flutter APK build |
| `deploy-tts-server.yml` | Cloud Run deploy |

### Documentation
| File | Purpose |
|------|------|
| `apps/tts-factory/README.md` | App guide |
| `docs/TTS_FACTORY_DEPLOY_GUIDE.md` | GCP setup steps |

---

## ⏳ Pending (Manual GCP Setup)

### 1. Enable APIs
```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  texttospeech.googleapis.com
```

### 2. Create Artifact Registry
```bash
gcloud artifacts repositories create tts-factory \
  --repository-format=docker \
  --location=asia-northeast3
```

### 3. Create Service Accounts

**Deploy SA** (for GitHub Actions):
```bash
gcloud iam service-accounts create tts-factory-deploy
# Add roles: roles/run.admin, roles/artifactregistry.writer, roles/iam.serviceAccountUser
```

**TTS SA** (for API calls):
```bash
gcloud iam service-accounts create tts-factory-api
# Add role: roles/texttospeech.client
```

### 4. GitHub Secrets

| Secret | Source |
|--------|--------|
| `GCP_PROJECT_ID` | `gcloud config get-value project` |
| `GCP_SA_KEY` | Deploy SA JSON key |
| `TTS_APP_SECRET` | `openssl rand -hex 32` |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | TTS SA JSON key |
| `TTS_SERVER_URL` | (after first deploy) |

### 5. First Deploy

1. GitHub → Actions → "Deploy TTS Server to Cloud Run"
2. Run workflow (main branch)
3. Get URL: `gcloud run services describe tts-factory --region=asia-northeast3 --format="value(status.url)"`
4. Add `TTS_SERVER_URL` secret with the URL

### 6. Rebuild APK

After server URL is set, rebuild Flutter APK to include correct server URL.

---

## Architecture

```
[Galaxy Tab] → [Cloud Run] → [Google TTS API]
     │              │
     │              ├─ POST /v1/jobs (create)
     │              ├─ GET /v1/jobs/{id} (status)
     │              └─ GET /v1/jobs/{id}/download (ZIP)
     │
     └─ ZIP: audio/*.mp3 + logs/report.csv
```

## Constraints

- Max 25 units per batch
- Max 1100 chars per unit
- Auto-cleanup after download
- Stateless (no persistent storage)

## Links

- [APK Download](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-tts-factory/main/tts-factory-debug.zip)
- [Dashboard](https://dtslib-apk-lab.vercel.app)
- [Deploy Guide](./TTS_FACTORY_DEPLOY_GUIDE.md)
