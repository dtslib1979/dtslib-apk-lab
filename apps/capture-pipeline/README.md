# Parksy Capture v11.0.0

**Lossless Conversation Capture for LLM Power Users — Now with On-Device AI**

<p align="center">
  <img src="https://img.shields.io/badge/version-11.0.0-blue" alt="version">
  <img src="https://img.shields.io/badge/platform-Android-green" alt="platform">
  <img src="https://img.shields.io/badge/flutter-3.24-blue" alt="flutter">
  <img src="https://img.shields.io/badge/ai-ondevice-brightgreen" alt="on-device AI">
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

Android **Share Intent** bypasses clipboard limits entirely. Share directly → saved as `.md` instantly.

```
Select All → Share → Parksy Capture → Done
```

No clipboard. No truncation. No data loss. **And now: on-device AI search.**

---

## Features (v11.0.0)

### Core
| Feature | Description |
|---------|-------------|
| 📥 **Lossless Capture** | Share Intent bypasses clipboard limits |
| 📤 **Re-upload** | Share saved logs back to any LLM app |
| ☁️ **GitHub Backup** | Auto-sync (optional, no secret required) |

### On-Device AI (New in v11)
| Feature | Description |
|---------|-------------|
| 🧠 **AI Search** | Semantic search via MiniLM L6-v2 embedding (384-dim) |
| 💬 **LLM Q&A** | DeepSeek API powered answers about your logs |
| 🔍 **Hybrid Search** | AI embedding + keyword fallback (offline-safe) |
| 🛠️ **Tools Tab** | JSONL converter, wording profiler, MCP generator |

### UI
| Feature | Description |
|---------|-------------|
| 🔎 **Full-Text Search** | Keyword search across all logs |
| ⭐ **Favorites** | Star important conversations |
| 📊 **Stats** | Total logs, size, starred count |
| 👁️ **Preview** | See first 3 lines without opening |
| 🎨 **GitHub Dark Theme** | Professional dark UI |
| ⏱️ **Relative Time** | "2h ago" instead of timestamps |
| 🔄 **Sort Options** | By date, size, or name |

---

## Technical Architecture

```
┌──────────────────────────────────────────────────┐
│              Parksy Capture APK                    │
├──────────────────────────────────────────────────┤
│                  Flutter (Dart)                    │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │
│  │ Capture  │  │ Browse   │  │ Tools          │  │
│  │ Tab      │  │ Tab      │  │ Tab            │  │
│  │          │  │          │  │ ┌────────────┐ │  │
│  │ Share    │  │ Search   │  │ │JSONL 변환  │ │  │
│  │ 수신     │  │ 목록     │  │ │워딩 프로필 │ │  │
│  │ 저장     │  │ 상세     │  │ │MCP 생성    │ │  │
│  └────┬─────┘  └────┬─────┘  │ │언어 변환   │ │  │
│       │             │        │ └────────────┘ │  │
│       └──────┬──────┘        └────────────────┘  │
│              │                                    │
├──────────────┴────────────────────────────────────┤
│              MethodChannel (Dart ↔ Kotlin)         │
├──────────────────────────────────────────────────┤
│              MainActivity.kt                       │
│  ┌──────────────────────────────────────────┐     │
│  │ Share Intent Handler                     │     │
│  │ File I/O (MediaStore API)                │     │
│  │ Local Text Search (키워드)               │     │
│  │ JSONL Converter                          │     │
│  │ Wording Profiler                         │     │
│  │ onDeviceSearch(query, mode)              │     │
│  │   ├─ Embed Server (8018) → 성공          │     │
│  │   └─ 로컬 텍스트 검색 → fallback         │     │
│  └──────────────────────────────────────────┘     │
├──────────────────────────────────────────────────┤
│         Termux (폰 백그라운드)                     │
│  ┌──────────────┐  ┌────────────────────────┐    │
│  │ Embed Server │  │ MCP Server             │    │
│  │ :8018        │  │ :8015 (Voice TTS)      │    │
│  │              │  │ :8016 (Audio)          │    │
│  │ MiniLM 임베딩 │  │ :8020 (Publish)       │    │
│  │ DeepSeek LLM │  │ :8789 (Webpage)        │    │
│  └──────────────┘  └────────────────────────┘    │
├──────────────────────────────────────────────────┤
│           Downloads/parksy-logs/                  │
│  ├── ParksyLog_YYYYMMDD_HHMMSS.md               │
│  ├── ParksyLog_YYYYMMDD_HHMMSS.md               │
│  └── .parksy-meta.json                           │
└──────────────────────────────────────────────────┘
```

### AI Search Flow

```
User Question
  → Dart: platform.invokeMethod('onDeviceSearch')
  → Kotlin: callMcpSearch(query, mode)
  → HTTP POST localhost:8018/api/tool
  → Embed Server:
       llm_generate → DeepSeek API (클라우드, 한국어 특화)
       embed_search → MiniLM L6-v2 (온디바이스, 384차원)
  → Kotlin: fallback to localTextSearch() if server unavailable
  → Dart: display answer
```

---

## On-Device AI Details

| Component | Model/Tech | Location | Cost |
|-----------|-----------|----------|------|
| **Embedding** | sentence-transformers/all-MiniLM-L6-v2 | Termux (Python) | $0 |
| **LLM** | DeepSeek V3 (deepseek-chat) | Cloud API | ~$0.27/1M tokens |
| **Keyword Search** | Kotlin native (frequency scoring) | APK native | $0 |
| **Cache** | HuggingFace offline (local_files_only) | Termux | $0 |

---

## Tools Tab (v11)

| Tool | Function |
|------|----------|
| **JSONL Converter** | .md → .jsonl (conversation turns → {user/assistant} pairs) |
| **Wording Profiler** | Word frequency, sentence patterns, domain weight analysis |
| **MCP Server Generator** | From conversation profile → custom MCP tool spec |
| **Language Converter** | Conversation → English translation (ML Kit) |

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

## Requirements

- Android 8.0+ (API 26)
- Termux (for AI embedding server)
  - Python 3.13+
  - transformers + torch + aiohttp
  - HuggingFace offline cache (MiniLM)
- DeepSeek API key (for LLM Q&A)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **11.0.0** | 2026-05 | On-device AI (MiniLM+DeepSeek), Tools tab, no cloud APIs |
| 10.0.8 | 2026-05 | MCP integration preparation |
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

> On-device AI isn't just cheaper — it's private, permanent, and always available.

Most people consume LLM output.  
Parksy Capture is for people who **own it**.
