# Overlay Dual Subtitle

> Personal use only. No distribution.

실시간 이중자막 오버레이 앱 (Galaxy Tab S9)

## Features (v1)

- 화면 위 오버레이 자막 (KO + EN + Dictation)
- 마이크 입력 → 서버 STT/번역
- Mock 모드 데모 지원
- 레이턴시 연출 (동시통역 느낌)
- 설정: 폰트 크기, 투명도, 너비, 딜레이

## UI 구성

### Floating Bubble (48dp)
- **탭**: 자막 박스 show/hide
- **롱프레스**: 설정 패널 열기
- **드래그**: 위치 이동

### Subtitle Box
- **KO 라인**: 노란색
- **EN 라인**: 흰색
- **DICT 라인**: 회색 (설정에서 활성화)
- **드래그**: 위치 이동 (잠금 해제 시)

### Settings Panel
- Font Size: 12~28sp
- Opacity: 30~100%
- Width: 50~100%
- Delay: 0~1500ms
- Show Dictation: ON/OFF
- Lock Position: ON/OFF

## Permissions

1. **오버레이 권한**: 설정 → 앱 → 특별한 접근 → 다른 앱 위에 표시
2. **마이크 권한**: 런타임 요청

## Install

1. GitHub Actions → Artifacts → `overlay-dual-sub-debug` 다운로드
2. APK 설치
3. 오버레이 권한 허용
4. Start 버튼 탭

## Mode Switch

`MainActivity.kt` 에서:
```kotlin
val useMock = true  // Mock 모드 (서버 없이 데모)
val useMock = false // WebSocket 모드 (서버 필요)
```

## Mock 모드 동작

- 2.5초마다 새 문장 생성
- Dictation → 즉시 표시
- KO → delay × 0.8 후 표시
- EN → delay × 1.6 후 표시
- 동시통역 UX 시뮬레이션

## WebSocket 서버 프로토콜

### 다운링크 (서버 → 앱)
```json
{
  "segId": 123,
  "dictation": "Hello, how are you?",
  "ko": "안녕하세요, 어떻게 지내세요?",
  "en": "Hello, how are you?"
}
```

### 업링크 (앱 → 서버)
- PCM16 mono 16kHz 바이너리 청크 (500ms)

## Tech Stack

- Kotlin + Jetpack Compose
- Min SDK 29 (Android 10)
- Target SDK 34
- Foreground Service + TYPE_APPLICATION_OVERLAY
- OkHttp WebSocket

## Project Structure

```
app/src/main/java/.../overlaydualsub/
├── MainActivity.kt
├── service/
│   └── OverlayService.kt
├── overlay/
│   ├── OverlayWindowController.kt
│   ├── BubbleComposable.kt
│   ├── SubtitleBoxComposable.kt
│   └── SettingsPanelComposable.kt
├── audio/
│   └── MicAudioCapturer.kt
├── net/
│   ├── SubtitleStreamClient.kt
│   ├── MockSubtitleClient.kt
│   └── WsSubtitleClient.kt
└── model/
    ├── SubtitleEvent.kt
    └── OverlaySettings.kt
```

## Version

v1.0.0

## Troubleshooting

### 오버레이가 안 보여요
- 설정 → 앱 → Dual Subtitle → 다른 앱 위에 표시 허용

### Mock 자막이 안 나와요
- Start 버튼 눌렀는지 확인
- 알림바에 "Mock 모드 실행 중" 표시 확인

### 자막 위치가 이상해요
- 버블 롱프레스 → 설정 → Lock Position OFF
- 자막 박스 드래그로 위치 조정
