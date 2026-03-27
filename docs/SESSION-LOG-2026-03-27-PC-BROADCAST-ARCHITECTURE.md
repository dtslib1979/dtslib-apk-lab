# 회의록 — 2026-03-27 | PC 방송국 아키텍처 전환 스터디

> 참석: 박씨 + Claude Code
> 형식: 구두 문답 → 아키텍처 확정

---

## 1. 발단 — 태블릿 볼륨 제한 해제

**상황**: SM-X716N(태블릿) 청각보호 75% 설정으로 볼륨 제한 걸려 있음

**조치**: ADB로 즉시 해제
```bash
adb -s 100.74.21.77:5555 shell settings put global audio_safe_volume_state 0
adb -s 100.74.21.77:5555 shell cmd media_session volume --stream 3 --set 15
```
**결과**: 청각보호 해제, 미디어 볼륨 15/15 최대

---

## 2. ADB 연결 현황 확인

연결된 기기 2대:
| 기기 | IP | 모델 |
|------|-----|------|
| SM-S938N | 100.103.250.45:5555 | 갤럭시 S25 Ultra |
| SM-X716N | 100.74.21.77:5555 | 갤럭시 탭 S9 FE |

---

## 3. 스튜디오 앱 탐색

### cloud-appstore → dtslib-apk-lab 으로 정정
- 처음에 cloud-appstore 의 audio-studio (오디오 컷&루프 도구) 를 찾았으나 박씨 의도와 다름
- 실제 대상: **dtslib-apk-lab 의 Parksy Studio v1.0.0**

### Parksy Studio 현황
```json
{
  "package": "com.parksy.studio",
  "version": "v1.0.0",
  "status": "태블릿에 이미 설치됨",
  "features": [
    "화면녹화 (MIC/외장마이크/DAW 3모드)",
    "WebView (URL → 풀스크린)",
    "카메라 오버레이",
    "BGM 플레이어",
    "cloud-appstore 런처"
  ]
}
```

**태블릿 설치 확인된 Parksy 앱 전체:**
- `kr.parksy.axis` — Axis 상황판 오버레이
- `com.parksy.capture` — 캡처
- `com.parksy.ttsfactory` — TTS
- `com.parksy.studio` — 스튜디오

---

## 4. 핵심 패러다임 전환 — 박씨 직접 제시

### Before (구 설계)
> "태블릿 온디바이스 환경에서 전부 처리"

모든 연산(화면녹화, FFmpeg, 오디오처리)을 태블릿이 혼자 담당.
Android 제약(루프백 불가, 앱 간 오디오 차단, 처리 한계)으로 타협이 많았음.

### After (신 설계)
> "PC가 두뇌, 태블릿은 입력 단말기"

박씨 한 마디: *"그러니까 PC 환경인데, 카메라 달려 있고 펜 판서하고 목소리 입력하는 입력창 터미널로 쓰겠다는 건데"*

**태블릿 = 4채널 입력 단말기:**
| 채널 | 입력 | 처리 |
|------|------|------|
| 화면 | WebView / 앱 조작 | ADB → PC 캡처 |
| S펜 | 판서/드로잉 | 태블릿 직접 (물리 입력) |
| 카메라 | 영상 피드 | scrcpy → PC |
| 터치 | 네비게이션 | Axis 탭 등 |

**PC = 모든 연산 담당:**
- REAPER: 목소리 보정
- OBS: 화면 합성
- FFmpeg: 인코딩
- youtube-studio.js: 업로드

---

## 5. 하드웨어 확정

### 오디오 체인
```
Shure MV88+ ──┐
               ├──▶ Focusrite Scarlett ──USB──▶ PC (REAPER)
XLR 마이크 ───┘
```

### 오디오 루프백 문제 → PC로 해결
- Android 온디바이스 루프백: 루트 없이 불가 (OS 차단)
- 해결: Focusrite → PC → REAPER 처리 → VB-Cable 가상루프백
- 태블릿 오디오 고민 자체가 불필요해짐

### Focusrite "왜 안되냐" 논의
- 태블릿에 꽂으면 Android USB 오디오 권한 이슈 발생
- 결론: PC에 꽂으면 그냥 됨. REAPER가 이미 돌아가고 있음.

---

## 6. 완전체 아키텍처 (확정)

```
┌─────────────────────────────────────────────────────────────────┐
│                        INPUT LAYER                              │
│  MV88+ → Focusrite → PC    +    태블릿 (화면/펜/카메라)         │
└─────────────────────────┬───────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PROCESSING LAYER (PC)                         │
│                                                                 │
│  REAPER: Gate → EQ → Comp → De-ess → Limiter → 녹음            │
│  scrcpy: 태블릿 화면 → PC 소스                                  │
│  OBS: 화면 합성 (액자 구성) + 녹화                             │
│  FFmpeg: 영상 + 오디오 합산 + 인코딩                            │
└─────────────────────────┬───────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                     OUTPUT LAYER                                │
│  final.mp4 (16:9, 액자 구성) → YouTube 업로드                  │
└─────────────────────────────────────────────────────────────────┘
```

### 역할 분담 확정

| | PC 자동 | 박씨 직접 |
|-|---------|----------|
| 화면녹화 시작/종료 | ✅ ADB | |
| URL 열기 | ✅ ADB intent | |
| 오디오 처리/녹음 | ✅ REAPER | |
| 합산/업로드 | ✅ FFmpeg + youtube-studio.js | |
| **Axis 상황판** | | ✅ 흐름 따라 탭 |
| **S펜 판서** | | ✅ 손으로 직접 |
| **카메라 각도** | | ✅ 몸으로 |

> **Axis 자동화 제안 → 박씨 거절**: "내가 어디 가리키는지 중간중간 눌러주는 게 더 낫다"
> **Whisper 실시간 제안 → 박씨 거절**: "직접 말하면서 방송하는데 왜 필요하냐"
> **라이브 스트리밍 제안 → 박씨 거절**: "녹화로 올릴 건데 라이브가 왜 필요하냐"

---

## 7. 최종 영상 포맷 확정

**YouTube 롱폼 (가로 16:9)**

```
┌─────────────────────────────┐
│                             │
│   ┌───────────────────┐     │
│   │  태블릿 화면      │     │  ← 액자 구성
│   │  (인터랙티브 페이지│    │  ← status bar/nav bar 크롭
│   │   조작 중)        │     │
│   └───────────────────┘     │
│                             │
└─────────────────────────────┘
  + REAPER 보정 목소리
  → 녹화 끝 → 자동 인코딩 → 업로드
```

---

## 8. PC 사양 확인

| 항목 | 사양 |
|------|------|
| CPU | Intel i7-8550U (4코어/8스레드) |
| RAM | 16GB (여유 ~2GB) |
| GPU | Intel UHD 620 (내장) |
| SSD | NVMe 512GB |
| 외장 | WD My Passport 2TB |

### 사양별 가능 여부

| 기능 | 가능? |
|------|-------|
| OBS 녹화 | ✅ (Quick Sync 인코더 사용) |
| REAPER 오디오 보정 | ✅ |
| scrcpy 미러링 | ✅ |
| FFmpeg 인코딩 | ✅ (약간 느리지만 문제 없음) |
| Whisper 실시간 | ❌ (GPU 없음, 불필요하기도 함) |

---

## 9. 현재 미설치 / 미세팅 항목 (TODO)

| 항목 | 도구 | 우선순위 |
|------|------|---------|
| 태블릿 화면 → PC 미러링 | scrcpy 설치 | 1순위 |
| 가상 오디오 루프백 | VB-Cable 설치 (Windows) | 1순위 |
| REAPER 목소리 체인 템플릿 | 박씨 직접 세팅 (10분) | 1순위 |
| OBS 씬 구성 (액자 레이아웃) | OBS 설치 + 씬 설계 | 2순위 |
| 태블릿 상하단 크롭 | OBS 필터 세팅 | 2순위 |
| 녹화 후 자동 인코딩 | broadcast.py 작성 | 3순위 |
| APK URL Intent 수신 | parksy-studio 수정 + 빌드 | 3순위 |
| 자동 업로드 | youtube-studio.js | ✅ 이미 있음 |

---

## 10. 결정 사항 요약

1. **태블릿 = 입력 단말기** (두뇌는 PC)
2. **오디오 파이프라인 = 100% PC** (Focusrite → REAPER → VB-Cable)
3. **영상 = scrcpy → OBS → 액자 합성 → 녹화**
4. **Axis/S펜 = 박씨 직접 조작** (자동화 없음)
5. **불필요한 기능 제거**: Whisper 실시간, 라이브 스트리밍
6. **최종 도구 5개**: REAPER + scrcpy + OBS + FFmpeg + youtube-studio.js

---

*회의록 작성: Claude Code / 2026-03-27*

---

## 세션 로그 — 2026-03-27 오후 | Parksy Studio v2.0 구현 완료

> 형식: CLAUDE.md 세션 로그 포맷

---

### 2026-03-27 | Parksy Studio v2.0 전체 구현 + Glot APK v2 재설계 + MCP 연동 완성

**작업:**

1. **broadcast.py v1.0** (`apps/parksy-studio/broadcast.py`, 285줄)
   - Phase 1: ADB intent → 태블릿 웹페이지 오픈
   - Phase 2: FFmpeg DirectShow(scrcpy window + VB-Cable) + frame.png overlay → H.264/AAC 1920×1080 녹화
   - Phase 3: SIGINT flush → 정상 종료
   - Phase 4: youtube-studio.js → YouTube 업로드
   - Ctrl+C 핸들러로 자동 종료+업로드 연결

2. **glot.py v2.0** (`apps/parksy-glot/glot.py`, 370줄)
   - WebSocket 서버(포트 8765) + HTTP 서버(포트 8766)
   - CONTROL_HTML: Web Speech API 컨트롤 페이지 (Chrome/Edge 무료 STT)
   - SUBTITLE_HTML: 드래그+핀치줌 자막 표시 페이지
   - Google Translate 무료 endpoint (ko/en 번역)

3. **frame.png 생성기** (`/tmp/make_frame.py`)
   - 1920×1080 칠판 다크그린 액자 PNG
   - 중앙 투명 영역 (x=42, y=58, w=1836, h=922) — scrcpy 화면이 들어갈 자리
   - 상단 58px: PARKSY STUDIO v2.0(골드) + 강의주제 + HH:MM + 🔴REC
   - 하단 100px: 원어/한국어/영어 자막 3줄
   - 분필 텍스처 노이즈 + 골드 코너 장식

4. **바탕화면 런처** (`C:\Users\dtsli\Desktop\🎬 PARKSY STUDIO.bat`)
   - 실행 순서: REAPER → scrcpy → Glot서버(WSL2) → Chrome 컨트롤 페이지
   - scrcpy 미설치 시 안내 메시지 출력

5. **APK 스토어 업데이트** (`dashboard/apps.json`, `dashboard/index.html`)
   - parksy-studio: registryStatus → "migrated-to-pc"
   - parksy-glot: registryStatus → "migrated-to-pc"
   - migrated-to-pc 상태 카드 렌더링 추가 (주황색 배지)

6. **Glot APK v2.0 재설계** (`apps/parksy-glot/`)
   - v1(온디바이스 Whisper/STT 4334줄) 전부 제거, Axis-shell 패턴으로 교체
   - `flutter_overlay_window` + `webview_flutter` 의존성으로 교체
   - `overlayMain()`: WebView → `http://PC_IP:8766/subtitle` 로드
   - `main()`: PC IP 설정 UI + 오버레이 ON/OFF 토글
   - 패키지명: `com.dtslib.parksy_glot` → `com.parksy.glot`
   - minSdk: 29 → 21

7. **scrcpy 설치 완료** — winget 3.3.4, PATH 등록됨

8. **WSL MCP 설정 정비** (`~/.claude/settings.json`)
   - filesystem: `/home/dtsli`, `/mnt/c/Users/dtsli`, `/mnt/d` 전체로 확장
   - playwright MCP 추가 (@playwright/mcp 0.0.68, Windows 직접 경로)
   - windows-cli MCP 추가 (@simonb97/server-win-cli)
   - chrome-mcp 추가 (mcp-chrome-bridge)

**결정:**

- OBS 완전 폐기 → FFmpeg DirectShow 직접 녹화로 확정 (이전 세션에서 결정)
- Glot STT 처리: 온디바이스 Whisper(유료) → PC Web Speech API(무료) 로 전환
- 자막 오버레이: 전용 APK → Axis-shell 패턴(얇은 WebView 껍데기)으로 재설계
- 태블릿 = 입력 단말기, PC = 두뇌 아키텍처 확정

**결과:**

- 커밋 7개: a99688f → 1e0924b
- Vercel 자동 배포 완료
- win-gui MCP 14개 도구 정상 응답 확인 (screenshot/click/type/powershell 등)
- playwright/windows-cli MCP 정상 응답 확인

**교훈:**

- OBS 재언급 실수 (이전 세션 결정 기억 필수)
- GPU 작업 오인 실수 (이 파이프라인은 전부 CPU)
- 원격 환경(mosh + Tailscale + ADB)에서 Claude Code 구동 중 — Claude Desktop 건드리지 말 것
- DAW 세션 분리 운영 중 — broadcast.py 관련 작업 시 DAW 세션 충돌 주의

**재구축 힌트:**

- `broadcast.py --url [URL] --title "제목"` 실행하면 4단계 자동 진행
- scrcpy 먼저 실행 후 Enter → FFmpeg 녹화 시작
- VB-Cable 미설치 시 녹화 불가 (수동 설치 필요: https://vb-audio.com/Cable/)
- Glot APK 빌드: `cd apps/parksy-glot && flutter pub get && flutter build apk --debug`

---
