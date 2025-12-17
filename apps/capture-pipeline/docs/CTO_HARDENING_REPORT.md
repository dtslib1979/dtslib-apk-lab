# Capture Pipeline — CTO Hardening Report

**Date:** 2025-12-17
**Scope:** Repository lock + secrets hardening
**Target:** `dtslib1979/parksy-logs` (ONLY)

---

## ✅ Changes Applied

### 1. Secrets Removed from Code
| File | Before | After |
|------|--------|-------|
| `lib/main.dart` | `static const apiKey = 'CHANGE_ME'` | `String.fromEnvironment('CAPTURE_API_KEY')` |
| `lib/main.dart` | `static const workerUrl = '...'` | `String.fromEnvironment('WORKER_URL')` |

**Commit:** `fix(capture-pipeline): remove hardcoded secrets, use dart-define injection`

### 2. CI Build Updated
| File | Change |
|------|--------|
| `.github/workflows/build-capture-pipeline.yml` | Added `--dart-define=WORKER_URL` and `--dart-define=CAPTURE_API_KEY` |

**Commit:** `fix(capture-pipeline): inject secrets via dart-define in CI build`

### 3. Documentation Added
| File | Purpose |
|------|---------|
| `docs/SETUP.md` | Complete deployment guide with secrets setup |

**Commit:** `docs(capture-pipeline): add SETUP.md with deployment guide`

---

## ✅ Verification Results

### Repo Mixing Search
| Pattern | Occurrences | Status |
|---------|-------------|--------|
| `dtslib-data-backup` | 0 | ✅ Clean |
| `CHANGE_ME` | 0 | ✅ Removed |
| `Authorization: token` in app | 0 | ✅ Clean |
| `api.github.com` in app | 0 | ✅ Clean |

### Worker Configuration
| Variable | Value | Source |
|----------|-------|--------|
| `REPO_OWNER` | `dtslib1979` | wrangler.toml |
| `REPO_NAME` | `parksy-logs` | wrangler.toml |
| `GITHUB_TOKEN` | (secret) | CI `--var` injection |
| `API_KEY` | (secret) | CI `--var` injection |

### App Configuration
| Variable | Injection Method |
|----------|-----------------|
| `WORKER_URL` | `--dart-define` at build time |
| `CAPTURE_API_KEY` | `--dart-define` at build time |

---

## 📋 Required GitHub Secrets

Before build, set these in Repository Settings → Secrets:

| Secret Name | Description |
|-------------|-------------|
| `CAPTURE_WORKER_URL` | Worker URL (e.g., `https://parksy-capture-worker.xxx.workers.dev`) |
| `CAPTURE_API_KEY` | App → Worker authentication token |
| `CAPTURE_GITHUB_TOKEN` | GitHub PAT with `repo` scope for `parksy-logs` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for Worker deployment |
| `CF_ACCOUNT_ID` | Cloudflare account ID |

---

## 🔒 Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECRETS BOUNDARY                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  GitHub Secrets (encrypted)                                  │
│  ├── CAPTURE_WORKER_URL                                      │
│  ├── CAPTURE_API_KEY                                         │
│  ├── CAPTURE_GITHUB_TOKEN                                    │
│  └── CLOUDFLARE_*                                            │
│                                                              │
│         │                           │                        │
│         ▼                           ▼                        │
│  ┌─────────────┐            ┌─────────────────┐             │
│  │   CI Build  │            │  Worker Deploy  │             │
│  │ --dart-define│           │  wrangler --var │             │
│  └──────┬──────┘            └────────┬────────┘             │
│         │                            │                       │
│         ▼                            ▼                       │
│  ┌─────────────┐            ┌─────────────────┐             │
│  │     APK     │───POST────▶│  CF Worker      │             │
│  │  (no secrets)│  X-API-Key │  (env secrets)  │             │
│  └─────────────┘            └────────┬────────┘             │
│                                      │                       │
│                                      ▼                       │
│                             ┌─────────────────┐             │
│                             │  GitHub API     │             │
│                             │  parksy-logs    │             │
│                             └─────────────────┘             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Done Criteria Checklist

- [x] `dtslib-data-backup` — zero occurrences
- [x] Worker targets ONLY `dtslib1979/parksy-logs`
- [x] App contains no GitHub token/owner/repo strings
- [x] Secrets injected via CI, not in source code
- [x] Documentation complete (SETUP.md)
- [ ] APK builds successfully (pending CI run)

---

## Next Steps

1. **Set GitHub Secrets** — Add all 5 secrets listed above
2. **Trigger Build** — Push or manual workflow dispatch
3. **Deploy Worker** — Run `deploy-capture-worker.yml`
4. **Smoke Test** — Share text from Chrome, verify local + cloud save
