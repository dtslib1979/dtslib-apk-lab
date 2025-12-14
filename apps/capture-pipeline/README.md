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

## Known Limitations

- Android 11+ (API 30+) required
- Samsung OneUI tested only
- Network timeout: 5 seconds

## Troubleshooting

- **Permission denied**: Enable "Install unknown apps" for your file manager
- **Network error**: Check internet connection, app will still save locally
