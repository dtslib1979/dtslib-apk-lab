# Laser Pen Overlay - Roadmap

## v1.0 (현재) ✅
- 풀스크린 판서 앱
- S Pen / Finger 입력 분리 (MotionEvent.getToolType)
- 3초 fade-out 효과
- 색상 순환 (흰/노/검)
- Undo/Redo/Clear/Exit

## v2.0 (계획)
실제 시스템 오버레이 구현

### 핵심 기능
- [ ] Android Foreground Service
- [ ] WindowManager로 투명 오버레이 생성
- [ ] S Pen → 오버레이 캔버스
- [ ] Finger → 하위 앱으로 pass-through

### 기술 요구사항
```kotlin
// WindowManager.LayoutParams
TYPE_APPLICATION_OVERLAY
FLAG_NOT_FOCUSABLE
FLAG_NOT_TOUCH_MODAL
FLAG_LAYOUT_IN_SCREEN
```

### 구현 단계
1. OverlayService.kt (Foreground Service)
2. OverlayView.kt (Custom View + Canvas)
3. TouchDispatcher (Stylus/Finger 분기)
4. Flutter → Service 연동 (MethodChannel)

### 리스크
- Android 12+ 오버레이 정책 변경
- Samsung One UI 특이사항
- 성능 (60fps 유지)

## v2.1 (미래)
- 위젯으로 빠른 토글
- 화면녹화 연동
- 펜 굵기 조절
