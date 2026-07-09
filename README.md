# DTSLIB APK Lab

박씨 전용 Android APK 개발 모노레포.

## 핵심 개념: 온디바이스 ADB APK

이 레포가 존재하는 이유는 하나다.

> **Good Lock으로 안 되고, ADB로도 안 될 때만 APK를 만든다.**
> (`~/.claude/CLAUDE.md` — ADB 설계 철학 참조)

폰은 WSL2 PC를 섬기는 SSH 클라이언트다. 대부분의 자동화는 ADB 원격 조종으로 끝나지만,
오버레이·상시 실행·카메라/마이크 점유·백그라운드 서비스처럼 **ADB 천장 위에 있는 것만** 여기서 APK로 만든다.
그래서 이 레포의 앱은 "일반 앱스토어 앱"이 아니라 **폰과 PC 사이의 물리적 틈을 메우는 브릿지 부품**이다.

이 개념을 가장 순수하게 구현한 앱이 **[Blackhole](apps/blackhole)** — "모든 디바이스를 PC로 연결한다."

## 📦 App 카탈로그 (개념별 분류)

### 🕳️ Bridge — 온디바이스 ↔ PC 연결 (핵심 개념)
| App | Version | Description |
|-----|---------|-------------|
| **Blackhole** | v1.1.0 | 모든 디바이스를 PC로 연결 — WebView + PC 화면 실시간 뷰어 |

### 📡 Broadcast — 방송 제작 파이프라인
| App | Version | Description |
|-----|---------|-------------|
| **Parksy Axis** | v5.0.0 | 방송용 사고 단계 오버레이 |
| **Parksy Studio** | v1.0.0 | 화면녹화 + 동시통역 + BGM + 트리머 (실행률 ~50%, v2.0 백서 있음) |

### 🎨 Overlay / Creative — 판서·그림
| App | Version | Description |
|-----|---------|-------------|
| **Parksy Pen** | v25.12.0 | S Pen 레이저펜 판서 오버레이 |
| **Parksy Liner** | — | 사진 → 스케치 (XDoG 라인아트, Samsung Notes 연동) |

### 🔤 Subtitle
| App | Version | Description |
|-----|---------|-------------|
| **Parksy Glot** | v1.0.0 | 실시간 다국어 자막 (Whisper + GPT-4o) |

### 🎵 Audio
| App | Version | Description |
|-----|---------|-------------|
| **Parksy Melody** | — | YouTube 오디오 컷 — 프리셋 클립 + 텔레그램 브릿지 |

### 🛠️ Utility
| App | Version | Description |
|-----|---------|-------------|
| **Parksy Capture** | v10.0.8 | 공유 텍스트 캡처 → GitHub 아카이브 |
| **Parksy ChronoCall** | v1.0.0 | 통화 녹음 STT 변환 (Whisper) |

### ⌚ Wearable — 구매 대기 (계획 슬롯)
| App | Status | Description |
|-----|--------|-------------|
| **Parksy Glass** | planned | 1인칭 POV 라이브 퍼포먼스 방송용 스마트 글래스. [백서](apps/smart-glass/README.md) |

### 🗄️ Archive — 폐기 (서사 보존, 코드는 archive/ 로 격리)
| App | Discontinue Reason |
|-----|---------|
| Parksy MIDI | archive/midi-converter |
| Parksy Audio Tools | archive/parksy-audio-tools |
| Parksy Wavesy | archive/parksy-wavesy |
| Parksy TTS | Edge TTS/Grok 품질로 대체됨. Google Cloud 과금 이슈. archive/tts-factory |

전체 메타데이터는 [`app-registry.json`](app-registry.json)이 source of truth.

## 🏪 Store

**https://dtslib-apk-lab.vercel.app**

## 🔧 Development

```bash
# Clone
git clone https://github.com/dtslib1979/dtslib-apk-lab.git
cd dtslib-apk-lab

# Build specific app
cd apps/blackhole
flutter pub get
flutter build apk --debug
```

## ⚖️ License

Personal use only. No distribution.

---

*Powered by GitHub Actions + nightly.link + Vercel*
