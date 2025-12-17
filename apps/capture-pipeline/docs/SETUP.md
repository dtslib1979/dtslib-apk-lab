# Parksy Capture — Setup Guide

Personal-use LLM conversation capture pipeline.
Bypasses Android clipboard limits via Share Intent.

---

## What This Does

1. **Share text** from any app (Chrome, Claude, ChatGPT)
2. **Local save** → `Downloads/parksy-logs/ParksyLog_YYYYMMDD_HHmmss.md`
3. **Cloud archive** → `dtslib1979/parksy-logs/logs/YYYY/MM/DD/*.md` (optional)

---

## Prerequisites

### 1. GitHub Repository
- Create private repo: `parksy-logs`
- This stores cloud-archived conversations

### 2. Cloudflare Worker
- Worker name: `parksy-capture-worker`
- Deployed via GitHub Actions

### 3. GitHub Secrets (Repository Settings → Secrets)

| Secret Name | Description |
|------------|-------------|
| `CAPTURE_WORKER_URL` | `https://parksy-capture-worker.<account>.workers.dev` |
| `CAPTURE_API_KEY` | Random string for app → worker auth |
| `CAPTURE_GITHUB_TOKEN` | GitHub PAT with `repo` scope for parksy-logs |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `CF_ACCOUNT_ID` | Cloudflare account ID |

---

## Build APK

### Option A: GitHub Actions (Recommended)
1. Push to main → auto-builds
2. Download from Actions → Artifacts

### Option B: Local Build
```bash
cd apps/capture-pipeline
flutter build apk --debug \
  --dart-define=WORKER_URL=https://your-worker.workers.dev \
  --dart-define=CAPTURE_API_KEY=your-api-key
```

---

## Install & Test

### 1. Install APK
- Download from GitHub Actions artifact
- `adb install app-debug.apk` or direct install

### 2. Grant Permissions
- First share will request storage permission
- Allow "Parksy Capture" to save files

### 3. Smoke Test

**Test 1: Chrome Share**
1. Open Chrome → select text
2. Tap Share → Parksy Capture
3. Wait for toast: "Saved Local ✅" or "Saved Local & Cloud 🚀"
4. Check `Downloads/parksy-logs/` for file

**Test 2: Text Selection (PROCESS_TEXT)**
1. Long-press text in any app
2. Tap "..." → Parksy Capture
3. Verify toast + file saved

**Test 3: Cloud Archive**
1. After successful share with cloud
2. Check `parksy-logs` repo → `logs/YYYY/MM/DD/`
3. Verify markdown file exists

---

## Architecture

```
┌─────────────┐     Share      ┌────────────────┐
│  Any App    │───Intent───────▶│ Parksy Capture │
│ (Chrome...)  │               │    (Android)    │
└─────────────┘               └────────┬───────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  │                  ▼
           ┌───────────────┐           │         ┌───────────────┐
           │  LOCAL SAVE   │           │         │  CLOUD SAVE   │
           │  Downloads/   │           │         │  CF Worker →  │
           │  parksy-logs/ │           │         │  GitHub API   │
           └───────────────┘           │         └───────────────┘
                                       ▼
                              ┌─────────────────┐
                              │  Toast + Exit   │
                              │    (2 sec)      │
                              └─────────────────┘
```

---

## File Format

```markdown
---
date: 2025-12-17 20:04:02
source: android-share
---

[Your captured text here]
```

---

## Troubleshooting

### "Saved Local Only" (no cloud)
- Check Worker URL configured in build
- Check CAPTURE_API_KEY matches Worker secret
- Check Worker deployed successfully

### "Save Failed"
- Grant storage permission to app
- Check Android 10+ scoped storage compatibility

### No file in Downloads
- Check `Downloads/parksy-logs/` folder
- File naming: `ParksyLog_YYYYMMDD_HHmmss.md`

---

## Security Notes

- **No secrets in APK**: All keys injected at build time
- **Worker-only GitHub access**: App never touches GitHub directly
- **Local-first**: Cloud failure doesn't block local save
- **Private repo**: `parksy-logs` should be private

---

## Related Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Flutter UI + share handler |
| `android/.../MainActivity.kt` | Native share intent + file save |
| `worker/src/worker.js` | Cloudflare Worker → GitHub |
| `worker/wrangler.toml` | Worker config (repo targets) |
