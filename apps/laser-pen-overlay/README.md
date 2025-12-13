# Laser Pen Overlay v2.4.0

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 📥 빠른 다운로드

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip)

## 🎯 핵심 기능

### v2.4 신규 - 드래그 가능 컨트롤 바 ⭐
- ✅ **자유 위치** - 컨트롤 바를 원하는 위치로 드래그
- ✅ **드래그 핸들** - ⋮⋮ 아이콘으로 이동
- ✅ **테두리 디자인** - 시각적 구분 향상

### v2.3 - 플로팅 컨트롤 바
- ✅ **화면 내 컨트롤** - 오버레이 모드에서 떠있는 버튼들
- ✅ **즉시 제어** - 색상/Undo/Redo/Clear/숨기기

### v2.2 - S Pen 압력 감지
- ✅ **압력 감지** - 누르는 힘에 따라 선 굵기 (6~16px)
- ✅ **5색 지원** - ⚪흰색, 🟡노랑, ⚫검정, 🔴빨강, 🔵파랑

### v2.1 - Quick Settings Tile
- ✅ **빠른 설정 타일** - 상태바에서 한 탭 ON/OFF
- ✅ **알림 액션 버튼** - ON/OFF, 색상, 클리어, 종료

### v2.0 - 시스템 오버레이
- ✅ **실제 오버레이** - 다른 앱 위에 판서
- ✅ **S Pen 전용** - S Pen만 그려짐
- ✅ **손가락 Pass-through** - 손가락은 하위 앱 조작
- ✅ **3초 Fade-out** - 레이저펜 효과

## 📱 대상 기기

- Galaxy Tab S9 (개인 기기)

## 🚀 사용법

### 플로팅 컨트롤 바 (v2.4)

| 버튼 | 동작 |
|------|------|
| ⋮⋮ | 드래그 핸들 (이동) |
| ⚪ | 색상 순환 |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 클리어 |
| 👁 | 오버레이 숨기기 |

**드래그**: 컨트롤 바 아무데나 터치 후 드래그하면 위치 이동

### Quick Settings 타일
상태바 → Quick Settings 편집 → **Laser Pen** 추가

### 알림 액션
알림 패널에서: ON/OFF, 색상, 클리어, 종료

## 🎨 색상

| 이모지 | 색상 |
|--------|------|
| ⚪ | 흰색 (기본) |
| 🟡 | 노랑 |
| ⚫ | 검정 |
| 🔴 | 빨강 |
| 🔵 | 파랑 |

## 🏗️ 아키텍처

```
┌─────────────────────────────────┐
│ Quick Settings Tile             │
│ Notification Actions            │
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ OverlayService                  │
│ ├── OverlayCanvasView (전체화면)│
│ │   ├── STYLUS + Pressure       │
│ │   └── FINGER → Pass-through   │
│ └── FloatingControlBar (드래그) │ ← v2.4
│     └── 색상/Undo/Redo/Clear/Hide│
└─────────────────────────────────┘
```

## 📋 버전 기록

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| **v2.4.0** | 2025-12-13 | 드래그 가능 컨트롤 바 |
| v2.3.0 | 2025-12-13 | 플로팅 컨트롤 바 |
| v2.2.0 | 2025-12-13 | S Pen 압력 감지, 5색 지원 |
| v2.1.0 | 2025-12-13 | Quick Settings Tile, 알림 액션 |
| v2.0.0 | 2025-12-13 | 시스템 오버레이 |
| v1.0.0 | 2025-12-13 | MVP |

## ⚠️ 제한사항

- Galaxy Tab S9 전용
- Debug 빌드

## ⚖️ 헌법 준수

[CONSTITUTION.md](../../CONSTITUTION.md)
