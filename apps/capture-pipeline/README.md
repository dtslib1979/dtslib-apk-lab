# Parksy Capture Pipeline v1.0

> Personal use only. No distribution.

## Overview

Android Share Intent를 통해 텍스트를 캡처하고, 로컬 저장 + GitHub 아카이빙을 수행하는 개인용 데이터 파이프라인.

## Features (MVP v1)

1. **Share Intent 수신** — `text/plain` MIME type
2. **Local 저장** — `Download/parksy-logs/ParksyLog_YYYYMMDD_HHmmss.md`
3. **Cloud 저장** — Cloudflare Worker → GitHub Repository
4. **Toast Feedback** — 성공/실패 알림
5. **Auto-finish** — Activity 즉시 종료

## Architecture

```
Android Share Intent
       ↓
   ShareActivity.kt
       ↓
   ┌───────┴───────┐
   ↓               ↓
Local            Cloud
MediaStore       POST → Worker → GitHub
(MUST succeed)   (MAY fail)
```

## Fail-safe Strategy

| Local | Cloud | Feedback |
|-------|-------|----------|
| ✅ | ✅ | "Saved Local & Cloud 🚀" |
| ✅ | ❌ | "Saved Local Only ✅" |
| ❌ | - | "Error! Save Failed ❌" |

## Setup

### 1. Deploy Cloudflare Worker

```bash
cd apps/capture-pipeline/worker
npm install -g wrangler
wrangler login
wrangler secret put GITHUB_TOKEN   # GitHub PAT (repo scope)
wrangler secret put API_KEY        # Any secret string
wrangler deploy
```

Worker URL 예시: `https://parksy-capture-worker.<your-subdomain>.workers.dev`

### 2. Update App Config

`lib/main.dart`에서 Worker URL 설정:
```dart
static const workerUrl = 'https://parksy-capture-worker.YOUR_SUBDOMAIN.workers.dev';
```

### 3. Build & Install APK

GitHub Actions가 자동으로 빌드합니다.

## Constitution Compliance

- §2.2: Debug APK Only ✅
- §2.4: GitHub Actions CI/CD ✅
- §4.4: No Dialog (Auto-save) ✅
- §1.1 Amendment: GitHub Archive 예외 허용

## How to Install

1. Go to [Actions](../../actions) tab
2. Select "Build Capture Pipeline" workflow
3. Download `capture-pipeline-debug` artifact
4. Install APK on Galaxy device

## Repositories

| Repo | Purpose |
|------|---------|
| `dtslib-apk-lab` | App source code |
| `parksy-logs` | Archive storage (private) |

## Known Limitations

- Android 11+ (API 30+) required
- Samsung OneUI tested only
- Network timeout: 5 seconds

## Troubleshooting

- **Permission denied**: Enable "Install unknown apps" for your file manager
- **Network error**: Check internet connection, app will still save locally
- **Cloud save fails**: Check Worker deployment and API_KEY
