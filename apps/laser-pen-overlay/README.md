# Laser Pen Overlay v2.1.0

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 📥 빠른 다운로드

**로그인 없이 바로 다운로드:**

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip)

```
https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip
```

> ZIP 다운로드 → 압축 해제 → `app-debug.apk` 설치

## 🎯 핵심 기능

### v2.1 - Quick Settings Tile
- ✅ **빠른 설정 타일** - 상태바에서 한 탭으로 ON/OFF
- ✅ **알림 액션 버튼** - Toggle/Clear/Stop

### v2.0 - 시스템 오버레이 모드
- ✅ **실제 오버레이** - 다른 앱(웹브라우저, 유튜브 등) 위에 판서
- ✅ **S Pen 전용 입력** - S Pen만 캔버스에 그려짐
- ✅ **손가락 Pass-through** - 손가락은 하위 앱 조작
- ✅ **Foreground Service** - 백그라운드에서도 오버레이 유지

### 기본 기능
- ✅ 3초 후 페이드아웃 (레이저펜 효과)
- ✅ 색상 전환 (흰/노/검)
- ✅ Undo/Redo/Clear/Exit
- ✅ 입력 모드 토글 (S Pen 전용 ↔ 모든 입력)

## 📱 대상 기기

- Galaxy Tab S9 (개인 기기)

## 🚀 사용법

### 첫 실행 - 권한 설정
1. 앱 실행
2. **SYSTEM_ALERT_WINDOW** 권한 허용 (다른 앱 위에 표시)
3. **알림 권한** 허용 (Android 13+)

### ⭐ Quick Settings 타일 (v2.1 신규)
1. 상태바 내려서 Quick Settings 열기
2. 편집 모드 → **Laser Pen** 타일 추가
3. 타일 탭하면 오버레이 즉시 ON/OFF

### 알림 액션 버튼
오버레이 실행 중 알림에서:
- **Toggle** - 오버레이 숨기기/보이기
- **Clear** - 모든 스트로크 삭제
- **Stop** - 서비스 종료

### 오버레이 모드
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
| 🚪 | 종료 (서비스도 종료) |

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
│ ├── Foreground Service          │
│ ├── 알림 액션 버튼              │
│ └── OverlayCanvasView.kt        │
│     ├── STYLUS → 캔버스 렌더링  │
│     └── FINGER → pass-through   │
└────────────┬────────────────────┘
┌────────────▼────────────────────┐
│ LaserPenTileService.kt          │
│ └── Quick Settings Tile         │
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
| 06 | Quick Settings 타일 탭 | 오버레이 ON/OFF 토글 |
| 07 | 알림 Toggle 버튼 | 오버레이 숨기기/보이기 |
| 08 | 알림 Clear 버튼 | 모든 선 삭제 |
| 09 | 알림 Stop 버튼 | 서비스 종료 |

## ⚙️ 기술 스택

- Flutter 3.24 + Kotlin Native
- Android Foreground Service
- WindowManager (TYPE_APPLICATION_OVERLAY)
- MotionEvent.getToolType() → STYLUS/FINGER 구분
- TileService (Quick Settings)
- MethodChannel 브릿지

## ⚠️ 알려진 제한사항

- Galaxy Tab S9 전용 (타 기기 미테스트)
- Debug 빌드 (성능 최적화 미적용)
- 일부 보안 앱에서 오버레이 차단될 수 있음
- 게임 등 하드웨어 가속 앱에서 패스스루 불완전할 수 있음

## 📋 버전 기록

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| v2.1.0 | 2025-12-13 | Quick Settings Tile + 알림 액션 버튼 |
| v2.0.0 | 2025-12-13 | 시스템 오버레이 기능 (OverlayService) |
| v1.0.0 | 2025-12-13 | MVP (판서 + 페이드아웃 + 터치 분리) |

## ⚖️ 헌법 준수

본 앱은 [CONSTITUTION.md](../../CONSTITUTION.md)를 준수합니다.
