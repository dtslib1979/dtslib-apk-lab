# Parksy Capture — Setup Guide

LLM 대화 캡처 앱. Share Intent로 클립보드 제한 우회.

---

## What It Does

1. 앱에서 텍스트 Share → Parksy Capture
2. **로컬 저장** → `Downloads/parksy-logs/*.md` (항상)
3. **클라우드 아카이브** → `parksy-logs` repo (설정 시)

---

## Required Secrets (GitHub Repo Settings)

| Secret Name | Description |
|-------------|-------------|
| `PARKSY_WORKER_URL` | Cloudflare Worker URL |
| `PARKSY_API_KEY` | App ↔ Worker 인증 토큰 |
| `CAPTURE_GITHUB_TOKEN` | GitHub PAT (`repo` scope) |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API 토큰 |
| `CF_ACCOUNT_ID` | Cloudflare 계정 ID |

---

## Deploy Worker

```bash
cd apps/capture-pipeline/worker
wrangler login
wrangler secret put API_KEY        # PARKSY_API_KEY와 동일 값
wrangler secret put GITHUB_TOKEN   # CAPTURE_GITHUB_TOKEN 값
wrangler deploy
```

Worker URL: `https://parksy-capture-worker.<account>.workers.dev`

---

## CI Build (How It Works)

```yaml
flutter build apk --debug \
  --dart-define=PARKSY_WORKER_URL=${{ secrets.PARKSY_WORKER_URL }} \
  --dart-define=PARKSY_API_KEY=${{ secrets.PARKSY_API_KEY }}
```

- Secrets는 빌드 시점에만 주입됨
- APK에 하드코딩된 URL/Key 없음
- Secret leak guard가 빌드 전 검사

---

## Phone Test Checklist

### Test 1: Chrome Share
1. Chrome에서 텍스트 선택
2. Share → Parksy Capture
3. Toast 확인: "Saved locally ✅" 또는 "Saved Local & Cloud 🚀"
4. `Downloads/parksy-logs/` 확인

### Test 2: Samsung Notes / 다른 앱
1. 텍스트 길게 눌러 선택
2. ... → Parksy Capture
3. Toast + 파일 저장 확인

### Test 3: Cloud (설정 완료 시)
1. Share 후 "Saved Local & Cloud 🚀" 확인
2. `parksy-logs` repo → `logs/YYYY/MM/` 확인

---

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| "Saved locally ✅" (cloud 없음) | Secrets 미설정 | Repo Secrets 설정 후 재빌드 |
| "Save Failed ❌" | 권한 미부여 | 앱에 저장소 권한 허용 |
| APK 설치 안됨 | Debug 서명 문제 | `adb install -r app-debug.apk` |

---

## File Structure

```
apps/capture-pipeline/
├── lib/main.dart           # Flutter UI + Share handler
├── android/.../MainActivity.kt  # Native file save
├── worker/src/worker.js    # Cloudflare Worker
└── docs/SETUP.md           # This file
```
