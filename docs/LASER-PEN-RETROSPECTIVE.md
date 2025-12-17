# Laser Pen Overlay 개발 회고록

> **프로젝트**: Laser Pen Overlay
> **기간**: 2025년 12월 15일 ~ 17일 (3일간)
> **최종 버전**: v25.12.0
> **개발 환경**: Termux + Claude Code (AI Pair Programming)

---

## 1. 프로젝트 개요

### 목표
Samsung S Pen과 손가락 터치를 분리하여 Wacom 타블렛처럼 동작하는 오버레이 앱 개발

### 핵심 요구사항
- S Pen → 캔버스에 그리기
- 손가락 → 아래 앱으로 터치 전달 (스크롤, 탭 등)
- 화면 녹화 시 컨트롤바 숨김
- 낮은 레이턴시

---

## 2. 버전 히스토리

| 버전 | 주요 변경 | 결과 |
|------|----------|------|
| v7.0 ~ v18 | 기본 S Pen/손가락 분리 구현 | 성공 |
| v19 | 화면 녹화 감지 기능 추가 | 부분 성공 |
| v20 | FLAG_SECURE로 녹화 시 UI 숨김 시도 | **실패** |
| v21 | willContinue 실시간 스트리밍 시도 | **실패** |
| v22 | 터치 주입 롤백 | 복구 |
| v24 | 극단적 투명도 (Ghost Mode) | 성공 |
| v24.1 | 터치 주입 안정화 | 성공 |
| v24.2 | 핸들만 살짝 보이게 조정 | 성공 |
| v25.12 | 예쁜 아이콘 + 최종 릴리즈 | **완료** |

---

## 3. 주요 시행착오 및 교훈

### 3.1 FLAG_SECURE 실패

#### 시도한 것
```kotlin
// 컨트롤바에 FLAG_SECURE 적용
barParams = WindowManager.LayoutParams(...).apply {
    flags = flags or WindowManager.LayoutParams.FLAG_SECURE
}
```

#### 기대한 결과
- 컨트롤바만 화면 녹화에서 제외
- 캔버스와 아래 앱은 정상 녹화

#### 실제 결과
```
"보안 정책상 화면 녹화를 할 수 없습니다"
```
- **전체 화면 녹화가 차단됨**
- FLAG_SECURE는 요소 단위가 아닌 **화면 전체**에 적용
- 삼성 UI가 녹화에서 제외되는 건 **시스템 권한** (일반 앱 불가)

#### 교훈
> FLAG_SECURE는 보안 기능이지 UI 숨김 기능이 아니다.
> 일반 앱이 녹화에서 특정 요소만 제외하는 것은 **불가능**하다.

---

### 3.2 willContinue 실시간 스트리밍 실패

#### 시도한 것
```kotlin
// 실시간 제스처 스트리밍 시도
private fun continueGesture(x: Float, y: Float) {
    currentGesture?.let { gesture ->
        gesture.path.lineTo(x, y)

        // willContinue=true로 실시간 전송
        val stroke = GestureDescription.StrokeDescription(
            gesture.path, 0, 16, true  // willContinue = true
        )
        val gestureDesc = GestureDescription.Builder()
            .addStroke(stroke)
            .build()
        dispatchGesture(gestureDesc, callback, null)
    }
}
```

#### 기대한 결과
- ACTION_MOVE마다 실시간으로 아래 앱에 터치 전달
- 레이턴시 감소

#### 실제 결과
```
"먹통이 돼버렸네"
```
- **터치 주입이 완전히 작동 안 함**
- dispatchGesture의 willContinue는 연속 제스처용이 아님
- 동일 Path를 여러 번 dispatch하면 충돌 발생

#### 교훈
> dispatchGesture는 **완성된 제스처**를 한 번에 주입하는 API다.
> 실시간 스트리밍은 InputManager.injectInputEvent() 필요 (루트 권한).
> **레이턴시는 API 한계로 해결 불가**.

---

### 3.3 투명도 조절 시행착오

#### 첫 번째 시도: 전부 극단 투명
```kotlin
setTextColor(Color.argb(5, 255, 255, 255))  // alpha 5
background = GradientDrawable().apply {
    setColor(Color.argb(3, 60, 60, 60))  // alpha 3
}
```

#### 결과
```
"나도 안 보여"
```

#### 최종 해결책
```kotlin
// 핸들만 살짝 보임 (사용자 참조용)
setTextColor(Color.argb(50, 255, 255, 255))   // alpha 50
setColor(Color.argb(25, 100, 100, 100))       // alpha 25

// 나머지 버튼은 극단 투명 (녹화 시 안 보임)
setTextColor(Color.argb(12, 255, 255, 255))   // alpha 12
setColor(Color.argb(5, 60, 60, 60))           // alpha 5
```

#### 교훈
> 사용자 경험과 녹화 품질 사이의 **균형점**을 찾아야 한다.
> 완전히 안 보이면 사용자도 못 쓴다.

---

## 4. 기술적 성과

### 4.1 S Pen / 손가락 분리 (핵심 성공)
```kotlin
override fun onTouchEvent(event: MotionEvent): Boolean {
    val isStylus = event.getToolType(0) == MotionEvent.TOOL_TYPE_STYLUS

    if (isStylus) {
        // S Pen → 캔버스에 그리기
        handleStylusDrawing(event)
    } else {
        // 손가락 → AccessibilityService로 아래 앱에 주입
        TouchInjectionService.instance?.injectTouchEvent(event)
    }
    return true
}
```

### 4.2 AccessibilityService 제스처 주입
```kotlin
private fun endGesture(x: Float, y: Float) {
    val gesture = currentGesture ?: return
    gesture.path.lineTo(x, y)

    val duration = (System.currentTimeMillis() - gesture.startTime)
        .coerceIn(50, 1000)

    val strokeDesc = GestureDescription.StrokeDescription(
        gesture.path, 0, duration
    )
    val gestureDesc = GestureDescription.Builder()
        .addStroke(strokeDesc)
        .build()

    dispatchGesture(gestureDesc, callback, null)
}
```

### 4.3 동적 FLAG_NOT_TOUCHABLE 전환
```kotlin
fun setPassthroughMode(enabled: Boolean) {
    canvasParams?.let { params ->
        if (enabled) {
            params.flags = params.flags or FLAG_NOT_TOUCHABLE
        } else {
            params.flags = params.flags and FLAG_NOT_TOUCHABLE.inv()
        }
        windowManager?.updateViewLayout(overlayView, params)
    }
}
```

---

## 5. 수용한 한계점

| 한계 | 이유 | 대안 |
|------|------|------|
| 녹화 시 UI 완전 숨김 불가 | 시스템 권한 필요 | Ghost 투명도 |
| 스크롤 레이턴시 | dispatchGesture API 한계 | 없음 (루트 필요) |
| 실시간 터치 전달 불가 | willContinue 미지원 | PATH 수집 후 한번에 주입 |

---

## 6. 개발 과정에서 배운 점

### 6.1 Android 보안 모델 이해
- FLAG_SECURE는 **화면 전체**에 적용
- 일반 앱은 화면 녹화 내용 제어 불가
- 시스템 앱만 특정 요소 제외 가능

### 6.2 AccessibilityService 한계
- dispatchGesture는 **완성된 경로**만 주입 가능
- 실시간 스트리밍 미지원
- 레이턴시는 불가피

### 6.3 UX 타협점 찾기
- 기술적 불가능 시 **시각적 트릭** 활용
- "안 보이게" 대신 "거의 안 보이게"
- 사용자 최소 참조점 유지

### 6.4 롤백의 중요성
- 실험적 변경 전 **작동하는 버전 보존**
- 실패 시 빠른 롤백으로 피해 최소화
- Git 커밋 단위를 작게 유지

---

## 7. 최종 아키텍처

```
┌─────────────────────────────────────────────┐
│                OverlayService               │
│  - WindowManager 오버레이 관리              │
│  - 알림 & Quick Settings Tile              │
└─────────────────┬───────────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    ▼                           ▼
┌───────────────┐       ┌───────────────────┐
│OverlayCanvas  │       │FloatingControlBar │
│ View          │       │ (Ghost Mode)      │
│               │       │                   │
│ S Pen → Draw  │       │ 색상/Undo/Redo    │
│ 손가락 → Pass │       │ Clear/Close       │
└───────┬───────┘       └───────────────────┘
        │
        ▼
┌───────────────────┐
│TouchInjection     │
│Service            │
│(Accessibility)    │
│                   │
│ dispatchGesture() │
│ → 아래 앱 터치    │
└───────────────────┘
```

---

## 8. 파일 구조

```
apps/laser-pen-overlay/
├── android/app/src/main/kotlin/com/dtslib/laser_pen_overlay/
│   ├── MainActivity.kt           # Flutter ↔ Native 브릿지
│   ├── OverlayService.kt         # 오버레이 관리 (416줄)
│   ├── OverlayCanvasView.kt      # 캔버스 & 터치 분리
│   ├── FloatingControlBar.kt     # Ghost 컨트롤바 (278줄)
│   ├── TouchInjectionService.kt  # 제스처 주입 (225줄)
│   └── LaserPenTileService.kt    # Quick Settings
├── android/app/src/main/res/
│   ├── drawable/
│   │   ├── ic_launcher.xml           # 앱 아이콘
│   │   └── ic_launcher_foreground.xml # S Pen + Laser 디자인
│   └── xml/
│       └── accessibility_service_config.xml
├── lib/main.dart                 # Flutter UI (권한 요청)
├── pubspec.yaml                  # v25.12.0+31
└── app-meta.json                 # 대시보드 메타데이터
```

---

## 9. 향후 개선 가능성

| 항목 | 필요 조건 | 난이도 |
|------|----------|--------|
| 레이턴시 개선 | 루트 권한 + InputManager | 높음 |
| 녹화 시 UI 완전 숨김 | 시스템 앱 서명 | 불가능 |
| 펜 압력 감지 | S Pen API 연동 | 중간 |
| 제스처 커스터마이징 | 설정 UI 추가 | 낮음 |

---

## 10. 결론

### 성공한 것
- S Pen / 손가락 완벽 분리
- Ghost 투명도로 녹화 품질 확보
- 안정적인 터치 주입
- 예쁜 앱 아이콘

### 실패했지만 배운 것
- FLAG_SECURE의 진짜 동작 방식
- dispatchGesture의 한계
- Android 보안 모델의 견고함

### 핵심 교훈
> **"안 되는 건 안 되는 거다"**
> 기술적 한계를 인정하고 우회 방법을 찾는 것이 실용적이다.
> 완벽한 해결책이 없을 때 **타협점**을 찾는 것도 엔지니어링이다.

---

*작성: Claude Code (AI Pair Programming)*
*프로젝트: https://github.com/dtslib1979/dtslib-apk-lab*
*대시보드: https://dtslib-apk-lab.vercel.app/*
