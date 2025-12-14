# S Pen 웹 오버레이 판서 앱 — 기술백서

> 버전 2.0 | 2025.12.14 | 구현 완료

## 1. Executive Summary

Galaxy Tab S9 환경에서 웹페이지 위에 S Pen으로 판서하고, 손가락으로는 스크롤/조작이 가능한 오버레이 앱.

| 항목 | 내용 |
|------|------|
| **프로젝트명** | Laser Pen Overlay |
| **대상 디바이스** | Galaxy Tab S9 (Android 13+) |
| **사용 목적** | 화면녹화용 실시간 판서 (세로 Portrait 모드) |
| **핵심 기능** | S Pen 판서 + 손가락 통과 + 3초 Fade-out |

---

## 2. 기능 요구사항

### 2.1 입력 분리 (Input Discrimination)

| 입력 타입 | 동작 | 구현 방식 |
|-----------|------|-----------|
| S Pen (Stylus) | 오버레이 Canvas에 판서 | `MotionEvent.TOOL_TYPE_STYLUS` |
| 손가락 (Finger) | 하위 앱으로 Pass-through | `dispatchTouchEvent return false` |

### 2.2 레이저펜 효과 (Fade-out)

Samsung Notes 레이저펜 UX 재현:
- 스트로크 생성 후 **3초간 유지**
- 3.0초 ~ 3.5초: Opacity 1.0 → 0.0 (Fade-out)
- 3.5초 이후: 스트로크 삭제 (메모리 해제)

### 2.3 UI 구성

| 버튼 | 동작 |
|------|------|
| 🎨 색상 | 흰색 ↔ 노랑 ↔ 검정 ↔ 빨강 ↔ 시안 순환 |
| ◀ Undo | 마지막 스트로크 제거 |
| ▶ Redo | 제거된 스트로크 복원 |
| 🧹 Clear | 전체 스트로크 삭제 |
| ✕ Exit | 오버레이 종료 |

---

## 3. 시스템 아키텍처

### 3.1 기술 스택

| 레이어 | 기술 |
|--------|------|
| UI Framework | Flutter 3.24.0 (Dart) |
| Native Bridge | Kotlin (Android Native) |
| 터치 분기 | `MotionEvent.getToolType()` |
| 오버레이 | `SYSTEM_ALERT_WINDOW` + `WindowManager` |
| 렌더링 | Custom Android View (Canvas) |

### 3.2 아키텍처 다이어그램

```
┌─────────────────────────────────────────────┐
│           Flutter UI Layer                   │
│  ┌─────────┐  ┌─────────┐  ┌────────────┐  │
│  │ Buttons │  │ Canvas  │  │ Stroke Mgr │  │
│  └─────────┘  └─────────┘  └────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ MethodChannel
┌──────────────────▼──────────────────────────┐
│          Kotlin Native Layer                 │
│  ┌─────────────────────────────────────┐    │
│  │         TouchDispatcher              │    │
│  │  if(toolType==STYLUS) → Canvas       │    │
│  │  if(toolType==FINGER) → PassThrough  │    │
│  └─────────────────────────────────────┘    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│        Android WindowManager                 │
│   TYPE_APPLICATION_OVERLAY + OverlayView     │
└─────────────────────────────────────────────┘
```

### 3.3 핵심 제약사항 (해결됨)

**순수 Flutter로 구현 불가능한 이유:**
```
Android 입력 시스템: stylus ⊂ touch_event
flutter_overlay_window.notTouchable:
  touch_event 전체 → pass-through
  ∴ stylus_event도 함께 pass-through됨
```

**해결책:** Kotlin Native에서 `MotionEvent.getToolType()` 분기 처리

---

## 4. 구현 완료 현황

| Phase | 작업 내용 | 상태 | 산출물 |
|-------|----------|------|--------|
| Phase 1 | Kotlin TouchDispatcher 구현 | ✅ | OverlayCanvasView.kt |
| Phase 2 | Flutter-Kotlin MethodChannel 브릿지 | ✅ | MainActivity.kt |
| Phase 3 | Canvas + Stroke 모델 구현 | ✅ | OverlayCanvasView.kt |
| Phase 4 | Fade-out 타이머 + UI 버튼 구현 | ✅ | FloatingControlBar.kt |
| Phase 5 | Galaxy Tab S9 실기기 테스트 | ⏳ | APK Artifact |

---

## 5. 핵심 코드

### 5.1 Stylus/Finger 분기 (OverlayCanvasView.kt)

```kotlin
private fun isStylus(event: MotionEvent): Boolean {
    val toolType = event.getToolType(0)
    if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
        toolType == MotionEvent.TOOL_TYPE_ERASER) {
        return true
    }
    // Fallback: SOURCE_STYLUS 체크
    if ((event.source and InputDevice.SOURCE_STYLUS) == InputDevice.SOURCE_STYLUS) {
        return true
    }
    return false
}

override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    // Finger → pass-through (하위 앱으로)
    if (!isStylus(event)) {
        return false
    }
    // Stylus → 이 View에서 처리
    return super.dispatchTouchEvent(event)
}
```

### 5.2 Fade-out 로직

```kotlin
data class StrokeData(
    val segments: List<PathSegment>,
    val color: Int,
    val createdAt: Long
) {
    fun getOpacity(): Float {
        val elapsed = System.currentTimeMillis() - createdAt
        return when {
            elapsed < 3000 -> 1f           // 3초간 100%
            elapsed > 3500 -> 0f           // 3.5초 후 0%
            else -> 1f - ((elapsed - 3000) / 500f)  // 0.5초간 fade
        }
    }
    
    fun isExpired(): Boolean {
        return System.currentTimeMillis() - createdAt > 3500
    }
}
```

---

## 6. 파일 구조

```
apps/laser-pen-overlay/
├── lib/
│   ├── main.dart
│   ├── screens/drawing_screen.dart
│   ├── models/
│   ├── services/
│   └── widgets/
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   └── kotlin/com/dtslib/laser_pen_overlay/
│       ├── MainActivity.kt
│       ├── OverlayService.kt
│       ├── OverlayCanvasView.kt
│       ├── FloatingControlBar.kt
│       └── LaserPenTileService.kt
└── pubspec.yaml
```

---

## 7. 성공 기준

| # | 기준 | 상태 |
|---|------|------|
| 1 | S Pen 입력 시 Canvas에 정상 렌더링 (100% 인식) | ⏳ 실기기 테스트 |
| 2 | 손가락 입력 시 웹페이지 스크롤/클릭 정상 동작 | ⏳ 실기기 테스트 |
| 3 | 스트로크 3초 후 Fade-out 자연스러움 | ✅ 구현 완료 |
| 4 | UI 렌더링 60fps 유지 (화면녹화 중) | ⏳ 실기기 테스트 |
| 5 | 색상 전환 0.3초 이내 반응 | ✅ 구현 완료 |

---

## 8. APK 다운로드

1. [GitHub Actions](https://github.com/dtslib1979/dtslib-apk-lab/actions/workflows/build-laser-pen.yml)
2. 최신 빌드의 **laser-pen-overlay-debug** artifact 다운로드
3. Galaxy Tab S9에 설치

---

*Personal use only. Not for distribution.*
