# Changelog

## [2.0.0] - 2026-01-03

### Added
- **Track A: 화면 녹음** - MediaProjection으로 시스템 오디오 캡처
- **Track B: 파일 변환** - 로컬 MP3/WAV/M4A 파일 지원
- **MIDI 변환** - Basic Pitch 기반 Cloud Run API 연동
- **프리셋 선택기** - 1/2/3분 구간 지원 (AIVA 호환)
- **Result 모나드** - 명시적 에러 처리 패턴
- **FileManager** - 임시 파일 자동 정리
- **에러 메시지 한국어화** - 네트워크/서버/파일 오류

### Architecture
- `core/` - AppConfig, Result<T>, DurationUtils
- `services/` - AudioService, MidiService, FileManager, PermissionService
- `screens/` - HomeScreen, CaptureScreen, ConverterScreen, TrimmerScreen
- `widgets/` - PresetSelector, ResultCard

### Technical
- Flutter 3.0+ / Dart 3.0+
- Android 10+ (API 29+) required for MediaProjection
- FFmpeg audio toolkit for processing
- Dio for HTTP with proper timeout handling

### Server
- `POST /convert` - 동기 MIDI 변환 (앱 전용)
- `POST /v1/jobs` - 비동기 변환 (향후 확장)
- Cloud Run 배포 (us-central1)

---

## [1.0.0] - 2025-12-30

### Initial Release
- Basic audio trimmer functionality
- WAV output only
- No MIDI conversion
