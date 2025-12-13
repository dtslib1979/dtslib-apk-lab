# Laser Pen Overlay v2.0

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 🎯 핵심 기능

### v2.0 신규 - 시스템 오버레이 모드
- ✅ **실제 오버레이** - 다른 앱(웹브라우저, 유튜브 등) 위에 판서
- ✅ **S Pen 전용 입력** - S Pen만 캔버스에 그려짐
- ✅ **손가락 Pass-through** - 손가락은 하위 앱 조작
- ✅ **Foreground Service** - 백그라운드에서도 오버레이 유지

### 기존 기능
- ✅ 3초 후 페이드아웃 (레이저펜 효과)
- ✅ 색상 전환 (흰/노/검)
- ✅ Undo/Redo/Clear/Exit
- ✅ 입력 모드 토글 (S Pen 전용 ↔ 모든 입력)

## 📱 대상 기기

- Galaxy Tab S9 (개인 기기)

## 📥 설치

1. [GitHub Actions](https://github.com/dtslib1979/dtslib-apk-lab/actions) 접속
2. **Build Laser Pen Overlay** 워크플로우 클릭
3. 최신 성공 빌드 (✓ 녹색) 클릭
4. 하단 **Artifacts** → `laser-pen-overlay-debug` 다운로드
5. ZIP 해제 → `app-debug.apk`
6. Galaxy 기기로 전송 및 설치

## 🚀 사용법

### 첫 실행 - 권한 설정
1. 앱 실행
2. **SYSTEM_ALERT_WINDOW** 권한 허용 (다른 앱 위에 표시)
3. **알림 권한** 허용 (Android 13+)

### 기본 모드 (앱 내 판서)
1. 앱 실행 후 검정 배경 화면 표시
2. S Pen으로 판서 → 3초 후 자동 소멸
3. 손가락으로 스크롤 가능 (All 모드 시)

### ⭐ 오버레이 모드 (v2 신규)
1. 좌측 상단 **"오버레이 OFF"** 버튼 탭
2. **"오버레이 ON"** 으로 전환됨
3. 홈 버튼 눌러 다른 앱 실행 (웹브라우저, 유튜브 등)
4. **S Pen으로 화면 위에 판서** → 3초 후 자동 소멸
5. **손가락으로 하위 앱 스크롤/탭** → 정상 동작

### 컨트롤 바 (하단)

| 버튼 | 동작 |
|------|------|
| 🎨 | 색상 순환 (흰→노→검) |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 전체 삭제 |
| 🚪 | 종료 (오버레이 모드 시 서비스도 종료) |

## 🏗️ 아키텍처

```
┌─────────────────────────────────┐
│ Flutter UI (drawing_screen)    │
│ ├── 앱 내 판서 (기본 모드)      │
│ └── 오버레이 토글 버튼          │
└────────────┬────────────────────┘
             │ MethodChannel
┌────────────▼────────────────────┐
│ MainActivity.kt                 │
│ ├── /touch (터치 이벤트)        │
│ └── /overlay (서비스 제어)      │
└────────────┬────────────────────┘
             │ startService
┌────────────▼────────────────────┐
│ OverlayService.kt               │
│ └── OverlayCanvasView.kt        │
│     ├── STYLUS → 캔버스 렌더링  │
│     └── FINGER → pass-through   │
└─────────────────────────────────┘
```

## 🧪 테스트 시나리오

| TC | 시나리오 | 기대 결과 |
|----|----------|----------|
| 01 | 앱 내 S Pen 판서 | 선 표시됨 |
| 02 | 3초 대기 | 선 페이드아웃 후 소멸 |
| 03 | 오버레이 ON → 홈 이동 | 알림 표시됨 |
| 04 | 웹브라우저에서 S Pen 판서 | 오버레이 캔버스에 선 표시 |
| 05 | 웹브라우저에서 손가락 스크롤 | 웹페이지 스크롤됨 |
| 06 | 색상 버튼 탭 | 펜 색상 변경 |
| 07 | Exit 버튼 탭 | 앱 및 서비스 종료 |

## ⚙️ 기술 스택

- Flutter 3.24 + Kotlin Native
- Android Foreground Service
- WindowManager (TYPE_APPLICATION_OVERLAY)
- MotionEvent.getToolType() → STYLUS/FINGER 구분
- MethodChannel 브릿지

## ⚠️ 알려진 제한사항

- Galaxy Tab S9 전용 (타 기기 미테스트)
- Debug 빌드 (성능 최적화 미적용)
- 일부 보안 앱에서 오버레이 차단될 수 있음
- 게임 등 하드웨어 가속 앱에서 패스스루 불완전할 수 있음

## 📋 버전 기록

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| v2.0.0 | 2025-12-13 | 시스템 오버레이 기능 추가 (OverlayService) |
| v1.0.1 | 2025-12-13 | 빌드 트리거 |
| v1.0.0 | 2025-12-13 | MVP (판서 + 페이드아웃 + 터치 분리) |
