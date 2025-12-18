# PARKSY PERSONAL APK CONSTITUTION v1.3

> Personal-use Android APK Development Constitution  
> This document is **legally binding** for all projects in this repository.  
> Any AI agent (Claude, etc.) MUST read and obey this document  
> **BEFORE writing any code.**

---

## 0. GRAND PREMISE (대전제)

- **Target User:** ONLY Parksy (the developer)
- **Purpose:** Personal workflow acceleration
- **This is NOT:**
  - a product
  - a service
  - a startup
  - a portfolio piece
  - a distributable app

> **Success Definition:**  
> *"It works on my phone and saves my time."*

---

## 1. SCOPE LAW — What NOT to Build

### 1.1 Strictly Forbidden (Absolute Prohibitions)

- Login / Signup / Authentication
- ~~Cloud servers, databases, APIs, uploads~~ (See Amendment A1)
- Analytics, telemetry, tracking
- Ads, subscriptions, payments
- Multi-user or multi-device support
- App Store / Play Store preparation
- Feature expansion "just in case"

### 1.2 v1 Success Criteria

- Works reliably on **my Galaxy device(s)**
- Reduces friction in daily use
- Stability always beats feature richness

---

## 2. BUILD LAW — Factory Rules

### 2.1 Source of Truth

- **GitHub repository is the single source of truth**
- Code lives in GitHub
- Builds are produced exclusively by GitHub Actions

### 2.2 Artifact Policy

- **DEBUG APK ONLY**
  - `flutter build apk --debug`
- No keystore
- No release signing
- No store-ready builds unless explicitly ordered

### 2.3 Exception Trigger for Release Signing

Release signing is permitted **only when ALL conditions below are met**:

| # | Condition | Threshold |
|---|-----------|----------|
| 1 | Consecutive install failures | ≥ 3 times |
| 2 | Failure cause | Debug signature rejection |
| 3 | Workaround attempted | ADB install tried and failed |

### 2.4 Mandatory CI/CD

Every app **must include** a workflow file that:
- Triggers on push to main and workflow_dispatch
- Builds DEBUG APK
- Uploads artifact

---

## 3. CLINICAL TRIAL LAW — Testing Reality

### 3.1 Test Subjects

- Test device(s): **my personal Android Galaxy**
- No compatibility matrix
- No emulator obsession

### 3.2 Development Loop

```
1. Modify code
2. Push to GitHub
3. GitHub Actions builds APK
4. Install APK on device
5. Use in real life
6. Record friction
7. Repeat
```

---

## 4. UX LAW — Touch Economy

### 4.1 KPI: Touch Count

- Minimum number of taps to complete a task
- Screens: **1–3 maximum**
- One-handed usage preferred

### 4.2 UI Principles

- Big buttons (**minimum 48dp touch target**)
- High contrast
- No hidden gestures
- No microscopic controls

### 4.3 Automation by Default

- Auto-generated filenames
- Auto-save to default location
- Auto-selected defaults

### 4.4 Dialog Prohibition

- No "Save As"
- No repetitive confirmation dialogs
- No repeated permission explanations (ask once, remember forever)

---

## 5. REALITY LAW — Performance & Failure

### 5.1 Mobile Constraints Are Law

- Large files must be processed via **streaming / chunking**
- Never load entire large assets into RAM
- Long tasks require progress indicators and cancellation

### 5.2 Failure Is Expected

- App crashes must **not corrupt output**
- Temporary files must be cleaned
- Errors must be shown in **human language** (Toasts / Snackbars)

---

## 6. DEPENDENCY LAW — Library Discipline

- Prefer **stable, battle-tested packages**
- Avoid experimental or "clever" architectures
- No over-engineering (Clean Architecture overkill is forbidden)
- Replace broken plugins immediately

---

## 7. DOCUMENTATION LAW — Minimal but Mandatory

Each app must include a `README.md` containing:

- "Personal use only. No distribution."
- Step-by-step instructions to download APK from GitHub Actions
- Known limitations
- Basic troubleshooting

---

## 8. AI HAND-OFF LAW — How to Command Claude

Every instruction to an AI agent **must include**:

1. Repository URL
2. MVP v1 feature list (3–5 items max)
3. Explicit Non-goals list
4. Mandatory Debug APK via GitHub Actions

### Standard Command Phrase

> "Read CONSTITUTION.md first.  
> Implement [FEATURE] in compliance with the Constitution."

---

## 9. VERSION UPGRADE LAW — Evolution Rules

### 9.1 Version Transition Trigger

Upgrade from vN → vN+1 is permitted **only when ALL conditions are met**:

| # | Condition | Evidence Required |
|---|-----------|------------------|
| 1 | Core workflow changed | Written description |
| 2 | vN success criteria met | ≥ 7 days stable daily use |
| 3 | New feature is blocking | Task impossible without it |

### 9.2 Scope Creep Veto

If an upgrade introduces:
- ≥ 3 new screens **OR**
- ≥ 2 new permissions  

→ **REJECTED** → Split into a separate app instead.

---

## 10. STORE SYNC LAW — Version Automation

### 10.1 Single Source of Truth (SSOT)

- **`apps/*/pubspec.yaml` version field is the ONLY truth**
- `dashboard/apps.json` is auto-generated (DO NOT edit manually)
- README에 버전 테이블 금지 (틀어지는 순간 배포 사고)

### 10.2 Auto-Sync Pipeline

```
pubspec.yaml 버전 수정 → git push → publish-store-index.yml → apps.json 자동 갱신 → Vercel 배포
```

### 10.3 Commit Message Convention

```
release(앱이름): x.y.z+build
```

예: `release(capture-pipeline): 5.1.0+12`

---

## 11. HYBRID ENFORCEMENT LAW — Human-in-the-Loop Control

This repository operates under a **Hybrid Enforcement Model**.

The Constitution is enforced by code with **two levels of severity**:
- 🔴 HARD BLOCK (execution must stop)
- 🟡 SOFT WARNING (human decision required)

---

### 11.1 HARD BLOCK ZONES (Absolute Enforcement)

The following paths are **CRITICAL ZONES**.

Any constitutional violation detected in these paths MUST:
- fail CI immediately
- block merge to main
- block deployment

**Critical Paths:**
```
.github/**
scripts/**
dashboard/apps.json
```

These zones protect:
- deployment integrity
- store version correctness
- atomic publishing guarantees

**No AI agent is permitted to bypass this block.**

---

### 11.2 SOFT WARNING ZONES (Advisory Enforcement)

The following paths are **EXPERIMENTAL ZONES**.

Violations detected here MUST:
- raise warnings
- notify the human operator (Parksy)
- request confirmation before promotion to main

**Soft Zones:**
```
apps/**
dashboard/** (except apps.json)
```

AI agents MAY continue working in these zones,
but MUST clearly report:
- which constitutional rule may be violated
- why it might be justified
- what non-goals were preserved

---

### 11.3 Human Decision Gate

Only the human operator (Parksy) may:
- approve a soft-zone violation
- promote changes affecting critical zones
- authorize constitutional amendments

**AI agents MUST surface violations, but MUST NOT self-approve them.**

---

### 11.4 Enforcement Priority

If a change touches BOTH zones in one commit:
→ **HARD BLOCK rules take precedence.**

Mixed commits are strongly discouraged.

---

### 11.5 Forbidden Patterns (Auto-Detected)

```python
FORBIDDEN_PATTERNS = [
    r'firebase',
    r'analytics',
    r'crashlytics',
    r'admob',
    r'play.?store',
    r'app.?store',
    r'login|signup|auth',
    r'subscription|payment',
    r'telemetry|tracking',
    r'multi.?user|multi.?device',
]
```

---

## AMENDMENTS

### Amendment A1 — GitHub Archive Exception (2025-12-14)

**Clause:** §1.1 (Strictly Forbidden)

**Change:** 
- OLD: "Cloud servers, databases, APIs, uploads" (absolute prohibition)
- NEW: GitHub repository archiving is **PERMITTED** for personal data asset purposes

**Scope:**
- GitHub repository write access ONLY
- No external cloud services (AWS, Firebase, etc.)
- No third-party APIs beyond GitHub

---

**END OF CONSTITUTION v1.3**
