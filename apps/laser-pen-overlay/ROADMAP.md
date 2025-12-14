# Laser Pen Overlay - Roadmap

## v1.0 ✅
- 풀스크린 판서 앱
- S Pen / Finger 입력 분리 (MotionEvent.getToolType)
- 3초 fade-out 효과
- 색상 순환 (흰/노/검)
- Undo/Redo/Clear/Exit

## v2.0 ✅ (Current)
실제 시스템 오버레이 구현 완료

### 핵심 기능 ✅
- [x] Android Foreground Service (OverlayService.kt)
- [x] WindowManager로 투명 오버레이 생성
- [x] S Pen → 오버레이 캔버스 (TOOL_TYPE_STYLUS)
- [x] Finger → 하위 앱으로 pass-through (dispatchTouchEvent return false)

### 구현 완료 파일
```
kotlin/
├── MainActivity.kt          # Flutter MethodChannel 브릿지
├── OverlayService.kt         # Foreground Service + WindowManager
├── OverlayCanvasView.kt      # Stylus/Finger 분기 + Canvas
├── FloatingControlBar.kt     # 하단 컨트롤 버튼
└── LaserPenTileService.kt    # Quick Settings 타일
```

### 핵심 로직
```kotlin
// OverlayCanvasView.kt
override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    if (!isStylus(event)) return false  // Finger → pass-through
    return super.dispatchTouchEvent(event)  // Stylus → Canvas
}
```

### 색상 팔레트
- ⚪ WHITE
- 🟡 YELLOW  
- ⚫ BLACK
- 🔴 RED
- 🔵 CYAN

## v2.1 (미래)
- [ ] 위젯으로 빠른 토글
- [ ] 화면녹화 연동
- [ ] 펜 굵기 조절
- [ ] 압력 감도 설정

## 테스트 체크리스트
- [ ] Galaxy Tab S9 실기기 테스트
- [ ] S Pen 입력 100% 인식 확인
- [ ] Finger pass-through 확인 (웹 스크롤)
- [ ] 3초 fade-out 자연스러움
- [ ] 60fps 렌더링 확인
