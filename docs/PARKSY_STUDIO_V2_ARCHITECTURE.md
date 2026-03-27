# Parksy Studio v2.0 — 시스템 아키텍처 확정판

> 확정일: 2026-03-27
> 설계: 박씨 + Claude Code
> 분류: 내부 아키텍처 문서

---

## 한 줄 선언

**태블릿은 4채널 입력 단말기다. PC가 방송국이다. 편집은 없다.**

---

## OS 경계별 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  INFRA — mosh (UDP resilient) · Tailscale WireGuard Mesh VPN · BIOS Server  │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐
│  ANDROID  SM-X716N  Tab S9 FE    │
│                                  │
│  ┌──────────────┐                │
│  │ 인터랙티브   │  ← ADB intent  │
│  │ 웹페이지     │    URL open    │
│  └──────────────┘                │
│  ┌──────────────┐                │
│  │ Parksy Pen   │  ← S펜 판서   │
│  │ 오버레이     │    (직접)      │
│  └──────────────┘                │
│  ┌──────────────┐                │
│  │ Axis 상황판  │  ← 탭 직접    │
│  │ 오버레이     │                │
│  └──────────────┘                │
│         │                        │
│    ADB/TCP over Tailscale VPN    │
└─────────┼────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  WINDOWS HOST                                                               │
│                                                                             │
│  AUDIO CHAIN                           VIDEO CHAIN                         │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────┐   │
│  │ Shure MV88+ (XLR Condenser)      │  │ scrcpy                       │   │
│  │      ↓ XLR                       │  │ ADB Mirror Window            │   │
│  │ Focusrite Scarlett (USB IF)       │  └──────────────┬───────────────┘   │
│  │      ↓ USB                       │                 │ GDI Window        │
│  │ REAPER DAW                       │                 │                   │
│  │  Gate → EQ → Comp                │                 ▼                   │
│  │  De-ess → Limiter                │  ┌──────────────────────────────┐   │
│  │      ↓ WDM                       │  │  FFmpeg — Mux & Encode       │   │
│  │ VB-Cable (Virtual Audio Device)  │  │                              │   │
│  └──────────────┬───────────────────┘  │  ① DirectShow Video          │   │
│                 │ DirectShow           │     (scrcpy Window)          │   │
│                 └──────────────────────►  ② DirectShow Audio          │   │
│                                        │     (VB-Cable)               │   │
│                                        │  ③ 액자 오버레이             │   │
│                                        │     (brand frame PNG)        │   │
│                                        │  ④ 크롭 필터                 │   │
│                                        │     (status/nav bar 제거)    │   │
│                                        │  ⑤ H.264 / AAC               │   │
│                                        │     1920×1080 · 16:9         │   │
│                                        └──────────────┬───────────────┘   │
└───────────────────────────────────────────────────────┼─────────────────────┘
                                                        │
                                                   final.mp4
                                                        │
┌───────────────────────────────────────────────────────┼─────────────────────┐
│  WSL2 — Ubuntu · Claude Runtime                       │                     │
│                                                        │                     │
│  ┌─────────────────────────────────────────────────┐  │                     │
│  │  Claude Stack                                   │  │                     │
│  │  Claude Code (WSL2)                             │  │                     │
│  │    ├── Desktop Commander MCP (Win 프로세스 제어) │  │                     │
│  │    └── Claude in Chrome + Playwright MCP        │  │                     │
│  └──────────────────┬──────────────────────────────┘  │                     │
│                     │ orchestrate                      │                     │
│  ┌──────────────────▼──────────────────────────────┐  │                     │
│  │  broadcast.py — Orchestrator                    │  │                     │
│  │                                                 │  │                     │
│  │  Phase 1: adb shell am start -a VIEW -d {URL}   │  │                     │
│  │           → 태블릿 웹페이지 오픈                │  │                     │
│  │                                                 │  │                     │
│  │  Phase 2: subprocess.Popen(ffmpeg ...)          │  │                     │
│  │           → 녹화 시작                           ├──┘                     │
│  │                                                 │                        │
│  │  Phase 3: SIGINT → FFmpeg flush & close         │                        │
│  │           → final.mp4 생성                      │                        │
│  │                                                 │                        │
│  │  Phase 4: youtube-studio.js 실행                │                        │
│  │           → YouTube Data API v3 자동 업로드     │                        │
│  └─────────────────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  OUTPUT                                                                     │
│  final.mp4 (H.264 · AAC · 1920×1080 · 16:9)                                │
│      → youtube-studio.js (YT Data API v3)                                  │
│      → YouTube 채널                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 역할 분담 확정

| 작업 | 담당 | 방식 |
|------|------|------|
| URL 전송 → 웹페이지 오픈 | Claude (broadcast.py) | ADB intent |
| 녹화 시작/종료 | Claude (broadcast.py) | FFmpeg subprocess |
| 오디오 보정 | 박씨 직접 세팅 | REAPER 템플릿 |
| S펜 판서 | 박씨 직접 | 손으로 |
| Axis 상황판 탭 | 박씨 직접 | 손으로 |
| 카메라 각도 | 박씨 직접 | 몸으로 |
| 자동 업로드 | Claude (broadcast.py) | youtube-studio.js |

---

## 신호 흐름 요약

```
박씨 말한다 (Shure MV88+)
    → Focusrite → REAPER 보정 → VB-Cable

박씨 판서/탭한다 (태블릿)
    → Parksy Pen / Axis → scrcpy → PC 창

FFmpeg
    → scrcpy 창(DirectShow) + VB-Cable(DirectShow)
    → 액자 PNG overlay
    → 크롭 (status bar / nav bar 제거)
    → H.264/AAC 인코딩
    → final.mp4

박씨가 종료 신호
    → broadcast.py Phase 3 → FFmpeg SIGINT
    → Phase 4 → youtube-studio.js → YouTube 자동 업로드
```

---

## 핵심 원칙

1. **편집 제로** — 웹페이지 자체가 완성된 콘텐츠. 녹화 = 완성본.
2. **PC가 두뇌** — 모든 연산(오디오보정/인코딩/업로드)은 PC.
3. **태블릿은 단말기** — 입력(화면/펜/탭)만 담당.
4. **인프라 무중단** — mosh + Tailscale + BIOS Server Mode.
5. **Claude가 오케스트레이터** — broadcast.py로 4단계 자동 실행.

---

## Phase 1 박씨 직접 세팅 항목

| 항목 | 도구 | 비고 |
|------|------|------|
| 태블릿 화면 미러링 | scrcpy 설치 | Windows에 설치 |
| 가상 오디오 루프백 | VB-Cable 설치 | Windows에 설치 |
| 오디오 체인 템플릿 | REAPER | Gate/EQ/Comp/De-ess/Limiter 프리셋 |

---

*아키텍처 확정: 2026-03-27 / Claude Code + 박씨*
