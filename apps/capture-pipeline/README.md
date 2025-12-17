# Parksy Capture v3.0.0

**Lossless Conversation Capture for LLM Power Users**

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0.0-blue" alt="version">
  <img src="https://img.shields.io/badge/platform-Android-green" alt="platform">
  <img src="https://img.shields.io/badge/flutter-3.24-blue" alt="flutter">
</p>

---

## The Problem

On mobile, copying long LLM conversations **fails silently**.

- Clipboard has memory limits
- Text gets truncated without warning
- You lose parts of the conversation

Most people give up. They screenshot, summarize, or abandon the data.

**Parksy Capture was built for people who didn't.**

---

## The Solution

Android **Share Intent** has no size limit.

Instead of copy-paste, share the conversation directly to Parksy Capture.

```
Select All → Share → Parksy Capture → Done
```

No clipboard. No truncation. No data loss.

---

## Features (v3.0.0)

### Core
| Feature | Description |
|---------|-------------|
| 📥 **Lossless Capture** | Share Intent bypasses clipboard limits |
| 📤 **Re-upload** | Share saved logs back to any LLM app |
| ☁️ **Cloud Backup** | Auto-sync to GitHub (optional) |

### Pro UI (New in v3)
| Feature | Description |
|---------|-------------|
| 🔍 **Search** | Full-text search across all logs |
| ⭐ **Favorites** | Star important conversations |
| 📊 **Stats** | Total logs, size, starred count |
| 👁️ **Preview** | See first 3 lines without opening |
| 🎨 **GitHub Dark Theme** | Professional dark UI |
| 📖 **Onboarding** | First-launch tutorial |
| ⏱️ **Relative Time** | "2h ago" instead of timestamps |
| 🔄 **Sort Options** | By date, size, or name |

---

## App Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Capture** | Share from browser | Auto-save, show status, exit |
| **Browse** | Open app directly | List, search, star, share |
| **Onboarding** | First launch | 3-page tutorial |

---

## Screenshots

```
┌─────────────────────────┐
│  Parksy Capture         │
├─────────────────────────┤
│  Logs: 24  ⭐ 5  1.2MB  │
├─────────────────────────┤
│ 🔍 Search logs...    ⭐ │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 20251217_143052   ⭐ │ │
│ │ ChatGPT discussion  │ │
│ │ about Flutter...    │ │
│ │ 2h ago • 45KB    🗑️ │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 20251217_120815   ☆ │ │
│ │ Claude code review  │ │
│ │ for the new...      │ │
│ │ 5h ago • 12KB    🗑️ │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

---

## Workflow

### Capture (from browser)
```
1. Open LLM web app (ChatGPT, Claude, etc.)
2. Select entire conversation
3. Tap Share
4. Choose "Parksy Capture"
5. ✓ Saved
```

### Re-upload (to continue conversation)
```
1. Open Parksy Capture
2. Find the log (search or browse)
3. Tap to open
4. Tap "Upload to LLM"
5. Choose target app (ChatGPT, Claude, etc.)
6. Paste and continue
```

---

## Technical Architecture

```
┌──────────────────────────────────────────┐
│                 Flutter App              │
├──────────────────────────────────────────┤
│  AppRouter → ShareHandler │ HomeScreen   │
│                           │ LogDetail    │
│                           │ Onboarding   │
├──────────────────────────────────────────┤
│              MethodChannel               │
├──────────────────────────────────────────┤
│            MainActivity.kt               │
│  ┌────────────────────────────────────┐  │
│  │ Share Intent Handler              │  │
│  │ File I/O (MediaStore API)         │  │
│  │ Search (full-text)                │  │
│  │ Metadata (.parksy-meta.json)      │  │
│  │ Stats aggregation                 │  │
│  └────────────────────────────────────┘  │
├──────────────────────────────────────────┤
│           Downloads/parksy-logs/         │
│  ├── ParksyLog_20251217_143052.md       │
│  ├── ParksyLog_20251217_120815.md       │
│  └── .parksy-meta.json                  │
└──────────────────────────────────────────┘
```

---

## File Format

```markdown
---
date: 2025-12-17 14:30:52
source: android-share
---

[Full conversation text here]
```

---

## Cloud Backup (Optional)

Set GitHub secrets for auto-sync:

```
PARKSY_WORKER_URL=https://your-worker.workers.dev
PARKSY_API_KEY=your-secret-key
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | 2025-12 | Pro UI, search, favorites, stats, onboarding |
| 2.1.0 | 2025-12 | Log browser, re-share |
| 2.0.0 | 2025-12 | Cloud backup, crash fixes |
| 1.0.0 | 2025-12 | Initial release |

---

## Who This Is For

- Developers
- Writers  
- Researchers
- Prompt engineers
- Anyone who treats **LLM conversations as data assets**

---

## Philosophy

> When copy-paste fails, capture the entire conversation as a file — and re-upload it anytime.

Most people consume LLM output.  
Parksy Capture is for people who **collect it**.
