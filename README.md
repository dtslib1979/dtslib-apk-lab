# Parksy APK Lab

박씨 전용 Android APK 개발 모노레포

## 📦 Apps

| App | Version | Description |
|-----|---------|-------------|
| **Parksy Audio Tools** | v2.0.0 | 🎵 화면녹음 → MIDI (AIVA용) |
| **Parksy Axis** | v5.0.0 | 방송용 사고 단계 오버레이 |
| **Parksy Pen** | v25.12.0 | S Pen 레이저펜 판서 |
| **Parksy Capture** | v10.0.8 | 텍스트 캡처 → GitHub 아카이브 |
| **Parksy Subtitle** | v1.0.0 | 이중자막 오버레이 |
| **Parksy AIVA** | v2.0.0 | AIVA MP3 무음 트리밍 |
| **Parksy TTS** | v1.0.2 | 배치 TTS 생성기 |

## 🎵 Parksy Audio Tools

**화면 오디오 캡처 → MP3 → MIDI 변환기**

- Track A: 화면 녹음 (MediaProjection)
- Track B: 파일 변환 (MP3/WAV/M4A)
- MIDI 출력: AIVA 직접 업로드 가능

[📄 Documentation](apps/parksy-audio-tools/README.md) | [📋 Changelog](apps/parksy-audio-tools/CHANGELOG.md) | [🧪 Testing](apps/parksy-audio-tools/TESTING.md)

## 🏪 Store

**https://dtslib-apk-lab.vercel.app**

## 🔧 Development

```bash
# Clone
git clone https://github.com/dtslib1979/dtslib-apk-lab.git
cd dtslib-apk-lab

# Build specific app
cd apps/parksy-audio-tools
flutter pub get
flutter build apk --debug
```

## ⚖️ License

Personal use only. No distribution.

---

*Powered by GitHub Actions + nightly.link + Vercel*
