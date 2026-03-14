# parksy-studio 개발 기획문서

> 작성일: 2026-03-14
> 출처: Claude Code 대화 세션에서 취지 정리

---

## 한 줄 정의

**방송 제작 파이프라인 전체를 하나의 APK 안에.**

---

## 공리 (절대 전제)

- **앱 = 생각의 서식** — 엔드 프로덕트 아님. 사고 과정을 구조화하는 도구.
- **배포 = YouTube** — 플레이스토어/SaaS/서버 없음. 화면녹화가 콘텐츠.
- **비용 제로** — 모든 기능 브라우저 런타임 or Android 시스템 API. 서버 없음.
- **브라우저 UI 없음** — 방송 화면에 주소창/탭바 일절 안 보임.

---

## 취지

유튜브 영상 제작 과정에서 브라우저 여러 개, PWA 여러 개, APK 여러 개 전환하는
파편화를 **하나의 앱**으로 통합.

```
cloud-appstore (소재집)  →  parksy-studio APK (런처 + 스튜디오)  →  YouTube
```

---

## 7대 핵심 기능

| # | 기능 | 구현 | 비용 |
|---|------|------|------|
| 1 | 읽어주기 (TTS) | Edge 앱 Intent 연동 | 무료 |
| 2 | 번역 | Chrome WebView 내장 번역 | 무료 |
| 3 | 백그라운드 재생 + PiP | Android MediaSession + ForegroundService | 무료 |
| 4 | 동시통역 | 시스템 오디오 캡처 + Web Speech API + Gemini Nano | 무료 |
| 5 | 영상트리머 | 화면녹화 + 자동크롭 + YouTube 규격화 (Shorts/Long) | 무료 |
| 6 | 배경음악 플레이어 | parksy-audio YouTube URL 채널 연동 | 무료 |
| 7 | 실시간 자막 | 내 목소리 → Web Speech API → 화면 텍스트 | 무료 |

### 영상트리머 상세
```
화면녹화 (내 메뉴바 포함)
        ↓
FFmpeg WASM 자동 처리:
  - 위아래 메뉴바 크롭 제거
  - YouTube Shorts: 1080×1920 (9:16)
  - YouTube Long:   1920×1080 (16:9)
        ↓
규격화 영상 저장 → YouTube 업로드
```
**FOSS 생태계 공백 — 자동크롭 + YouTube 규격화 하는 앱 없음. 독보적.**

### 동시통역 상세
```
어떤 영상 재생 (YouTube, 인터뷰 등)
        ↓
Android AudioPlaybackCaptureConfiguration
        ↓
Web Speech API → 원어 텍스트
        ↓
Gemini Nano → 영어 → 한국어
        ↓
실시간 자막 오버레이
```

### 배경음악 플레이어 상세
```
parksy-audio 제작 음악 → YouTube 업로드
        ↓
parksy-studio에서 URL JSON으로 관리
        ↓
카테고리별 채널 (ambient / instrument / loop / texture)
        ↓
앱 업데이트 없이 곡 추가 가능
```

---

## 개발 판단 기준 (컨트롤 키 5개)

```
1. 반복되는가? → Yes (편집+업로드 매번 반복)
2. 생각을 서식화하는가? → Yes (파이프라인 자체가 서식)
3. YouTube로 보여줄 수 있는가? → Yes (화면녹화 키트가 콘텐츠)
4. 생산자 시간 단축? → Yes (앱 4~5개 전환 → 1개)
5. DHM? → Yes (Delight + Hard-to-copy + 생산성)
```

5/5 통과.

---

## 기술 스택

- **베이스**: Flutter + WebView (바텀업, apk-lab 기존 구조 재활용)
- **엔진**: Android WebView (Chromium)
- **영상처리**: FFmpeg WASM
- **STT**: Web Speech API (무료)
- **번역/AI**: Gemini Nano (온디바이스, 무료)
- **오디오캡처**: AudioPlaybackCaptureConfiguration (Android 10+)
- **미디어**: MediaSession + ForegroundService

F-Droid 조사 결과: 이 기능 조합 가진 앱 없음 → 직접 바텀업 개발.

---

## 레포 위치

```
dtslib-apk-lab/apps/parksy-studio/
├── docs/PLAN.md
├── app/          ← Flutter WebView APK
├── webview/      ← 런처 UI (HTML/JS)
└── .github/workflows/build.yml
```

## upstream / downstream

```
parksy-audio (배경음악 YouTube URL)
cloud-appstore (도구 13개)
        ↓
parksy-studio (런처 + 스튜디오)
        ↓
YouTube (배포)
```

---

## Phase

| Phase | 내용 |
|-------|------|
| 0 | 기획문서 확정 (완료) |
| 1 | Flutter WebView APK 껍데기 (풀스크린, 주소창 없음) |
| 2 | 런처 UI + cloud-appstore 도구 메뉴 |
| 3 | 영상트리머 (화면녹화 + FFmpeg 자동크롭 + YouTube 규격화) |
| 4 | 동시통역 (시스템 오디오 캡처 + Gemini Nano) |
| 5 | 실시간 자막 + TTS + 번역 |
| 6 | 배경음악 플레이어 (parksy-audio 채널) |
| 7 | YouTube 업로드 (OAuth) |
