# Changelog

All notable changes to Parksy Audio Tools will be documented in this file.

## [2.1.0+6] - 2026-01-04

### Added
- **Server Health Check** - 앱 시작/resume 시 MIDI 서버 상태 체크
- **MidiService.healthCheck()** - 서버 연결 상태 확인 메서드
- **TrimmerScreen Analytics** - 트림 화면 이벤트 추적
  - 파일 선택, 트림 성공/실패, WAV 공유
- **ErrorCode 확장** - rateLimited, offline, fileTooLarge 추가
- **Result 헬퍼 메서드** - getOrElse, getOrThrow, codeOrNull
- **Failure.isRetryable** - 재시도 가능 에러 판별
- **ErrorCodeMessage** - 모든 에러코드 한국어 메시지

### Tests
- MidiService 유닛 테스트 (singleton, healthCheck, convert)
- FileManager 유닛 테스트 (exists, getSize, createTempPath)
- Result 테스트 확장 (retryable, userMessage)

## [2.1.0+5] - 2026-01-04

### Added
- **OfflineAwareMixin** - CaptureScreen, ConverterScreen에 오프라인 체크 통합
- **Analytics Events** - 모든 화면 및 주요 액션 추적
  - 화면 전환 (capture, converter)
  - 녹음 시작/완료
  - MIDI 변환 시작/성공/에러
  - 파일 공유 (MP3, MIDI)
- **Service Unit Tests** - ConnectivityService, AnalyticsService 테스트

### Changed
- CaptureScreen - 녹음 시작 전 오프라인 체크
- ConverterScreen - 변환 시작 전 오프라인 체크  
- ResultCard - 공유 시 Analytics 이벤트 발생

## [2.1.0+4] - 2026-01-03

### Changed
- **Firebase Graceful Degradation** - google-services.json 없이 빌드 가능
- AnalyticsService stub 구현 (debug 모드 콘솔 로깅)
- Firebase dependencies 주석 처리 (재활성화 용이)

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
