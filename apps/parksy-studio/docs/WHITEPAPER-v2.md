# PARKSY STUDIO v2.0 — 개발 백서

> 작성일: 2026-03-27
> 작성: Claude Code + 박씨 공동 설계
> 분류: 내부 개발 문서 (개발백서)

---

## 한 줄 선언

**태블릿은 입력 단말기다. PC가 방송국이다.**

---

## 0. 왜 v2.0인가 — v1.0의 한계

v1.0은 **태블릿 온디바이스 모델**로 설계됐다.
모든 연산(화면녹화, FFmpeg, 오디오처리, STT)을 태블릿 혼자 담당.

### v1.0이 타협해야 했던 것들

| 기능 | v1.0 현실 | 원인 |
|------|----------|------|
| 오디오 루프백 | 불가 | Android OS 레벨 차단 |
| DAW 보정 목소리 녹음 | 불가 | 앱 간 오디오 캡처 금지 |
| FFmpeg 영상처리 | WASM, 느림 | 태블릿 CPU 한계 |
| 다중 소스 합성 | 불가 | 단일 앱 제약 |
| 전문가급 음질 | 불가 | 내장 마이크 한계 |

**구조적 원인:** 태블릿이 두뇌이자 단말기이자 인코더였다.
결과: 모든 곳에서 타협.

### 패러다임 전환 (2026-03-27 확정)

> *"그러니까 PC인데, 카메라 달려 있고 펜 판서하고 목소리 입력하는 입력창 터미널로 쓰겠다는 건데"*
> — 박씨, 2026-03-27

**태블릿 = 4채널 입력 단말기로 재정의.**
PC가 두뇌. 태블릿은 손발.

---

## 1. 시스템 아키텍처

### 1.1 전체 구조

```
┌─────────────────────────────────────────────────────────────────────┐
│                          INPUT LAYER                                │
│                                                                     │
│  Shure MV88+ ──┐                                                    │
│                ├──▶ Focusrite Scarlett ──USB──▶ PC                  │
│  XLR Mic ─────┘                                                     │
│                                                                     │
│  SM-X716N (Galaxy Tab S9 FE)                                        │
│  ├── 화면 (WebView / 인터랙티브 페이지)  ──ADB──▶ scrcpy ──▶ PC    │
│  ├── S펜 판서                            ────────────────▶ 박씨 직접│
│  ├── Axis 상황판 탭                      ────────────────▶ 박씨 직접│
│  └── 카메라                             ──ADB──▶ scrcpy ──▶ PC     │
│                                                                     │
│  SM-S938N (Galaxy S25 Ultra)                                        │
│  └── 보조 카메라 / 원격 모니터링                                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────┐
│                       PROCESSING LAYER — PC                          │
│                                                                      │
│  ┌─────────────────────┐    ┌───────────────────────────────────┐   │
│  │  AUDIO ENGINE       │    │  VIDEO ENGINE                     │   │
│  │                     │    │                                   │   │
│  │  Focusrite Input    │    │  scrcpy → OBS Source              │   │
│  │  → REAPER           │    │  OBS Scene:                       │   │
│  │    Gate             │    │  ├── 배경 레이어 (16:9)           │   │
│  │    EQ               │    │  ├── 액자 프레임                  │   │
│  │    Compressor       │    │  ├── 태블릿 화면 (크롭)           │   │
│  │    De-esser         │    │  └── Axis 오버레이 (선택)         │   │
│  │    Limiter          │    │  → OBS 녹화                       │   │
│  │  → VB-Cable         │    │                                   │   │
│  │  → WAV 동시 저장    │    └───────────────────────────────────┘   │
│  └─────────────────────┘                                            │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ADB CONTROLLER (broadcast.py)                               │   │
│  │  URL 목록 → 태블릿 WebView → 녹화 시작/종료 → 파일 수거      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  POST PROCESSOR (FFmpeg)                                      │   │
│  │  OBS영상 + REAPER WAV → 합산 → 최종 MP4                      │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬───────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────┐
│                        OUTPUT LAYER                                  │
│  final.mp4 → youtube-studio.js → YouTube 업로드                     │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 역할 분담 원칙

**PC가 하는 것 (자동화):**
- 오디오 캡처 + 처리 + 녹음
- 화면 합성 + 녹화
- ADB로 태블릿 제어 (URL 열기, 녹화 시작/종료)
- 파일 수거 + 인코딩 + 업로드

**박씨가 하는 것 (물리 조작):**
- Axis 상황판 탭 (방송 흐름 따라 직접)
- S펜 판서 (직접 그리기)
- 카메라 각도/위치 (몸으로)
- 말하기 (마이크 앞에서)

> **설계 원칙**: 박씨가 콘텐츠에 집중하는 것만 직접. 나머지는 전부 자동.

---

## 2. 하드웨어 스택

### 2.1 확정 구성

| 역할 | 장비 | 연결 |
|------|------|------|
| 메인 마이크 | Shure MV88+ | → Focusrite |
| 오디오 인터페이스 | Focusrite Scarlett | USB → PC |
| 오디오 처리 | REAPER (PC) | 상시 가동 |
| 영상 단말기 | SM-X716N Tab S9 FE | ADB (Tailscale) |
| 보조 기기 | SM-S938N S25 Ultra | ADB (Tailscale) |
| 두뇌 | PC (i7-8550U / 16GB) | 서버 모드 상시 가동 |

### 2.2 PC 사양 검증 결과

| 기능 | 가능 여부 | 비고 |
|------|----------|------|
| REAPER 오디오 체인 | ✅ | 현재 가동 중 |
| scrcpy 미러링 | ✅ | CPU 부하 낮음 |
| OBS Quick Sync 녹화 | ✅ | Intel UHD 620 HW인코딩 |
| FFmpeg 후처리 | ✅ | 약간 느리지만 배치 처리 무관 |
| 전체 동시 실행 | ✅ | 16GB RAM으로 여유 |

> GPU 없음(UHD 620 내장)이지만 OBS Quick Sync 인코더 사용으로 CPU 부하 해결.

---

## 3. APK의 새로운 역할 — v2.0 재정의

### v1.0 APK의 역할
> 전체 파이프라인을 혼자 다 처리하는 앱

### v2.0 APK의 역할
> **PC의 명령을 받아 실행하는 지능형 단말기**

```
v1.0: APK = 방송국 전체
v2.0: APK = 방송국의 카메라 + 모니터 + 펜
```

### 핵심 변화

| 기능 | v1.0 (온디바이스) | v2.0 (PC 오케스트레이션) |
|------|-----------------|------------------------|
| 오디오 처리 | 태블릿 내부 AudioEffect | PC REAPER VST 체인 |
| 화면녹화 트리거 | 손으로 탭 | ADB 커맨드 |
| URL 열기 | 손으로 입력 | ADB Intent 자동 주입 |
| 파일 저장 경로 | 태블릿 내부 | /sdcard/ (ADB pull 가능) |
| FFmpeg 처리 | WASM (느림) | PC FFmpeg (빠름) |
| 업로드 | OAuth 불안정 | PC youtube-studio.js |

---

## 4. APK 수정 사항 (v1.0 → v2.0)

### 4.1 추가: URL Intent 수신

PC에서 ADB로 URL을 직접 주입하면 WebView가 즉시 열린다.

```kotlin
// AndroidManifest.xml 추가
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:scheme="parksy" android:host="open"/>
</intent-filter>
```

```bash
# PC에서 실행
adb shell am start -n com.parksy.studio/.MainActivity \
  --es url "https://dtslib1979.github.io/dtslib-cloud-appstore/audio-studio/"
```

### 4.2 수정: 파일 저장 경로

```kotlin
// 기존: 앱 내부 디렉토리
val outputDir = context.filesDir

// 변경: ADB 접근 가능한 경로
val outputDir = Environment.getExternalStoragePublicDirectory(
    Environment.DIRECTORY_MOVIES
).resolve("ParksynStudio")
```

### 4.3 제거: 불필요한 기능

v2.0에서 APK에서 제거 (PC가 담당):
- FFmpeg WASM 트리머 → PC FFmpeg
- YouTube OAuth 업로드 → PC youtube-studio.js
- 복잡한 오디오 효과 체인 → REAPER

**APK는 가벼워진다. 단말기니까.**

### 4.4 유지: 핵심 기능

- 화면녹화 (MIC / UNPROCESSED / DAW 모드)
- WebView 풀스크린 렌더링
- Axis 오버레이 연동
- cloud-appstore 런처

---

## 5. PC 소프트웨어 스택

### 5.1 REAPER — 오디오 엔진

```
Focusrite 입력
  → Noise Gate (배경 소음 차단)
  → EQ (목소리 주파수 최적화: 80Hz 롤오프, 3kHz 존재감 부스트)
  → Compressor (다이나믹 평탄화, ratio 3:1)
  → De-esser (치찰음 제거)
  → Limiter (클리핑 방지, -1dBTP)
  → VB-Cable Out (OBS 오디오 소스)
  → WAV 파일 동시 저장 (타임스탬프 파일명)
```

박씨 직접 세팅 (10분). REAPER 템플릿으로 저장 후 부팅 시 자동 로드.

### 5.2 scrcpy — 태블릿 미러링

```bash
# 설치
choco install scrcpy  # Windows

# 실행 (태블릿 → PC 미러링)
scrcpy --serial 100.74.21.77:5555 \
       --window-title "Parksy-Tablet" \
       --no-audio \
       --stay-awake
```

OBS에서 "Window Capture" 소스로 scrcpy 창 잡으면 끝.

### 5.3 OBS — 화면 합성 + 녹화

**Scene 구성: "Parksy Long-form"**

```
Layer 1 (배경): 단색 or 그라데이션 배경 (#0A0A0A)
Layer 2 (액자): 테두리 프레임 이미지 (PNG 오버레이)
Layer 3 (콘텐츠): scrcpy Window Capture
  → Crop/Pad 필터: 상단 status bar, 하단 nav bar 제거
  → 위치: 액자 안에 맞게 정렬
Layer 4 (오디오): VB-Cable (REAPER 출력)
```

**녹화 설정:**
- 포맷: MKV (충돌 시 파일 보존)
- 인코더: Quick Sync H.264 (Intel 내장 GPU)
- 해상도: 1920×1080
- 비트레이트: 8000 Kbps
- 오디오: AAC 256kbps

### 5.4 broadcast.py — ADB 컨트롤러

```python
# 사용법
python broadcast.py urls.txt

# urls.txt 형식
https://dtslib1979.github.io/parksy-audio/overtures/
https://dtslib1979.github.io/dtslib-cloud-appstore/
...
```

**동작 순서:**
```
1. REAPER 녹음 시작 (OSC 또는 키 시뮬레이션)
2. OBS 녹화 시작 (obs-websocket API)
3. ADB → URL 열기 → 3초 대기
4. [녹화 중 — 박씨 진행]
5. [엔터 입력 or 자동 타이머] → 종료
6. OBS 녹화 중지
7. REAPER 녹음 중지
8. adb pull /sdcard/Movies/ParksyStudio/*.mp4 ./raw/
9. ffmpeg 영상+오디오 합산
10. ./final/{title}.mp4 저장
```

### 5.5 FFmpeg 합산 커맨드

```bash
ffmpeg \
  -i raw/screen_{timestamp}.mkv \
  -i reaper/voice_{timestamp}.wav \
  -c:v copy \
  -c:a aac -b:a 256k \
  -map 0:v:0 -map 1:a:0 \
  final/{title}.mp4
```

---

## 6. 영상 포맷 표준

### 6.1 YouTube Long-form (16:9)

```
┌─────────────────────────────────────────────────┐ 1920px
│                                                 │
│   ┌───────────────────────────────────────┐     │
│   │                                       │     │
│   │         태블릿 화면                   │     │  1080px
│   │    (인터랙티브 페이지 조작 중)        │     │
│   │                                       │     │
│   │   [status bar 크롭됨]                 │     │
│   │   [nav bar 크롭됨]                    │     │
│   └───────────────────────────────────────┘     │
│                                                 │
└─────────────────────────────────────────────────┘

오디오: REAPER 보정 목소리 (Focusrite → MV88+)
자막: 없음 (박씨 직접 말하는 것으로 대체)
```

### 6.2 크롭 기준 (Samsung Tab S9 FE)

| 영역 | 크롭 픽셀 |
|------|----------|
| 상단 Status Bar | 상위 80px |
| 하단 Navigation Bar | 하위 120px |
| 좌우 | 없음 |

OBS Crop/Pad 필터로 설정. 한 번 세팅하면 고정.

---

## 7. 오버레이 앱 연동

### 7.1 Parksy Axis (kr.parksy.axis)

방송 흐름에서 현재 섹션 표시용 FSM 오버레이.

**운영 방식 확정:**
- 박씨가 직접 탭으로 상태 전이
- PC 자동화 없음 (콘텐츠 흐름은 박씨만 안다)
- 화면 위에 항상 떠 있는 상태로 화면녹화에 포함

```
박씨 흐름:
강의 시작 → Axis 탭 (섹션 1) → 내용 진행 →
다음 섹션 → Axis 탭 (섹션 2) → ... → 마무리
```

### 7.2 Parksy Pen (laser-pen-overlay)

S펜 판서용 오버레이. v25.12.0.

- 판서는 박씨 직접 (물리 입력)
- PC ADB로 대체 불가 (이게 맞는 구조)
- 화면 위에 투명 레이어로 떠서 WebView 위에 그리기 가능

---

## 8. 개발 Phase 로드맵

### Phase 1 — PC 환경 세팅 (박씨 직접, 1일)

```
[ ] scrcpy 설치 (Windows)
[ ] VB-Cable 설치 (Windows 가상 오디오)
[ ] REAPER 오디오 체인 세팅 + 템플릿 저장
[ ] OBS 설치 + "Parksy Long-form" 씬 구성
[ ] obs-websocket 플러그인 설치
```

### Phase 2 — APK 수정 빌드 (1일)

```
[ ] URL Intent 수신 추가 (AndroidManifest + MainActivity)
[ ] 저장 경로 /sdcard/Movies/ParksyStudio/ 변경
[ ] 불필요 기능 제거 (WASM 트리머, OAuth 업로드)
[ ] GitHub Actions 빌드 → ADB install
```

### Phase 3 — broadcast.py 작성 (반나절)

```
[ ] URL 목록 읽기
[ ] OBS WebSocket API 연동 (녹화 시작/종료)
[ ] ADB Intent URL 주입
[ ] adb pull 자동화
[ ] FFmpeg 합산 자동화
```

### Phase 4 — 통합 테스트 (반나절)

```
[ ] 전체 파이프라인 1회 시연
[ ] 영상 품질 확인 (크롭, 합산, 음질)
[ ] 업로드 테스트
[ ] 템플릿 저장 (반복 사용 구조)
```

### Phase 5 — 운영 (지속)

```
[ ] URL 목록 관리 (urls.txt)
[ ] REAPER 체인 튜닝
[ ] OBS 씬 변형 (섹션별 레이아웃)
[ ] 녹화 → 업로드 파이프라인 자동화 고도화
```

---

## 9. v1.0 vs v2.0 비교

| 항목 | v1.0 | v2.0 |
|------|------|------|
| 오디오 | 태블릿 내장 AudioEffect | PC REAPER + Focusrite |
| 루프백 | 불가 | VB-Cable (PC) |
| 화면합성 | 불가 | OBS 액자 합성 |
| FFmpeg | WASM (제한적) | PC 네이티브 (완전) |
| 업로드 | OAuth 불안정 | youtube-studio.js (안정) |
| 음질 | 태블릿 내장 마이크 | Shure MV88+ 전문가급 |
| 제어 | 손으로 탭 | PC ADB 오케스트레이션 |
| APK 역할 | 방송국 전체 | 지능형 입력 단말기 |
| 타협 | 매우 많음 | 없음 |

---

## 10. 설계 원칙 — v2.0 헌법

```
1. 태블릿은 입력 단말기다. 처리는 PC에서.
2. 박씨는 콘텐츠에만 집중한다. 나머지는 자동.
3. Axis와 S펜은 박씨 직접. 자동화 금지.
4. APK는 가벼울수록 좋다. 단말기는 단순해야 한다.
5. PC가 꺼지면 모든 것이 멈춘다. PC는 서버다.
6. 파이프라인 끝은 항상 YouTube 업로드다.
7. 비용 제로 원칙 유지. 서버, 클라우드, 과금 API 없음.
```

---

## 11. 미해결 과제

| 과제 | 우선순위 | 비고 |
|------|---------|------|
| REAPER ↔ OBS 녹화 싱크 타이밍 | 높음 | 오디오/영상 싱크 맞춰야 함 |
| ADB 연결 끊김 시 복구 | 중간 | Tailscale watchdog |
| 태블릿 부팅 후 자동 앱 실행 | 낮음 | BOOT_COMPLETED receiver |
| 홈화면 1페이지 고정 | 낮음 | 박씨 1회 수동 (ADB 불가) |

---

*"방송국보다 더 나은 1인 시스템"*
*Parksy Studio v2.0 — 2026-03-27*
