# S Pen Overlay 최종 솔루션 - 기술 백서

> **Version:** 18.0.0 (Final)
> **Date:** 2024-12-16
> **Status:** Production Ready

---

## Executive Summary

Samsung S Pen과 손가락 터치를 완벽히 분리하여, Wacom 태블릿처럼 S Pen으로 그리면서 동시에 손가락으로 스크롤/터치가 가능한 오버레이 시스템 구현 완료.

---

## 1. 최종 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                        사용자 입력                           │
│              ┌──────────┐      ┌──────────┐                 │
│              │  S Pen   │      │  손가락   │                 │
│              └────┬─────┘      └────┬─────┘                 │
│                   │                 │                       │
│                   ▼                 ▼                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              OverlayCanvasView                       │   │
│  │         (FLAG_NOT_TOUCHABLE 없음)                    │   │
│  │                                                      │   │
│  │   isStylus(event)?                                   │   │
│  │      ├── YES → handleStylusTouch() → 그리기          │   │
│  │      └── NO  → handleFingerTouch() ─┐               │   │
│  └──────────────────────────────────────│───────────────┘   │
│                                         │                   │
│                                         ▼                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              OverlayService                          │   │
│  │         setPassthroughMode(true)                     │   │
│  │         FLAG_NOT_TOUCHABLE 추가                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                         │                   │
│                                         ▼                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           TouchInjectionService                      │   │
│  │         (AccessibilityService)                       │   │
│  │                                                      │   │
│  │   dispatchGesture() → 시스템 레벨 터치 주입          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                         │                   │
│                                         ▼                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 아래 앱                              │   │
│  │         (웹브라우저, 문서 뷰어 등)                    │   │
│  │                                                      │   │
│  │         손가락 스크롤/탭 정상 동작                    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 핵심 알고리즘

### 2.1 터치 분리 로직

```kotlin
override fun onTouchEvent(event: MotionEvent): Boolean {
    val isStylus = isStylus(event)

    return if (isStylus) {
        handleStylusTouch(event)  // S Pen → 그리기
    } else {
        handleFingerTouch(event)  // 손가락 → 주입
    }
}
```

### 2.2 S Pen 감지

```kotlin
private fun isStylus(event: MotionEvent): Boolean {
    // 방법 1: toolType (가장 정확)
    for (i in 0 until event.pointerCount) {
        when (event.getToolType(i)) {
            MotionEvent.TOOL_TYPE_STYLUS,
            MotionEvent.TOOL_TYPE_ERASER -> return true
        }
    }

    // 방법 2: source (구형 기기 대응)
    if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
        return true
    }

    return false
}
```

### 2.3 손가락 터치 주입 (핵심!)

```kotlin
private fun handleFingerTouch(event: MotionEvent): Boolean {
    val injectionService = TouchInjectionService.instance
    val overlayService = OverlayService.instance

    // 1. 터치 시작 시: 오버레이를 패스스루 모드로 전환
    if (event.actionMasked == MotionEvent.ACTION_DOWN) {
        overlayService?.setPassthroughMode(true)  // FLAG_NOT_TOUCHABLE 추가
    }

    // 2. 터치 이벤트를 Accessibility Service로 전달
    injectionService.injectTouchEvent(event)

    // 3. 터치 종료 시: 패스스루 모드 해제
    if (event.actionMasked == MotionEvent.ACTION_UP ||
        event.actionMasked == MotionEvent.ACTION_CANCEL) {
        Handler(Looper.getMainLooper()).postDelayed({
            overlayService?.setPassthroughMode(false)  // FLAG_NOT_TOUCHABLE 제거
        }, 100)
    }

    return true
}
```

### 2.4 패스스루 모드 전환

```kotlin
fun setPassthroughMode(enabled: Boolean) {
    canvasParams?.let { params ->
        if (enabled) {
            // 손가락 터치 통과 (주입된 제스처가 아래 앱으로 감)
            params.flags = params.flags or FLAG_NOT_TOUCHABLE
        } else {
            // 터치 수신 (S Pen 감지 가능)
            params.flags = params.flags and FLAG_NOT_TOUCHABLE.inv()
        }
        windowManager?.updateViewLayout(overlayView, params)
    }
}
```

### 2.5 제스처 주입 (AccessibilityService)

```kotlin
fun injectTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
        ACTION_DOWN -> startGesture(event.x, event.y)
        ACTION_MOVE -> continueGesture(event.x, event.y)
        ACTION_UP -> endGesture(event.x, event.y)
    }
    return true
}

private fun endGesture(x: Float, y: Float) {
    gesture.path.lineTo(x, y)

    val strokeDescription = GestureDescription.StrokeDescription(
        gesture.path,
        0,
        gestureDuration
    )

    val gestureDescription = GestureDescription.Builder()
        .addStroke(strokeDescription)
        .build()

    // 시스템 레벨에서 터치 주입
    dispatchGesture(gestureDescription, callback, null)
}
```

---

## 3. 왜 이 방법이 작동하는가?

### 3.1 문제의 본질

Android 오버레이 윈도우에서 터치를 아래 앱으로 전달하는 유일한 방법은 `FLAG_NOT_TOUCHABLE`이다. 하지만 이 플래그를 설정하면 모든 터치가 통과되어 S Pen도 감지할 수 없다.

### 3.2 해결책: 동적 플래그 전환 + 제스처 주입

1. **기본 상태**: `FLAG_NOT_TOUCHABLE` 없음 → 모든 터치 수신
2. **S Pen 터치**: 그대로 캔버스에서 처리 (그리기)
3. **손가락 터치 감지 시**:
   - 즉시 `FLAG_NOT_TOUCHABLE` 추가 (패스스루 모드)
   - AccessibilityService의 `dispatchGesture()`로 터치 재생성
   - 재생성된 터치는 오버레이를 통과하여 아래 앱에 도달
4. **손가락 터치 종료 시**: `FLAG_NOT_TOUCHABLE` 제거 → 다시 터치 수신 가능

### 3.3 타이밍 다이어그램

```
시간 →

손가락 DOWN 감지
    │
    ├── setPassthroughMode(true)  ← FLAG_NOT_TOUCHABLE 추가
    │
    ├── dispatchGesture(DOWN)     ← 터치 주입 시작
    │
손가락 MOVE...
    │
    ├── dispatchGesture(MOVE)     ← 터치 주입 계속
    │
손가락 UP 감지
    │
    ├── dispatchGesture(UP)       ← 터치 주입 완료
    │
    └── 100ms 후 setPassthroughMode(false)  ← FLAG_NOT_TOUCHABLE 제거
```

---

## 4. 필수 컴포넌트

### 4.1 파일 구조

```
android/app/src/main/
├── kotlin/com/dtslib/laser_pen_overlay/
│   ├── MainActivity.kt           # 권한 처리
│   ├── OverlayService.kt         # 오버레이 관리
│   ├── OverlayCanvasView.kt      # 터치 분리 + 그리기
│   ├── TouchInjectionService.kt  # 제스처 주입 (AccessibilityService)
│   ├── FloatingControlBar.kt     # 컨트롤 바
│   └── LaserPenTileService.kt    # Quick Settings 타일
├── res/
│   ├── xml/
│   │   └── accessibility_service_config.xml
│   └── values/
│       └── strings.xml
└── AndroidManifest.xml
```

### 4.2 권한

```xml
<!-- 오버레이 -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>

<!-- 포그라운드 서비스 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>

<!-- 알림 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- 접근성 서비스 (터치 주입용) -->
<!-- AndroidManifest.xml에 서비스 등록 필요 -->
```

### 4.3 접근성 서비스 설정

```xml
<!-- res/xml/accessibility_service_config.xml -->
<accessibility-service
    android:description="@string/accessibility_service_description"
    android:canPerformGestures="true"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagDefault"
    android:canRetrieveWindowContent="false" />
```

---

## 5. 사용자 설정 가이드

### 5.1 최초 설치 후

1. **오버레이 권한**: 앱 실행 시 자동 요청 → 허용
2. **제한된 설정 허용**: 앱 정보 → ⋮ → "제한된 설정 허용"
3. **접근성 서비스**: 설정 → 접근성 → "Laser Pen 터치 전달" → 켜기

### 5.2 업데이트 시

- 새 APK 설치 후 "제한된 설정 허용" 다시 필요 (Android 13+ 보안 정책)

---

## 6. 이전 시도 및 실패 원인

| 버전 | 접근 방식 | 실패 원인 |
|-----|----------|----------|
| v10-v14 | FLAG_NOT_TOUCHABLE + 호버 감지 | 호버 이벤트도 차단됨 |
| v15 | AccessibilityService 제스처 주입 | 주입된 제스처가 오버레이에 다시 캡처됨 |
| v16+ | 동적 패스스루 + 제스처 주입 | ✅ 성공 |

---

## 7. 결론

### 핵심 인사이트

1. **Android는 선택적 터치 통과를 지원하지 않음** - FLAG_NOT_TOUCHABLE은 전부 or 전무
2. **AccessibilityService의 dispatchGesture()는 시스템 레벨 터치 주입** - 윈도우 계층 무시
3. **핵심은 타이밍** - 손가락 터치 감지 즉시 패스스루 모드로 전환해야 주입된 제스처가 오버레이를 통과

### 최종 공식

```
S Pen 그리기 + 손가락 스크롤 동시 사용 =
    터치 분리 (isStylus) +
    동적 FLAG_NOT_TOUCHABLE 전환 +
    AccessibilityService 제스처 주입
```

---

## Appendix: 테스트 환경

- **Device**: Samsung Galaxy (S Pen 지원)
- **Android**: 15 (API 35)
- **개발 환경**: Termux + Flutter + Kotlin

---

*이 솔루션은 Wacom 스타일의 펜/터치 분리를 Android 오버레이에서 구현한 최초의 완전한 해결책입니다.*
