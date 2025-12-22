# Overlay Dual Subtitle

> Personal use only. No distribution.

실시간 이중자막 오버레이 앱 (Galaxy Tab S9)

## Features (v1)

- 화면 위 오버레이 자막 (KO + EN)
- 마이크 입력 → 서버 STT/번역
- Mock 모드 데모 지원
- 레이턴시 연출 (동시통역 느낌)

## Permissions

1. **오버레이 권한**: 설정 → 앱 → 특별한 접근 → 다른 앱 위에 표시
2. **마이크 권한**: 런타임 요청

## Install

1. GitHub Actions → Artifacts → `app-debug.apk` 다운로드
2. APK 설치
3. 오버레이 권한 허용
4. Start 버튼 탭

## Mode Switch

`MainActivity.kt` 에서:
```kotlin
val useMock = true  // Mock 모드
val useMock = false // WebSocket 모드
```

## Tech Stack

- Kotlin + Jetpack Compose
- Min SDK 29 (Android 10)
- Foreground Service + TYPE_APPLICATION_OVERLAY
- OkHttp WebSocket

## Version

v1.0.0
