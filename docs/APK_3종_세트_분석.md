# APK 3종 세트 분석

> 기술백서 v1.0 | 2026-01-16 | Parksy Apps Suite

---

## 1. 개요

본 문서는 Parksy 브랜드로 개발된 3개의 Android 앱에 대한 기술 분석 보고서입니다.

| 앱 | 패키지명 | 버전 | 용도 |
|----|----------|------|------|
| Parksy Capture | `com.parksy.capture` | 2.0.0 | 텍스트 캡처/아카이브 |
| Parksy Axis | `kr.parksy.axis` | 5.2.0 | 방송용 오버레이 |
| Parksy Pen | `com.dtslib.laser_pen_overlay` | 24.2.0 | S Pen 레이저 포인터 |

---

## 2. APK 메타데이터

### 2.1 Parksy Capture

```
Package:        com.parksy.capture
Version:        2.0.0 (versionCode: 3)
Min SDK:        26 (Android 8.0 Oreo)
Target SDK:     34 (Android 14)
Compile SDK:    34
Architecture:   arm64-v8a, armeabi-v7a, x86, x86_64
Framework:      Flutter + Kotlin
```

**APK 경로:** `/storage/emulated/0/Download/parksy-capture-v2.1.0.apk`

### 2.2 Parksy Axis

```
Package:        kr.parksy.axis
Version:        5.2.0 (versionCode: 1)
Min SDK:        21 (Android 5.0 Lollipop)
Target SDK:     34 (Android 14)
Compile SDK:    34
Architecture:   arm64-v8a, armeabi-v7a, x86, x86_64
Framework:      Flutter + flutter_overlay_window
```

**APK 경로:** `/storage/emulated/0/Download/ParksyAxis-v5.2.0.apk`

### 2.3 Parksy Pen

```
Package:        com.dtslib.laser_pen_overlay
Version:        24.2.0 (versionCode: 30)
Min SDK:        24 (Android 7.0 Nougat)
Target SDK:     35 (Android 15)
Compile SDK:    35
Architecture:   arm64-v8a, armeabi-v7a, x86, x86_64
Framework:      Flutter + Native Kotlin Overlay
```

**APK 경로:** `/storage/emulated/0/Download/laser-pen-v24.2.apk`

---

## 3. 권한 분석

### 3.1 권한 매트릭스

| 권한 | Capture | Axis | Pen |
|------|:-------:|:----:|:---:|
| `INTERNET` | O | - | - |
| `SYSTEM_ALERT_WINDOW` | - | O | O |
| `FOREGROUND_SERVICE` | - | O | O |
| `FOREGROUND_SERVICE_SPECIAL_USE` | - | O | O |
| `POST_NOTIFICATIONS` | - | O | O |
| `WAKE_LOCK` | - | O | - |
| `AccessibilityService` | - | - | O |

### 3.2 특수 권한 상세

#### SYSTEM_ALERT_WINDOW (다른 앱 위에 표시)
- **Axis**: 방송 중 화면에 사고 단계 오버레이 표시
- **Pen**: S Pen으로 화면 위에 그리기

#### FOREGROUND_SERVICE_SPECIAL_USE
- Android 14+ 에서 오버레이 서비스 유지에 필요
- `specialUse` foregroundServiceType 사용

#### AccessibilityService (접근성 서비스)
- **Pen**: 손가락 터치를 아래 앱에 전달 (TouchInjectionService)
- S Pen은 캔버스에 그리고, 손가락 터치는 통과시킴

### 3.3 특수 권한 요약 (JSON)

```json
{
  "parksy_capture": {
    "overlay": false,
    "accessibility": false,
    "notification_listener": false,
    "usage_stats": false,
    "battery_optimization": false,
    "unknown_sources": true
  },
  "parksy_axis": {
    "overlay": true,
    "accessibility": false,
    "notification_listener": false,
    "usage_stats": false,
    "battery_optimization": true,
    "unknown_sources": true
  },
  "parksy_pen": {
    "overlay": true,
    "accessibility": true,
    "notification_listener": false,
    "usage_stats": false,
    "battery_optimization": true,
    "unknown_sources": true
  }
}
```

---

## 4. 기능 상세

### 4.1 Parksy Capture

**목적:** Android Share Intent로 텍스트를 캡처하여 마크다운으로 저장

**핵심 기능:**
- `ACTION_SEND` Intent 수신 (공유 메뉴)
- `ACTION_PROCESS_TEXT` Intent 수신 (텍스트 선택 메뉴)
- `~/Downloads/parksy-logs/` 에 `ParksyLog_YYYYMMDD_HHMMSS.md` 형식으로 저장
- 별표/태그 메타데이터 관리
- 전체 텍스트 검색

**아키텍처:**
```
┌─────────────────────────────────────────┐
│              Flutter UI                  │
├─────────────────────────────────────────┤
│         MethodChannel Bridge             │
├─────────────────────────────────────────┤
│   MainActivity.kt (Kotlin Native)        │
│   - handleIntent()                       │
│   - saveFile() → MediaStore              │
│   - getLogFiles() → Direct File Access   │
└─────────────────────────────────────────┘
```

**저장소 접근:**
- Android 11+: `MANAGE_EXTERNAL_STORAGE` 권한 (런타임 요청)
- Android 10 이하: `READ/WRITE_EXTERNAL_STORAGE`

### 4.2 Parksy Axis

**목적:** 방송용 사고 단계 오버레이 (FSM 기반 상태 전이)

**핵심 기능:**
- 트리 구조로 단계 시각화
- 탭하면 다음 단계로 전이: `s → (s+1) mod n`
- 핀치 줌으로 오버레이 크기 조절
- 테마/폰트 커스터마이징
- 설정 영속화 (SharedPreferences)

**아키텍처:**
```
┌─────────────────────────────────────────┐
│         main() → AxisApp                 │
├─────────────────────────────────────────┤
│       overlayMain() → _OverlayApp        │
│       (vm:entry-point)                   │
├─────────────────────────────────────────┤
│    flutter_overlay_window Plugin         │
│    - showOverlay()                       │
│    - resizeOverlay()                     │
├─────────────────────────────────────────┤
│      OverlayService (Android)            │
│      - FOREGROUND_SERVICE                │
└─────────────────────────────────────────┘
```

**FSM (Finite State Machine):**
```dart
// 상태 전이
void _next() {
  _idx = (_idx + 1) % stages.length;
}

// 직접 점프
void _jump(int i) => _idx = i;
```

### 4.3 Parksy Pen

**목적:** S Pen 전용 레이저 포인터 오버레이

**핵심 기능:**
- S Pen → 캔버스에 그리기
- 손가락 → AccessibilityService로 아래 앱에 터치 전달
- 화면 녹화 감지 → 컨트롤바 자동 숨김
- Quick Settings Tile 지원
- Undo/Redo/Clear/색상 변경

**아키텍처:**
```
┌─────────────────────────────────────────┐
│            Flutter UI                    │
│         (설정 화면만)                     │
├─────────────────────────────────────────┤
│       OverlayService (Kotlin)            │
│       - WindowManager.addView()          │
│       - OverlayCanvasView                │
│       - FloatingControlBar               │
├─────────────────────────────────────────┤
│     TouchInjectionService                │
│     (AccessibilityService)               │
│     - dispatchGesture()                  │
├─────────────────────────────────────────┤
│      LaserPenTileService                 │
│      (Quick Settings Tile)               │
└─────────────────────────────────────────┘
```

**입력 분리 로직:**
```kotlin
when (event.getToolType(0)) {
    TOOL_TYPE_STYLUS → 캔버스에 그리기
    TOOL_TYPE_FINGER → TouchInjectionService로 전달
}
```

**화면 녹화 감지:**
- DisplayManager로 가상 디스플레이 체크
- 삼성 스크린 레코더 서비스 감지
- 녹화 중 → 컨트롤바 자동 숨김

---

## 5. 설치 가이드

### 5.1 설치 난이도

| 앱 | 난이도 | 필요 설정 |
|----|--------|----------|
| Capture | 쉬움 | 저장소 권한만 허용 |
| Axis | 중간 | 오버레이 권한 허용 |
| Pen | 어려움 | 오버레이 + 접근성 서비스 |

### 5.2 Parksy Capture 설치

1. APK 설치
2. 앱 실행 시 "모든 파일 접근 권한" 허용
3. 완료

### 5.3 Parksy Axis 설치

1. APK 설치
2. 앱 실행
3. "다른 앱 위에 표시" 권한 허용
   - 설정 → 앱 → Parksy Axis → 다른 앱 위에 표시 → 허용
4. 완료

### 5.4 Parksy Pen 설치

1. APK 설치
2. 앱 실행
3. "다른 앱 위에 표시" 권한 허용
4. "접근성 서비스" 활성화
   - 설정 → 접근성 → 설치된 앱 → Parksy Pen 터치 전달 → 켜기
5. (선택) 배터리 최적화 제외
   - 설정 → 배터리 → Parksy Pen → 제한 없음
6. 완료

---

## 6. 인스톨러 앱 연동

### 6.1 JSON 스키마

```json
{
  "apps": [
    {
      "name": "앱 이름",
      "package": "패키지명",
      "version": "버전",
      "version_code": 1,
      "min_sdk": 26,
      "target_sdk": 34,
      "permissions": ["권한 목록"],
      "special_permissions": {
        "overlay": false,
        "accessibility": false,
        "notification_listener": false,
        "usage_stats": false,
        "battery_optimization": false,
        "unknown_sources": true
      },
      "apk_path": "파일 경로",
      "notes": "특이사항"
    }
  ]
}
```

### 6.2 권한 Intent

```kotlin
// 오버레이 권한
Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
    Uri.parse("package:$packageName"))

// 접근성 설정
Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)

// 배터리 최적화 제외
Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
    Uri.parse("package:$packageName"))

// 알 수 없는 출처 허용
Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
    Uri.parse("package:$packageName"))
```

---

## 7. 전체 JSON 데이터

```json
{
  "apps": [
    {
      "name": "Parksy Capture",
      "package": "com.parksy.capture",
      "version": "2.0.0",
      "version_code": 3,
      "min_sdk": 26,
      "target_sdk": 34,
      "permissions": [
        "android.permission.INTERNET"
      ],
      "special_permissions": {
        "overlay": false,
        "accessibility": false,
        "notification_listener": false,
        "usage_stats": false,
        "battery_optimization": false,
        "unknown_sources": true
      },
      "apk_path": "/storage/emulated/0/Download/parksy-capture-v2.1.0.apk",
      "notes": "Share Intent 텍스트 캡처 앱. 저장소 권한은 런타임에 요청 (MANAGE_EXTERNAL_STORAGE)"
    },
    {
      "name": "Parksy Axis",
      "package": "kr.parksy.axis",
      "version": "5.2.0",
      "version_code": 1,
      "min_sdk": 21,
      "target_sdk": 34,
      "permissions": [
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.WAKE_LOCK"
      ],
      "special_permissions": {
        "overlay": true,
        "accessibility": false,
        "notification_listener": false,
        "usage_stats": false,
        "battery_optimization": true,
        "unknown_sources": true
      },
      "apk_path": "/storage/emulated/0/Download/ParksyAxis-v5.2.0.apk",
      "notes": "방송용 FSM 오버레이. 다른 앱 위에 표시 권한 필요"
    },
    {
      "name": "Parksy Pen",
      "package": "com.dtslib.laser_pen_overlay",
      "version": "24.2.0",
      "version_code": 30,
      "min_sdk": 24,
      "target_sdk": 35,
      "permissions": [
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
        "android.permission.POST_NOTIFICATIONS"
      ],
      "special_permissions": {
        "overlay": true,
        "accessibility": true,
        "notification_listener": false,
        "usage_stats": false,
        "battery_optimization": true,
        "unknown_sources": true
      },
      "apk_path": "/storage/emulated/0/Download/laser-pen-v24.2.apk",
      "notes": "S Pen 레이저 오버레이. 손가락 터치 전달용 접근성 서비스 사용"
    }
  ]
}
```

---

## 8. 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-01-16 | 1.0 | 초기 작성 |

---

*Generated by Claude Code*
