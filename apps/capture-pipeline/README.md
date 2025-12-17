# Parksy Capture

**Lossless Conversation Capture for Web-based LLMs (Mobile-first)**

---

## Why Parksy Capture Exists

On desktop, this problem doesn't exist.

You can select everything.
You can copy everything.
You can save it, upload it, or archive it however you want.

On mobile, especially Android, it does.

---

## The Real Problem

- LLM mobile apps **do not allow full conversation export**
- Many users switch to **mobile web browsers** to select entire conversations
- But even in browsers:
  - Copying long conversations **fails silently**
  - Text gets **truncated due to clipboard size limits**
  - You lose parts of the conversation without warning

This makes **long LLM conversations effectively non-exportable on mobile**.

Most people give up.
They screenshot, summarize, or abandon the data.

Parksy Capture was built by someone who didn't.

---

## What Parksy Capture Does

**Parksy Capture bypasses the clipboard entirely.**

Instead of relying on copy-paste, it uses Android's **Share Intent**, which is not constrained by clipboard memory limits.

### Workflow

1. Select the full conversation in a mobile web browser
   (ChatGPT, Claude, Gemini, etc.)
2. Tap **Share**
3. Choose **Parksy Capture**
4. The conversation is saved **exactly as selected**:
   - 📱 Locally as a `.txt` or `.md` file
   - ☁️ Automatically archived to a **private GitHub repository**

No trimming.
No summarization.
No data loss.

---

## Key Features

- **Lossless conversation capture**
- **Clipboard-free architecture**
- **Share → File → Archive** in one step
- **Local + Cloud (GitHub) backup**
- Optimized for **web-based LLM usage on mobile**
- **Zero-UI workflow** (no app interaction required)

---

## What Makes This Different

There are apps that:
- Save shared text to a file
- Manage clipboards
- Store notes
- Act as LLM frontends

There are **no apps** that intentionally target the intersection of:

- Clipboard limit bypass
- Full LLM conversation preservation
- File-based archiving
- Future ML / RAG reuse

**Parksy Capture is built specifically for that intersection.**

---

## Competitive Landscape (Summary)

| Category | Existing Solutions | Limitations |
|--------|-------------------|-------------|
| Text file savers | Save to File, Text File Creator | Local-only, no structured archiving, no GitHub |
| Clipboard managers | Clipboard Manager, Clipper | Still limited by clipboard memory |
| Note apps | Google Keep, Obsidian Share | Saves notes, not raw data files |
| LLM apps | ChatGPT, Claude | No full conversation export on mobile |

---

## Core Technical Insight (USP)

> **Android Share Intents are not bound by clipboard memory limits.**

This is a technical blind spot most users (and many developers) never exploit.

Parksy Capture is built entirely around this insight.

---

## What Parksy Capture Is NOT

- ❌ Not an AI app
- ❌ Not a summarizer
- ❌ Not a note-taking service
- ❌ Not a consumer productivity app
- ❌ Not a commercial SaaS

This is a **workflow utility for heavy LLM users**.

---

## Who This Is For

- Developers
- Writers
- Researchers
- Prompt engineers
- Anyone who treats **LLM conversations as data assets**

If you've ever thought:
> "I need this entire conversation later."

This tool is for you.

---

## One-Line Definition

> **When copy-paste fails, capture the entire conversation as a file.**

---

## Status

- Private-first utility
- Built for personal workflows
- Public repository for those who understand the problem
- Designed for long-term archiving and future machine-learning pipelines

---

## Philosophy

Most people consume LLM output.

Parksy Capture is for people who **collect it**.
