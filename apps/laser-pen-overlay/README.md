# Laser Pen Overlay

> S Pen 전용 웹 오버레이 판서 앱 (Galaxy Tab S9)

**Personal use only. No distribution.**

## 핵심 기능

- **S Pen만 판서**: S Pen으로 화면 위에 그리기
- **손가락 패스스루**: 손가락 터치는 하위 앱(브라우저 등)으로 전달
- **3초 Fade-out**: 스트로크가 3초 후 자동으로 사라짐
- **압력 감지**: S Pen 압력에 따른 선 굵기 변화

## v1.1.0 변경사항 (2025-12-14)

### 수정된 버그

| 버그 | 원인 | 해결 |
|------|------|------|
| S Pen이 그려지지 않음 | `onTouchEvent`에서 stylus 이벤트가 소비되지 않음 | `dispatchTouchEvent` 오버라이드로 stylus/finger 분기 |
| 손가락 패스스루 안 됨 | 오버레이가 모든 터치 이벤트 소비 | finger 이벤트에서 `return false`로 하위 전달 |
| Exit 버튼 안 눌림 | `setOnClickListener` 이벤트 전달 문제 | `setOnTouchListener`로 직접 터치 처리 |

### 핵심 수정 코드

**OverlayCanvasView.kt** - Stylus/Finger 분기:
```kotlin
override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    // Finger → pass-through (하위 앱으로)
    if (!isStylus(event)) {
        return false
    }
    // Stylus → 이 View에서 처리
    return super.dispatchTouchEvent(event)
}

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
```

## APK 다운로드

1. [GitHub Actions](../../actions/workflows/build-laser-pen.yml) 접속
2. 최신 성공한 빌드 클릭
3. Artifacts에서 `laser-pen-overlay-debug` 다운로드
4. APK 파일을 Galaxy Tab S9에 설치

## 사용법

1. 앱 실행
2. 오버레이 권한 허용 (최초 1회)
3. "오버레이 ON" 버튼 탭
4. 브라우저 등 다른 앱으로 이동
5. S Pen으로 화면 위에 판서
6. 손가락으로는 웹페이지 스크롤/클릭

### 컨트롤 바

| 버튼 | 기능 |
|------|------|
| ⚪/🟡/⚫/🔴/🔵 | 색상 순환 |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 전체 지우기 |
| ✕ | 오버레이 닫기 |

## 테스트 체크리스트

- [ ] 브라우저에서 손가락 스크롤 동작
- [ ] 브라우저에서 손가락 링크 클릭 동작
- [ ] S Pen으로 선 그리기 동작
- [ ] 3초 후 선 페이드아웃
- [ ] 색상 버튼 동작
- [ ] Undo/Redo 동작
- [ ] Clear 동작
- [ ] Exit(✕) 버튼 동작

## 알려진 제한사항

- Galaxy Tab S9에서만 테스트됨
- 일부 앱에서 오버레이가 차단될 수 있음
- 게임/영상 앱에서는 오버레이 권한이 제한될 수 있음

## 기술 스택

- Flutter 3.24.0
- Kotlin (Native Android)
- MotionEvent.getToolType() API
- WindowManager TYPE_APPLICATION_OVERLAY

## 빌드

GitHub Actions가 자동으로 debug APK를 빌드합니다.

```
push to main → build-laser-pen.yml → app-debug.apk artifact
```

---

*Personal use only. Not for distribution.*
