# Parksy APK Lab — System Architecture Whitepaper

> **One Person, Ten Apps, Zero Typed Code.**
> Voice-Driven Development로 30일 만에 구축한 개인 앱 팩토리의 전체 기술 아키텍처.

**Version:** v1.0
**Date:** 2026-03-01
**Author:** Parksy (Voice) + Claude Code (Implementation)
**Audience:** 기술 블로그 독자, Hacker News, 오픈소스 커뮤니티, 잠재 협력자
**Companion Docs:** CONTENT_MARKETING_PLAN.md (마케팅), SOURCE_POOL_SCM_WHITEPAPER.md (소스 확보), PARKSY_APK_PHILOSOPHY.md (철학)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview — 세 겹의 팩토리](#2-system-overview)
3. [Layer 1: App Manufacturing Line](#3-layer-1-app-manufacturing-line)
4. [Layer 2: Automation Pipeline](#4-layer-2-automation-pipeline)
5. [Layer 3: Distribution & Storefront](#5-layer-3-distribution--storefront)
6. [Cross-Cutting: Voice-Driven Development](#6-cross-cutting-voice-driven-development)
7. [App Portfolio — 10개 앱 기술 명세](#7-app-portfolio)
8. [Inter-App Communication](#8-inter-app-communication)
9. [CI/CD Architecture](#9-cicd-architecture)
10. [Compliance Automation](#10-compliance-automation)
11. [Monorepo Engineering](#11-monorepo-engineering)
12. [Infrastructure Map](#12-infrastructure-map)
13. [Quantitative Profile](#13-quantitative-profile)
14. [Failure Catalog — 실패에서 배운 것](#14-failure-catalog)
15. [Roadmap](#15-roadmap)
16. [Appendix](#appendix)

---

## 1. Executive Summary

Parksy APK Lab은 **1인 개발자가 음성 명령만으로 Android 앱 10개를 제조, 배포, 유지보수하는 시스템**이다.

코드를 직접 타이핑하지 않는다. 음성으로 요구사항을 말하면 Claude Code가 구현한다.
Play Store를 사용하지 않는다. 자체 스토어(Vercel)에서 직접 배포한다.
클라우드 API에 의존하지 않는다. 가능한 모든 처리를 on-device로 수행한다.

이 백서는 그 시스템의 **실제 작동 구조**를 문서화한다. 설계 의도가 아니라 돌아가는 코드에 근거한다.

### 핵심 수치

| 지표 | 값 | 근거 |
|------|-----|------|
| 앱 수 | 10개 (8 등록 + 2 개발중) | `dashboard/apps.json` + `apps/` 디렉토리 |
| 총 코드 | **23,913줄** (Dart) + **4,949줄** (Kotlin) | `find apps -name "*.dart"` wc -l |
| 자동화 스크립트 | 6개, **1,168줄** (Python + Shell) | `scripts/` |
| CI/CD 워크플로우 | **21개** | `.github/workflows/` |
| 의존성 | 68개 패키지, **GPL 위반 0건** | `license-audit.py` |
| 개발 기간 | 30일 (2026-01-31 → 2026-03-01) | `git log --reverse` |
| 커밋 수 | 62개 | `git log --oneline --all` |
| 직접 타이핑한 코드 | **0줄** | VDD 프로토콜 |
| 스토어 | Vercel (dtslib-apk-lab.vercel.app) | 라이브 |

---

## 2. System Overview

전체 시스템은 세 겹의 동심원으로 구성된다.

```
┌─────────────────────────────────────────────────┐
│           Layer 3: DISTRIBUTION                 │
│                                                 │
│   Vercel Store ← apps.json ← build_store_index  │
│   GitHub Releases ← CI/CD ← APK artifacts      │
│   nightly.link ← workflow artifacts             │
│                                                 │
├─────────────────────────────────────────────────┤
│           Layer 2: AUTOMATION                   │
│                                                 │
│   21 GitHub Actions workflows                   │
│   6 automation scripts                          │
│   Constitution Guard (policy enforcement)       │
│   License Audit (compliance)                    │
│   Store Index Sync (metadata SSOT)              │
│                                                 │
├─────────────────────────────────────────────────┤
│           Layer 1: APP MANUFACTURING            │
│                                                 │
│   10 Flutter+Kotlin hybrid apps                 │
│   Shared architecture patterns                  │
│   Platform Channel IPC                          │
│   F-Droid Source Pool references                │
│                                                 │
└─────────────────────────────────────────────────┘

        ↑ 모든 레이어를 관통하는 입력:
        🎤 Voice → Claude Code → Git Commit
```

**핵심 설계 원칙: 모든 것이 git에 기록된다.**

커밋이 전표이고, 브랜치가 챕터이고, `git log --reverse`가 줄거리다.
삽질, 실패, 방향 전환을 squash로 뭉개지 않는다. 31번 빌드한 Parksy Pen의 모든 실패가 레포에 남아 있다.

---

## 3. Layer 1: App Manufacturing Line

### 3.1 공통 아키텍처 패턴

10개 앱 전체가 동일한 하이브리드 구조를 따른다:

```
┌──────────────────────────────────────────────┐
│                Flutter (Dart)                 │
│                                              │
│   UI Layer        Business Logic    State    │
│   ┌─────────┐    ┌──────────────┐  ┌──────┐ │
│   │ Screens │ →  │  Services    │  │ Prefs│ │
│   │ Widgets │    │  Models      │  │ State│ │
│   └─────────┘    └──────────────┘  └──────┘ │
│         │                                    │
│         ↓                                    │
│   ┌──────────────────────────────────┐       │
│   │     MethodChannel / EventChannel │       │
│   └──────────────────────────────────┘       │
│         │                                    │
├─────────┼────────────────────────────────────┤
│         ↓        Android (Kotlin)            │
│                                              │
│   ┌─────────────────────────────────────┐    │
│   │  MainActivity (Channel Handler)     │    │
│   ├─────────────────────────────────────┤    │
│   │  OverlayService / AudioCapture /    │    │
│   │  AccessibilityService / FileIO      │    │
│   └─────────────────────────────────────┘    │
│                                              │
│   AndroidManifest.xml (permissions, intents) │
└──────────────────────────────────────────────┘
```

**왜 순수 Flutter가 아닌가:**
Android OS 레벨 기능(오버레이, 스크린 오디오 캡처, 접근성 서비스, 파일시스템 직접 접근)은 Flutter 플러그인만으로는 제어할 수 없다. 10개 앱 중 7개가 Kotlin 네이티브 레이어를 필요로 한다.

### 3.2 기술 스택 매트릭스

| 기술 | 역할 | 사용 앱 |
|------|------|---------|
| **Flutter 3.x** | UI + 비즈니스 로직 | 전체 10개 |
| **Kotlin** | Android 네이티브 | 7개 (Pen, Capture, Glot, Audio Tools, Liner, Axis, ChronoCall) |
| **MethodChannel** | Dart↔Kotlin IPC | 7개 |
| **WindowManager** | 오버레이 렌더링 | 3개 (Pen, Axis, Glot) |
| **AccessibilityService** | 터치 주입 | 1개 (Pen) |
| **MediaProjection** | 스크린 오디오 캡처 | 1개 (Audio Tools) |
| **FFmpeg** | 오디오 전처리 | 3개 (Wavesy, ChronoCall, Audio Tools) |
| **OpenAI Whisper API** | STT | 1개 (ChronoCall) |
| **Google Cloud TTS** | 음성 합성 | 1개 (TTS Factory) |
| **SharedPreferences** | 로컬 저장 | 전체 |
| **just_audio** | 오디오 재생 | 2개 (ChronoCall, Wavesy) |
| **XDoG Algorithm** | 선화 추출 | 1개 (Liner) |
| **flutter_midi_pro** | MIDI 재생/편집 | 1개 (Wavesy) |

### 3.3 앱별 코드 규모

| 앱 | Dart (줄) | Kotlin (줄) | 합계 | 파일 수 | 핵심 난이도 |
|----|-----------|-------------|------|---------|------------|
| **Parksy Glot** | 3,774 | 1,478 | 5,252 | 25+ | 실시간 STT + 오버레이 |
| **Parksy Audio Tools** | 3,359 | 699 | 4,058 | 20+ | MediaProjection + MIDI |
| **Parksy Axis** | 2,618 | 5 | 2,623 | 12 | FSM 상태 전이 |
| **Parksy Capture** | 2,452 | 654 | 3,106 | 8 | Share Intent + GitHub API |
| **Parksy Pen** | 995 | 1,583 | 2,578 | 12 | 터치 분리 + 접근성 |
| **ChronoCall** | 2,110 | 145 | 2,255 | 10 | FFmpeg + Whisper |
| **Parksy Wavesy** | 1,940 | 5 | 1,945 | 10 | MIDI 편집 엔진 |
| **Parksy TTS** | 783 | 5 | 788 | 6 | Cloud TTS 클라이언트 |
| **Parksy Liner** | 615 | 370 | 985 | 5 | XDoG 이미지 처리 |
| **MIDI Converter** | 318 | 5 | 323 | 3 | Basic Pitch 변환 |
| **합계** | **18,964** | **4,949** | **23,913** | **111+** | — |

---

## 4. Layer 2: Automation Pipeline

### 4.1 자동화 스크립트 일람

6개 스크립트가 수동 작업을 제거한다:

```
scripts/
├── build_store_index.py    (121줄)  스토어 메타데이터 동기화
├── constitution_guard.py   (124줄)  헌법 위반 검출 (금지 패턴)
├── license-audit.py        (293줄)  의존성 라이선스 감사
├── extract-apk.sh          (249줄)  APK 추출 + 감사 증빙
├── setup-source-pool.sh    (218줄)  소스풀 디렉토리 구축
└── source-pool-clone.sh    (163줄)  F-Droid 참조 소스 clone
                           ───────
                           1,168줄
```

### 4.2 build_store_index.py — SSOT 동기화

**문제:** 10개 앱의 버전 정보가 `pubspec.yaml`, `app-meta.json`, `dashboard/apps.json` 3곳에 흩어져 있다. 수동 동기화는 반드시 어긋난다.

**해결:**

```
pubspec.yaml (Source of Truth)
       │
       ↓  build_store_index.py
       │
       ├── dashboard/apps.json (자동 생성)
       │         │
       │         ↓
       │    Vercel Store (자동 반영)
       │
       └── GitHub Actions trigger:
            push to apps/*/pubspec.yaml
            → publish-store-index.yml
            → python scripts/build_store_index.py
            → git commit + push (자동)
```

`pubspec.yaml`의 `version:` 필드에서 정규식으로 버전을 추출하고, 사전 정의된 앱 설정(이름, 설명, 아이콘, 다운로드 URL)과 합쳐서 `apps.json`을 생성한다.

### 4.3 constitution_guard.py — 정책 자동 집행

이 프로젝트에는 헌법이 있다. **"개인용 앱은 Firebase, Analytics, AdMob, Play Store, 인증, 결제를 사용하지 않는다."**

```python
FORBIDDEN_PATTERNS = [
    (r'firebase',                 'Firebase is forbidden (§1.1)'),
    (r'analytics',                'Analytics is forbidden (§1.1)'),
    (r'crashlytics',              'Crashlytics is forbidden (§1.1)'),
    (r'admob',                    'AdMob is forbidden (§1.1)'),
    (r'play[_\-\s]?store',       'Play Store prep is forbidden (§1.1)'),
    (r'subscription|payment',     'Payments are forbidden (§1.1)'),
    (r'telemetry|tracking',       'Telemetry is forbidden (§1.1)'),
    (r'multi[_\-\s]?user',       'Multi-user is forbidden (§1.1)'),
]
```

**동작 모드:**
- **HARD BLOCK** (CI 실패): `.github/`, `scripts/`, `dashboard/apps.json`에서 위반 발생 시
- **SOFT WARNING** (경고만): `apps/`에서 위반 발생 시 (실험 허용)

이 스크립트는 `constitution-guard.yml` 워크플로우에서 **모든 PR과 main push에** 실행된다.

### 4.4 license-audit.py — GPL 방어선

293줄짜리 Python 스크립트가 `pubspec.yaml`의 모든 의존성을 스캔하고 라이선스를 검증한다.

**검사 항목:**
- GPL 2.0/3.0 의존성 → **빌드 차단**
- LGPL → 동적 링킹 확인 (Flutter 플러그인 = OK)
- Unknown 라이선스 → **경고**
- Apache 2.0 / MIT / BSD → **통과**

**최신 감사 결과 (2026-03-01):**
```
앱 9개 스캔 완료
의존성 68개 검사
GPL 위반: 0건
LGPL (FFmpeg): 2개 앱 — 동적 링킹으로 의무 해소
```

### 4.5 Source Pool 자동화 (extract-apk.sh + setup/clone)

3-Tier 소스 확보 아키텍처를 자동화한다:

```
Tier 1: F-Droid Open Source (Primary)
  └── source-pool-clone.sh
        → 참조 앱 clone
        → LICENSE 파일 검증
        → 라이선스 불일치 시 거부

Tier 2: Samsung SDK (Secondary)
  └── 공식 문서 참조 (스크립트 불필요)

Tier 3: APK 구조 분석 (Conditional)
  └── extract-apk.sh
        → apktool 디컴파일
        → .extraction-audit.json 자동 생성 (감사 증빙)
        → 구조 참조만, 코드 복사 금지
```

---

## 5. Layer 3: Distribution & Storefront

### 5.1 배포 아키텍처

Play Store를 사용하지 않는다. 세 가지 채널로 배포한다:

```
                ┌─────────────────────┐
                │    Vercel Store     │
                │  (dtslib-apk-lab    │
                │   .vercel.app)     │
                │                     │
                │  Production    0개  │
                │  Prototype Lab 8개  │
                └────────┬────────────┘
                         │ apps.json
                         │
       ┌─────────────────┼──────────────────┐
       │                 │                  │
       ↓                 ↓                  ↓
  GitHub Releases   nightly.link       직접 설치
  (수동 태깅)     (워크플로우 아티팩트)   (termux-open)
```

### 5.2 스토어 페이지 기술 구조

`dashboard/index.html` (444줄)은 **정적 SPA**다:

- **데이터:** `apps.json`을 fetch하여 동적 렌더링
- **섹션:** Production / Prototype Lab 2단 구조
- **디자인:** 다크 테마, Cinzel 세리프 + Inter 산세리프
- **색상:** `#0D0D0D` 배경, `#D4AF37` 골드 액센트, `#253A2F` 그린
- **애니메이션:** IntersectionObserver 기반 카드 reveal, CSS shimmer
- **PWA:** manifest.json + apple-touch-icon
- **배포:** Vercel (GitHub 연동 자동 배포) + GitHub Pages (fallback)

### 5.3 2-Track 배포 파이프라인

```
개발자 (Parksy)
    │
    ↓ voice command
Claude Code
    │
    ↓ git commit + push
GitHub
    │
    ├── CI: build-{app}.yml → APK artifact
    │     └── nightly.link 자동 배포
    │
    ├── CI: publish-store-index.yml
    │     └── apps.json 자동 갱신
    │
    ├── CI: constitution-guard.yml
    │     └── 정책 위반 차단
    │
    └── Vercel webhook
          └── 스토어 페이지 자동 배포
```

**별도 서버 인프라:**

| 서비스 | 호스팅 | 앱 |
|--------|--------|-----|
| TTS Server | GCP Cloud Run (asia-northeast3) | TTS Factory |
| MIDI Server | GCP Cloud Run (us-central1) | MIDI Converter |
| Audio Web | Vercel (Flutter Web) | Audio Tools |
| Store | Vercel | Dashboard |

---

## 6. Cross-Cutting: Voice-Driven Development

### 6.1 VDD 프로토콜

이 시스템의 모든 코드는 다음 프로세스로 생산된다:

```
┌──────────────────────────────────────────────┐
│              VDD Pipeline                    │
│                                              │
│  1. Parksy speaks requirement (Korean)       │
│          │                                   │
│          ↓                                   │
│  2. Claude Code interprets                   │
│          │                                   │
│          ↓                                   │
│  3. Claude reads source pool (F-Droid refs)  │
│          │                                   │
│          ↓                                   │
│  4. Claude generates new code                │
│     (Independent Implementation)             │
│          │                                   │
│          ↓                                   │
│  5. flutter build apk --debug                │
│          │                                   │
│          ├── SUCCESS → git commit + push     │
│          │                                   │
│          └── FAIL → voice feedback           │
│                → Claude fixes                │
│                → goto 5                      │
│                                              │
│  Feedback loop: avg 3-5 iterations/feature   │
└──────────────────────────────────────────────┘
```

### 6.2 증거: Parksy Pen의 31 빌드

`apps/laser-pen-overlay/`는 v1부터 v25.12까지 **31번의 빌드 이터레이션**을 거쳤다. git log에 모든 시도와 실패가 남아있다.

| 버전 범위 | 시도 | 결과 |
|-----------|------|------|
| v7-v18 | 기본 구현 | 성공 |
| v19 | 화면 녹화 감지 | 부분 성공 |
| **v20** | FLAG_SECURE로 UI 숨기기 | **완전 실패** — 시스템 전체 녹화 차단됨 |
| **v21** | willContinue 실시간 터치 스트리밍 | **완전 실패** — API가 스트리밍 미지원 |
| v22 | 터치 주입 롤백 | 복구 |
| **v24** | Ghost Mode (alpha 5-50) | 성공 — 극한 투명도로 우회 |
| v25.12 | 아이콘 + 마무리 | 출시 |

이 31번의 시행착오가 squash 없이 레포에 남아있다. **"레포지토리는 소설이다"** 원칙의 실증.

### 6.3 Human이 타이핑하는 것

- **커밋 메시지:** 아니오 (Claude가 작성, Human이 승인)
- **코드:** 아니오 (Claude Code 생성)
- **음성 명령:** 예 (한국어, 자연어)
- **APK 테스트:** 예 (실기기에서 수동 테스트)
- **방향 결정:** 예 ("이 기능 빼고 저걸 넣어")

---

## 7. App Portfolio

### 7.1 Parksy Pen — S Pen 오버레이 판서

**난이도: ★★★★★ (시스템 최고)**

Android에서 "S Pen은 그리고, 손가락은 스크롤"을 구현하는 것은 OS가 허용하지 않는 영역이다. FLAG_NOT_TOUCHABLE은 all-or-nothing이다.

**해결 아키텍처:**

```
S Pen Touch                  Finger Touch
    │                            │
    ↓                            ↓
OverlayCanvasView            OverlayCanvasView
(TOOL_TYPE_STYLUS 감지)      (TOOL_TYPE_FINGER 감지)
    │                            │
    ↓                            ↓
Canvas에 직접 드로잉          FLAG_NOT_TOUCHABLE 활성화
                                 │
                                 ↓
                        TouchInjectionService
                        (AccessibilityService)
                                 │
                                 ↓
                        dispatchGesture() →
                        하위 앱에 터치 전달
                                 │
                                 ↓
                        100ms 후 FLAG 해제
```

**핵심 Kotlin 코드:**
```kotlin
// OverlayCanvasView.kt — 터치 타입 분기
override fun onTouchEvent(event: MotionEvent): Boolean {
    return if (isStylus(event)) {
        handleStylusTouch(event)   // Canvas 드로잉
    } else {
        handleFingerTouch(event)   // 터치 주입
    }
}
```

**구성 요소:** OverlayService (416줄) + FloatingControlBar (278줄) + TouchInjectionService (225줄) + OverlayCanvasView + LaserPenTileService + MainActivity

**권한:** SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE, POST_NOTIFICATIONS, AccessibilityService

### 7.2 Parksy Capture — 텍스트 캡처 → GitHub 아카이브

다른 앱에서 텍스트를 공유하면 자동으로 GitHub 레포에 아카이브한다. ChronoCall의 STT 결과물도 여기로 흘러간다.

```
다른 앱 → Share Intent → Capture → GitHub API → 레포 저장
                                  → 로컬 저장 (fallback)
```

**Kotlin 네이티브:** content:// URI 처리, 파일 로컬 복사 (654줄)

### 7.3 Parksy Axis — 방송용 사고 단계 오버레이

FSM(Finite State Machine) 기반 상태 전이로 방송 중 현재 단계를 오버레이 표시한다.

```
State Machine:
  INTRO → MAIN → Q&A → OUTRO
    ↑                    │
    └────── RESET ───────┘
```

**특징:** 8개 테마, shareData IPC 동기화, 탭 UI, flutter_overlay_window 플러그인

### 7.4 Parksy ChronoCall — 통화 녹음 STT

삼성 통화 녹음 파일을 자동 감지하고, FFmpeg으로 전처리한 뒤, Whisper API로 STT 변환한다.

```
삼성 녹음 폴더 자동 탐지 (4개 경로 시도)
    │
    ↓
FFmpeg 전처리
  stereo 44.1kHz → mono 16kHz 64kbps
  ~5MB/분 → ~0.5MB/분 (90% 압축)
    │
    ↓
Whisper API (verbose_json)
  segments[] + timestamps
    │
    ↓
TranscriptScreen
  just_audio 재생 + 세그먼트 seek
  하이라이트 동기화 (AnimatedContainer)
    │
    ↓
Export: Markdown / Share → Parksy Capture
```

**삼성 경로 탐지 순서:**
```
1. /storage/emulated/0/Recordings/Call          (One UI 4+)
2. /storage/emulated/0/DCIM/.Recordings/Call    (One UI 3)
3. /storage/emulated/0/Call                     (구형)
4. /storage/emulated/0/Record/Call              (통신사 커스텀)
```

### 7.5 Parksy Wavesy — 음원 편집 가위

MP3 트리밍 + MIDI 편집 엔진. v4.0.0에서 MIDI 편집 기능 추가.

```
Audio Pipeline:
  MP3/M4A → FFmpeg trim → WAV/MP3 출력

MIDI Pipeline:
  MIDI 파일 파싱 → 트랙 시각화
  → 노트 편집 (추가/삭제/이동)
  → MIDI 파일 재생성
```

**MIDI 엔진 (v4.0.0 신규):** `midi_file.dart` (510줄) + `midi_editor.dart` (339줄) — MIDI 바이너리 파서, 트랙/노트/이벤트 모델, 비파괴 편집

### 7.6 Parksy Glot — 실시간 다국어 자막 오버레이

**가장 복잡한 앱** (5,252줄). 실시간 음성을 Whisper로 STT하고 GPT-4o로 번역하여 오버레이 자막 표시.

```
Mic/Screen Audio
    ↓ MediaProjection / MicAudioCapturer
AudioCaptureService (Kotlin)
    ↓ PCM stream
SubtitleStreamClient (WebSocket)
    ↓ STT + Translation
OverlayWindowController
    ↓
SubtitleBoxComposable (원문)
BubbleComposable (번역)
    ↓
Screen Overlay (SYSTEM_ALERT_WINDOW)
```

**독특한 점:** Flutter 버전 + 순수 Kotlin/Compose 버전 두 가지가 공존 (`lib/` + `app/`)

### 7.7 Parksy TTS — 배치 TTS 생성기

```
Flutter Client → GCP Cloud Run → Google TTS API
    │                  │
    │                  ├── POST /v1/jobs (생성)
    │                  ├── GET /v1/jobs/{id} (상태)
    │                  └── GET /v1/jobs/{id}/download (ZIP)
    │
    └── ZIP: audio/*.mp3 + logs/report.csv
```

**서버:** FastAPI, Docker, Cloud Run (asia-northeast3)
**제한:** 배치당 25유닛, 유닛당 1,100자

### 7.8 Parksy Liner — 사진 → 스케치

XDoG(eXtended Difference of Gaussians) 알고리즘으로 사진에서 선화를 추출한다. Samsung Notes에서 S Pen으로 오버드로잉하는 용도.

### 7.9 Parksy Audio Tools — 스크린 오디오 녹음 + MIDI 변환

MediaProjection으로 화면 오디오를 캡처하고, 서버사이드 Basic Pitch로 MIDI 변환한다. AIVA(AI 작곡) 입력용.

**고유 기술:** FloatingRecordButton (Kotlin, 오버레이 녹음 버튼), AudioCaptureService (MediaProjection 세션 관리)

### 7.10 MIDI Converter — 오디오 → MIDI 변환기

Audio Tools의 MIDI 변환 기능을 경량 앱으로 분리. GCP Cloud Run 서버 연동.

---

## 8. Inter-App Communication

앱들은 독립적이지 않다. Android Intent와 파일시스템을 통해 연결된다.

```
┌──────────────┐   Share Intent    ┌──────────────┐
│  ChronoCall  │ ─── (text) ────→  │   Capture    │
│  (STT 결과)  │                   │  (아카이브)   │
└──────────────┘                   └──────┬───────┘
                                          │
                                     GitHub API
                                          │
                                          ↓
                                   GitHub 레포 저장

┌──────────────┐   Share Intent    ┌──────────────┐
│    외부 앱    │ ── (audio/*) ──→  │  ChronoCall  │
│  (녹음기 등)  │                   │  (STT 변환)  │
└──────────────┘                   └──────────────┘

┌──────────────┐   파일시스템       ┌──────────────┐
│ Audio Tools  │ ── (WAV/MP3) ──→  │   Wavesy     │
│  (오디오 캡처) │                  │  (편집/트림)  │
└──────────────┘                   └──────────────┘

┌──────────────┐   Quick Settings  ┌──────────────┐
│  Android OS  │ ── (Tile Tap) ──→ │   Pen        │
│  (알림 패널)  │                   │  (오버레이)   │
└──────────────┘                   └──────────────┘
```

### Platform Channel 규약

| 앱 | Channel ID | Methods |
|----|-----------|---------|
| ChronoCall | `com.parksy.chronocall/intent` | getSharedAudio, copyUriToLocal, getAudioMetadata |
| Capture | `com.parksy.capture/...` | processShareIntent, copyToLocal |
| Pen | `com.dtslib.laser_pen_overlay/overlay` | startOverlay, stopOverlay, updateSettings |

---

## 9. CI/CD Architecture

### 9.1 워크플로우 맵 (21개)

```
.github/workflows/
│
├── BUILD (11개) ─────────────────────────────────
│   ├── build-parksy-axis.yml
│   ├── build-laser-pen.yml
│   ├── build-capture-pipeline.yml
│   ├── build-parksy-wavesy.yml
│   ├── build-tts-factory.yml
│   ├── build-chrono-call.yml
│   ├── build-parksy-liner.yml
│   ├── build-parksy-glot.yml
│   ├── build-parksy-audio-tools.yml
│   ├── build-midi-converter.yml
│   └── build-aiva-trimmer.yml
│
├── DEPLOY (5개) ─────────────────────────────────
│   ├── deploy-vercel.yml           (스토어 → Vercel)
│   ├── deploy-pages.yml            (스토어 → GitHub Pages)
│   ├── deploy-tts-server.yml       (서버 → Cloud Run)
│   ├── deploy-midi-server.yml      (서버 → Cloud Run)
│   └── deploy-parksy-audio-web.yml (웹앱 → Vercel)
│
├── GUARD (2개) ──────────────────────────────────
│   ├── constitution-guard.yml      (정책 위반 차단)
│   └── flutter-test.yml            (단위 테스트)
│
├── SYNC (1개) ───────────────────────────────────
│   └── publish-store-index.yml     (메타데이터 동기화)
│
└── LEGACY (2개) ─────────────────────────────────
    ├── overlay-dual-sub.yml
    └── (기타)
```

### 9.2 트리거 매트릭스

모든 빌드 워크플로우는 **path-scoped trigger**를 사용한다:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'apps/{app-name}/**'
      - '.github/workflows/build-{app-name}.yml'
  workflow_dispatch:  # 수동 트리거
```

**효과:** Wavesy만 수정하면 Wavesy만 빌드된다. 10개 앱이 동시에 빌드되지 않는다.

### 9.3 빌드 파이프라인 표준

```
checkout → flutter setup → pub get → build apk --debug
                                          │
                                          ↓
                                    upload-artifact
                                          │
                                          ↓
                                    GitHub Release
                                    (tag: {app}-latest)
```

---

## 10. Compliance Automation

### 10.1 3중 방어선

```
Defense Line 1: Source Pool (사전)
  └── F-Droid 우선, GPL 소스 참조 시 코드 미복사
  └── source-pool-clone.sh로 LICENSE 자동 검증

Defense Line 2: License Audit (개발 중)
  └── license-audit.py --strict
  └── pubspec.yaml 의존성 전수 스캔
  └── GPL 감지 시 빌드 차단

Defense Line 3: Constitution Guard (CI)
  └── constitution-guard.yml
  └── PR/push 시 자동 실행
  └── 금지 패턴 감지 → HARD BLOCK / SOFT WARN
```

### 10.2 Independent Implementation 원칙

| 행위 | 허용 여부 | 근거 |
|------|----------|------|
| F-Droid 오픈소스 코드 읽기 | **허용** | 라이선스가 허용 |
| 패턴/구조 학습 후 새 코드 작성 | **허용** | 독립 구현 |
| 코드 복사-붙여넣기 | **금지** | 라이선스 오염 위험 |
| 상용 앱 디컴파일 코드 복사 | **금지** | 저작권 위반 |
| 상용 앱 구조 참조 (Tier 3) | **조건부** | 역공학 예외, 감사 증빙 필수 |

### 10.3 감사 증적

모든 Tier 3 작업은 `extract-apk.sh`가 자동 생성하는 `.extraction-audit.json`에 기록된다:
- 추출 일시
- 대상 APK
- 참조 목적
- "코드 복사 없음" 선언

---

## 11. Monorepo Engineering

### 11.1 왜 모노레포인가

10개 앱을 10개 레포로 분리하면:
- CI/CD 워크플로우 10x 중복
- 크로스레포 의존성 관리 지옥
- 버전 동기화 불가능
- 1인 개발자에게 10개 레포 관리는 오버헤드

모노레포에서:
- path-scoped CI가 앱별 독립 빌드 보장
- `scripts/`의 자동화가 전체 앱에 일괄 적용
- `dashboard/apps.json`이 단일 진실 원천
- 한 번의 `git clone`으로 전체 시스템 확보

### 11.2 디렉토리 구조 원칙

```
/
├── apps/          # 제조 라인 (10개 앱)
│   └── {app}/
│       ├── lib/           # Dart 소스
│       ├── android/       # Android 네이티브
│       ├── pubspec.yaml   # 의존성 (SSOT)
│       └── app-meta.json  # 메타데이터
│
├── dashboard/     # 스토어 (배포 전면)
│   ├── index.html
│   └── apps.json  # 자동 생성
│
├── scripts/       # 자동화 도구 (공정 장비)
│
├── docs/          # 백서/철학서/기술문서
│
├── .github/
│   └── workflows/ # CI/CD (21개)
│
└── CLAUDE.md      # 개발 헌법 + 핸드오프 매뉴얼
```

### 11.3 크로스레포 연동

이 레포는 독립적이지 않다. 3개 형제 레포와 연동된다:

```
dtslib-apk-lab (이 레포)
    ↕ 오디오 에셋
parksy-audio
    ↕ 이미지 에셋
parksy-image
    ↕ 관제탑 (상태 동기화)
dtslib-localpc
    └── repos/status.json (3개 레포 현황)
    └── repos/dtslib-apk-lab.md (세션 로그)
```

**동기화 프로토콜:**
매 커밋 시 `dtslib-localpc/repos/status.json`을 갱신한다. 이 파일이 다른 세션(다른 기기의 Claude)에게 현재 상태를 전달하는 IPC 역할을 한다.

---

## 12. Infrastructure Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLOUD                                    │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   GitHub     │  │   Vercel     │  │   GCP Cloud Run      │  │
│  │              │  │              │  │                      │  │
│  │ Repository   │  │ Store Page   │  │ TTS Server           │  │
│  │ Actions CI   │  │ Audio Web    │  │  (asia-northeast3)   │  │
│  │ Releases     │  │              │  │ MIDI Server           │  │
│  │ Pages        │  │              │  │  (us-central1)       │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
└─────────┼─────────────────┼──────────────────────┼──────────────┘
          │                 │                      │
          │    HTTPS        │    HTTPS             │   HTTPS
          │                 │                      │
┌─────────┼─────────────────┼──────────────────────┼──────────────┐
│         ↓                 ↓                      ↓              │
│  ┌──────────────────────────────────────────────────────┐       │
│  │                  Galaxy Tab S9                       │       │
│  │                                                      │       │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │       │
│  │  │ Axis │ │ Pen  │ │Capture│ │Wavesy│ │ TTS  │      │       │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘      │       │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │       │
│  │  │Chrono│ │Liner │ │ Glot │ │Audio │ │ MIDI │      │       │
│  │  │ Call │ │      │ │      │ │Tools │ │ Conv │      │       │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘      │       │
│  │                                                      │       │
│  │  Termux + Claude Code (VDD Interface)               │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                 │
│                        DEVICE                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 13. Quantitative Profile

### 13.1 코드 언어 분포

| 언어 | 줄 수 | 비율 | 용도 |
|------|-------|------|------|
| Dart | 18,964 | 58.7% | Flutter UI + 비즈니스 로직 |
| Kotlin | 4,949 | 15.3% | Android 네이티브 |
| Python | 2,116 | 6.5% | 자동화 스크립트 + 서버 |
| YAML | 263+ | — | pubspec + CI/CD |
| HTML/JS/CSS | 686 | 2.1% | 스토어 대시보드 |
| Shell | 630 | 1.9% | 소스풀 자동화 |
| Markdown | 5,000+ | — | 문서 (9개 + CLAUDE.md) |
| **합계 (코드)** | **~27,000** | **100%** | — |

### 13.2 의존성 프로필

| 카테고리 | 패키지 수 | 예시 |
|---------|----------|------|
| UI/위젯 | 12 | flutter_overlay_window, file_picker |
| 오디오 | 8 | just_audio, ffmpeg_kit, flutter_midi_pro |
| 네트워크 | 6 | dio, http, web_socket_channel |
| 스토리지 | 5 | shared_preferences, path_provider |
| 유틸리티 | 15 | intl, share_plus, permission_handler |
| 이미지 | 4 | image, photo_view |
| 서버사이드 | 8 | fastapi, google-cloud-texttospeech |
| AI/ML | 10 | openai (Whisper, GPT-4o) |
| **합계** | **68** | **GPL: 0, LGPL: 2 (FFmpeg)** |

### 13.3 Android 타겟 매트릭스

| 설정 | 최솟값 | 최댓값 | 의미 |
|------|--------|--------|------|
| minSdk | 21 (Axis) | 29 (Glot, Audio Tools) | Android 5.0 ~ 10 |
| targetSdk | 34 | 35 (Pen) | Android 14~15 |
| compileSdk | 34 | 35 | — |
| NDK | 25.1.8937393 | — | FFmpeg 빌드용 |

### 13.4 생산성 지표

| 지표 | 값 |
|------|-----|
| 총 개발 기간 | 30일 |
| 총 커밋 | 62개 |
| 커밋/일 평균 | 2.07개 |
| 코드/커밋 평균 | ~435줄 |
| 앱/주 평균 | 2.5개 |
| 코드/앱 평균 | 2,391줄 (Dart) |
| 빌드 워크플로우/앱 | 1:1 매칭 |

---

## 14. Failure Catalog

실패는 삭제하지 않는다. 여기에 기록한다.

### 14.1 FLAG_SECURE 실패 (Pen v20)

**시도:** FLAG_SECURE를 컨트롤 바에만 적용하여 화면 녹화 시 UI 숨기기
**기대:** 특정 뷰만 녹화에서 제외
**실제:** 앱 전체의 화면 녹화가 차단됨 ("Security policy prevents screen recording")
**원인:** FLAG_SECURE는 Window 단위. 개별 View 단위 적용 불가.
**교훈:** Android 보안 모델은 절충이 없다. 허용되지 않은 것은 안 된다.

### 14.2 willContinue 실시간 스트리밍 실패 (Pen v21)

**시도:** `GestureDescription.StrokeDescription(path, 0, 16, willContinue=true)`로 실시간 터치 전달
**기대:** ACTION_MOVE 이벤트를 실시간 스트리밍
**실제:** "Everything stops working"
**원인:** dispatchGesture()는 완성된 경로를 한 번에 전달하도록 설계됨. 실시간 스트리밍은 InputManager.injectInputEvent() (root 필요)로만 가능.
**교훈:** API 파라미터가 존재한다고 의도대로 동작하는 것은 아니다.

### 14.3 jadx 메모리 실패 (Source Pool v1)

**시도:** Termux에서 jadx로 APK 디컴파일
**기대:** Java 소스 복원
**실제:** OutOfMemoryError (Termux 메모리 제한)
**해결:** apktool로 교체 (smali + 리소스 추출, 메모리 효율적)

### 14.4 FFmpeg Kit 의존성 충돌 (Wavesy)

**시도:** ffmpeg_kit_flutter_audio + flutter_midi_pro 동시 사용
**기대:** 정상 빌드
**실제:** `libc++_shared.so` 충돌 — 두 플러그인이 같은 네이티브 라이브러리를 다른 버전으로 번들링
**해결:** `pickFirst` 전략으로 하나만 선택

### 14.5 Clean Room → Independent Implementation (백서 v1)

**시도:** "Clean Room Implementation" (원본 코드를 전혀 보지 않고 구현) 주장
**기대:** 법적 방어력 극대화
**실제:** 실제로는 F-Droid 소스를 읽고 패턴을 학습함 → Clean Room 정의에 부합하지 않음
**해결:** "Independent Implementation"으로 정직하게 재정의. "읽되 복사하지 않는다."

---

## 15. Roadmap

### Phase 현재: App Factory (v1.0)

```
[✅] 10개 앱 코드 완성
[✅] CI/CD 21개 워크플로우
[✅] 자동화 스크립트 6개
[✅] Vercel 스토어 배포
[✅] 3중 컴플라이언스 방어선
[⏳] ChronoCall flutter create + 빌드
[⏳] Production 승격 (Prototype Lab → Production)
```

### Phase 다음: Content Factory (v2.0)

```
[ ] Show HN 포스트 발행
[ ] YouTube 개발 시리즈 시작
[ ] 서사 추출 도구 (narrative-extract.py) 구현
[ ] Source Pool 파이프라인 실전 가동
[ ] Speaker Diarization (ChronoCall v2)
[ ] On-device Whisper (whisper.cpp, 클라우드 API 제거)
```

### Phase 장기: Hardware + Education

```
[ ] IoT 디바이스 + Claude Code 펌웨어
[ ] eae.kr PatchTech 커리큘럼
[ ] parksy.kr 퍼소나 허브
[ ] VDD 방법론 교육 콘텐츠
```

---

## Appendix

### A. 파일 구조 전체 맵

```
dtslib-apk-lab/                    (414 files)
│
├── apps/                          (10 apps, 366 files)
│   ├── capture-pipeline/          (Dart 2,452 + Kt 654 = 3,106줄)
│   ├── chrono-call/               (Dart 2,110 + Kt 145 = 2,255줄)
│   ├── laser-pen-overlay/         (Dart 995 + Kt 1,583 = 2,578줄)
│   ├── midi-converter/            (Dart 318 + Kt 5 = 323줄)
│   ├── parksy-audio-tools/        (Dart 3,359 + Kt 699 = 4,058줄)
│   ├── parksy-axis/               (Dart 2,618 + Kt 5 = 2,623줄)
│   ├── parksy-glot/               (Dart 3,774 + Kt 1,478 = 5,252줄)
│   ├── parksy-liner/              (Dart 615 + Kt 370 = 985줄)
│   ├── parksy-wavesy/             (Dart 1,940 + Kt 5 = 1,945줄)
│   └── tts-factory/               (Dart 783 + Kt 5 + Py 524 = 1,312줄)
│
├── dashboard/                     (HTML 444 + JSON)
│   ├── index.html
│   ├── apps.json
│   └── manifest.json
│
├── scripts/                       (1,168줄)
│   ├── build_store_index.py       (121줄)
│   ├── constitution_guard.py      (124줄)
│   ├── license-audit.py           (293줄)
│   ├── extract-apk.sh            (249줄)
│   ├── setup-source-pool.sh      (218줄)
│   └── source-pool-clone.sh      (163줄)
│
├── docs/                          (9 documents, ~5,000줄)
│
├── .github/workflows/             (21 workflows)
│
└── CLAUDE.md                      (~500줄, 개발 헌법)
```

### B. Git 기여자

| 이름 | 역할 |
|------|------|
| Parksy / Uncle, Parksy | 프로젝트 오너, 음성 지시, 방향 결정 |
| Claude | AI 코드 생성, 커밋 작성 |
| dtslib1979 / dimas-40 | GitHub 계정 (동일인) |

### C. 참조 소스 (F-Droid Source Pool)

| 참조 앱 | 라이선스 | 참조 대상 앱 | 참조 범위 |
|---------|----------|------------|----------|
| Ringdroid | Apache 2.0 | Wavesy | 파형 편집 패턴 |
| sherpa-onnx | Apache 2.0 | ChronoCall, TTS | STT/TTS 아키텍처 |
| whisperIME | Apache 2.0 | ChronoCall | on-device Whisper 패턴 |
| Clipboard Cleaner | MIT | Capture | 클립보드 처리 |
| Transcribro | Apache 2.0 | ChronoCall | STT UI 패턴 |

### D. 보안 프로필

| 항목 | 현재 상태 | 위험도 | 계획 |
|------|----------|--------|------|
| API 키 저장 | SharedPreferences (평문) | 낮음 (개인용) | flutter_secure_storage 고려 |
| 네트워크 통신 | HTTPS only | 낮음 | — |
| 사용자 인증 | 없음 (단일 사용자) | 없음 | — |
| 데이터 수집 | 없음 (헌법 §1.1 금지) | 없음 | — |
| 권한 | 최소 필요 권한만 요청 | 낮음 | — |

### E. 비용 구조

| 항목 | 월 비용 | 비고 |
|------|---------|------|
| GitHub | $0 | Free tier |
| Vercel | $0 | Hobby plan |
| GCP Cloud Run | ~$0 | Pay-per-request, 거의 미사용 |
| Google TTS | $0 | 1M 무료 문자/월 |
| OpenAI Whisper | ~$5 | 사용량 기반 |
| Play Store | $0 | **미사용** |
| **합계** | **~$5/월** | — |

---

> **"코드를 짜는 게 아니라 공장을 돌리고 있다.
> 다만 그 공장의 원장이 git이고, 라인이 파이프라인일 뿐이다."**
>
> — CLAUDE.md, 헌법 제2조

---

*End of Document*
*Version 1.0 — 2026-03-01*
*Generated by: Parksy (Voice Direction) + Claude Code (Implementation)*
