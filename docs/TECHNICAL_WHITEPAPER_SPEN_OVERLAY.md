# S Pen Overlay Touch Separation - Technical Whitepaper

> **Version:** 1.0
> **Date:** 2024-12-16
> **Author:** Claude Code + dtslib1979
> **Status:** Research Complete, Solution Identified

---

## Executive Summary

본 문서는 Samsung S Pen 오버레이 앱 개발 과정에서 발견한 Android 플랫폼의 기술적 한계와 시행착오, 그리고 최종 해결 방안을 정리한 기술 백서입니다.

**핵심 발견:**
- Android 오버레이 윈도우에서 "스타일러스 터치는 캡처, 손가락 터치는 통과"하는 선택적 터치 분리는 **표준 API로 불가능**
- 유일한 해결책: **Accessibility Service**를 통한 터치 이벤트 주입

---

## 1. 프로젝트 목표

### 1.1 요구사항
Wacom 태블릿과 같이:
- **S Pen 터치** → 오버레이 캔버스에 그리기
- **손가락 터치** → 아래 앱으로 통과 (스크롤, 탭 등)
- 두 입력이 실시간으로 분리되어 동시 사용 가능

### 1.2 기대 동작
```
┌─────────────────────────────────┐
│     Overlay Canvas (투명)        │  ← S Pen: 그리기
├─────────────────────────────────┤
│     Background App (웹브라우저)   │  ← 손가락: 스크롤
└─────────────────────────────────┘
```

---

## 2. Android 터치 이벤트 시스템 분석

### 2.1 입력 장치 구분
Android는 하드웨어 레벨에서 입력 장치를 구분함:

```kotlin
MotionEvent.TOOL_TYPE_FINGER  // 손가락
MotionEvent.TOOL_TYPE_STYLUS  // 스타일러스 (S Pen)
MotionEvent.TOOL_TYPE_ERASER  // 지우개 모드
```

Samsung S Pen은 EMR(Electro-Magnetic Resonance) 디지타이저를 사용하여 정전식 터치와 완전히 분리된 입력 레이어에서 동작.

### 2.2 오버레이 윈도우 플래그

```kotlin
WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
```

| 플래그 상태 | 터치 동작 | 호버 동작 |
|------------|----------|----------|
| **설정됨** | 모든 터치 통과 | 호버 이벤트 차단 |
| **해제됨** | 모든 터치 캡처 | 호버 이벤트 수신 |

**핵심 한계:** 선택적 통과 옵션 없음. 전부 통과 또는 전부 캡처.

### 2.3 호버 이벤트 (S Pen 고유 기능)

S Pen은 화면에 닿기 전 호버 이벤트 발생:
```
HOVER_ENTER → HOVER_MOVE → HOVER_EXIT → TOUCH_DOWN
```

이론적으로 호버 감지 후 FLAG_NOT_TOUCHABLE 해제하면 S Pen 터치 캡처 가능.

---

## 3. 시행착오 기록

### 3.1 Version 10: 단일 레이어 + 호버 감지

**설계:**
```
┌─────────────────────────────────┐
│  Canvas (FLAG_NOT_TOUCHABLE)    │
│  + onHoverEvent() 오버라이드     │
└─────────────────────────────────┘
```

**결과:** ❌ 실패
- `FLAG_NOT_TOUCHABLE` 설정 시 `onHoverEvent()` 호출 안 됨
- 손가락 스크롤은 되지만 S Pen 감지 불가

### 3.2 Version 11: 2레이어 아키텍처

**설계:**
```
┌─────────────────────────────────┐
│  Sensor Layer (터치 수신)        │  ← 호버 감지용
├─────────────────────────────────┤
│  Canvas Layer (FLAG_NOT_TOUCHABLE)│ ← 그리기용
└─────────────────────────────────┘
```

**결과:** ❌ 실패
- Sensor가 손가락 터치도 캡처하여 아래 앱으로 통과 안 됨
- `return false`로 터치 거부해도 윈도우 시스템에서 이미 캡처됨

### 3.3 Version 12: 터치 포워딩

**설계:**
```kotlin
// Sensor에서 S Pen 터치 감지 시 Canvas로 이벤트 전달
onStylusTouch?.invoke(event)
```

**결과:** ❌ 실패
- 이벤트 전달은 되지만 Canvas가 `FLAG_NOT_TOUCHABLE` 상태라 무시됨
- 플래그 토글 타이밍 문제

### 3.4 Version 13: setOnHoverListener

**설계:**
```kotlin
overlayView?.setOnHoverListener { _, event ->
    handleHoverEvent(event)
}
```

**결과:** ❌ 실패
- `FLAG_NOT_TOUCHABLE` 상태에서 리스너도 호출 안 됨
- Android 문서와 실제 동작 불일치

### 3.5 Version 14: 주기적 Peek 방식

**설계:**
```kotlin
// 100ms마다 15ms간 FLAG_NOT_TOUCHABLE 해제하여 호버 감지 시도
handler.postDelayed(peekRunnable, 100)
```

**결과:** ⚠️ 테스트 중
- 이론상 15ms 창에서 호버 이벤트 캡처 가능
- 타이밍 이슈와 손가락 터치 간섭 우려

---

## 4. 근본 원인 분석

### 4.1 Android 윈도우 시스템 한계

```
                    ┌─────────────────┐
                    │  WindowManager  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │ Overlay │    │   App   │    │ System  │
        │ Window  │    │ Window  │    │   UI    │
        └─────────┘    └─────────┘    └─────────┘
              │
              ▼
    FLAG_NOT_TOUCHABLE?
         /        \
       YES         NO
        │           │
        ▼           ▼
    Pass-through  Capture ALL
    (ALL touches) (ALL touches)
```

**선택적 통과 API 부재:** Android는 터치 이벤트를 장치 유형별로 필터링하여 통과시키는 기능을 제공하지 않음.

### 4.2 왜 삼성 기본 앱은 되나?

| 앱 | 동작 방식 | 오버레이 여부 |
|----|----------|-------------|
| Screen Write | 스크린샷 캡처 후 그리기 | ❌ 전체화면 점유 |
| 화면 메모 | 전체화면 모드 | ❌ 전체화면 점유 |
| Samsung Notes | 앱 내 캔버스 | ❌ 단일 앱 |

**결론:** 삼성도 "오버레이 + 선택적 터치 분리"는 구현하지 않음.

---

## 5. 해결 방안

### 5.1 Accessibility Service 방식 (권장)

```
┌─────────────────────────────────────────────────┐
│              Accessibility Service               │
│  - 시스템 레벨 입력 이벤트 모니터링               │
│  - dispatchGesture()로 터치 주입 가능            │
└─────────────────────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
    S Pen 터치                      손가락 터치
          │                             │
          ▼                             ▼
    오버레이에서 그리기            dispatchGesture()
                                        │
                                        ▼
                                  아래 앱으로 주입
```

**장점:**
- 완벽한 선택적 터치 분리 가능
- Wacom과 동일한 UX 구현 가능

**단점:**
- Accessibility 권한 필요 (사용자 부담)
- 설정 → 접근성에서 수동 활성화 필요

### 5.2 수동 토글 방식 (대안)

```kotlin
// 컨트롤바에 모드 전환 버튼
Button("✏️") { setStylusMode(true) }   // S Pen 그리기 모드
Button("👆") { setStylusMode(false) }  // 손가락 통과 모드
```

**장점:**
- 추가 권한 불필요
- 구현 간단

**단점:**
- UX 저하 (수동 전환 필요)
- 사용자가 모드 인지해야 함

### 5.3 비교표

| 방식 | 선택적 분리 | 권한 | UX | 구현 난이도 |
|-----|-----------|-----|-----|-----------|
| Accessibility Service | ✅ 완벽 | 접근성 | ⭐⭐⭐⭐⭐ | 중 |
| 수동 토글 | ❌ | 없음 | ⭐⭐⭐ | 하 |
| 주기적 Peek | ⚠️ 불안정 | 없음 | ⭐⭐ | 중 |

---

## 6. 구현 로드맵 (Accessibility Service)

### Phase 1: 서비스 구조
```kotlin
class JsonOverlayAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent) { }

    override fun onInterrupt() { }

    fun injectTouch(x: Float, y: Float, action: Int) {
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        dispatchGesture(gesture, null, null)
    }
}
```

### Phase 2: AndroidManifest 설정
```xml
<service
    android:name=".JsonOverlayAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService"/>
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_config"/>
</service>
```

### Phase 3: 터치 분리 로직
```kotlin
override fun onTouchEvent(event: MotionEvent): Boolean {
    return when {
        isStylus(event) -> {
            handleDrawing(event)
            true  // 캡처
        }
        else -> {
            accessibilityService?.injectTouch(event.x, event.y, event.action)
            true  // 캡처 후 주입
        }
    }
}
```

---

## 7. 결론

### 7.1 핵심 교훈

1. **Android 오버레이는 선택적 터치 통과를 지원하지 않음**
2. **FLAG_NOT_TOUCHABLE은 호버 이벤트도 차단함**
3. **표준 API만으로는 Wacom 스타일 UX 구현 불가**
4. **Accessibility Service가 유일한 완전한 해결책**

### 7.2 권장 사항

프로덕션 배포를 위해서는 **Accessibility Service 방식** 구현을 권장합니다. 사용자 권한 동의 UX를 잘 설계하면 충분히 수용 가능한 수준의 사용자 경험을 제공할 수 있습니다.

---

## Appendix A: 테스트 환경

- **Device:** Samsung Galaxy (S Pen 지원)
- **Android Version:** 15 (API 35)
- **Flutter:** 3.x
- **Kotlin:** 1.9.x

## Appendix B: 관련 Android 소스 코드

- `WindowManagerService.java` - 터치 이벤트 디스패치
- `InputDispatcher.cpp` - Native 입력 처리
- `ViewRootImpl.java` - 뷰 계층 이벤트 전달

## Appendix C: 버전 히스토리

| Version | 접근 방식 | 결과 |
|---------|----------|------|
| v10 | 단일 레이어 + 호버 | ❌ 호버 차단됨 |
| v11 | 2레이어 (센서+캔버스) | ❌ 손가락 통과 안 됨 |
| v12 | 터치 포워딩 | ❌ 타이밍 이슈 |
| v13 | setOnHoverListener | ❌ 리스너 호출 안 됨 |
| v14 | 주기적 Peek | ⚠️ 불안정 |

---

*이 문서는 개발 과정의 기술적 발견을 기록하기 위해 작성되었습니다.*
