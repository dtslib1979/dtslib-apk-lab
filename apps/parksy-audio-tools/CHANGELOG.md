# Changelog

All notable changes to Parksy Audio Tools will be documented in this file.

## [2.1.0] - 2026-01-03

### Added
- **Firebase Crashlytics** - 실시간 크래시 리포팅
- **Firebase Analytics** - 사용자 행동 분석
  - 화면 전환 추적
  - MIDI 변환 성공/실패율
  - 파일 공유 이벤트
- **ConnectivityService** - 네트워크 상태 실시간 모니터링
- **OfflineBanner** - 오프라인 상태 시각적 피드백
- **Rate Limit 처리** - 429 응답 한국어 메시지
- **Unit Tests** - Result, DurationUtils 테스트 커버리지
- **Widget Tests** - PresetSelector 테스트
- **CI/CD** - Flutter 테스트 워크플로우 추가

### Changed
- **MidiService** - Analytics 통합, 오프라인 체크 선행
- **HomeScreen** - OfflineBanner 래핑, 탭 전환 추적
- **main.dart** - 글로벌 에러 바운더리, Firebase 초기화
- **Server v1.2.0** - Rate limiting, CORS, 로깅, /metrics 엔드포인트

### Fixed
- Dio 응답 타입 캐스팅 버그 (Uint8List vs List<int>)

## [2.0.0] - 2025-12-31

### Added
- 3-Track 아키텍처 (Capture, Converter, Trimmer)
- Result<T> 모나드 에러 핸들링
- 프리셋 선택기 (1분/2분/3분)
- Cloud Run MIDI 서버 통합
- 자동 임시 파일 정리 (24시간)

### Changed
- Material 3 테마 (Deep Purple)
- IndexedStack 네비게이션 (상태 보존)
- FFmpeg Kit 오디오 전용 빌드

## [1.0.0] - 2025-12-20

### Initial Release
- 기본 오디오 녹음 기능
- WAV 트리밍
- 파일 공유
