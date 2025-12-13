# Laser Pen Overlay v2.5.0

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 📥 빠른 다운로드

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip)

## 🎯 핵심 기능

### v2.5 신규 - 스와이프 색상 전환 ⭐
- ✅ **좌우 스와이프** - 컨트롤 바에서 스와이프로 색상 변경
- ✅ **오른쪽 →** 다음 색상
- ✅ **왼쪽 ←** 이전 색상
- ✅ **Whitepaper 요구사항 완료!**

### v2.4 - 드래그 가능 컨트롤 바
- ✅ **자유 위치** - 컨트롤 바를 원하는 위치로 드래그
- ✅ **드래그 핸들** - ⋮⋮ 아이콘으로 이동

### v2.3 - 플로팅 컨트롤 바
- ✅ **화면 내 컨트롤** - 색상/Undo/Redo/Clear/숨기기

### v2.2 - S Pen 압력 감지
- ✅ **압력 감지** - 누르는 힘에 따라 선 굵기 (6~16px)
- ✅ **5색 지원** - ⚪흰색, 🟡노랑, ⚫검정, 🔴빨강, 🔵파랑

### v2.1 - Quick Settings Tile
- ✅ **빠른 설정 타일** - 상태바에서 한 탭 ON/OFF
- ✅ **알림 액션 버튼** - ON/OFF, 색상, 클리어, 종료

### v2.0 - 시스템 오버레이
- ✅ **실제 오버레이** - 다른 앱 위에 판서
- ✅ **S Pen 전용** / **손가락 Pass-through**
- ✅ **3초 Fade-out** - 레이저펜 효과

## 📱 대상 기기

- Galaxy Tab S9 (개인 기기)

## 🚀 사용법

### 플로팅 컨트롤 바

| 제스처 | 동작 |
|--------|------|
| **스와이프 →** | 다음 색상 |
| **스와이프 ←** | 이전 색상 |
| **드래그 ↕** | 위치 이동 |

| 버튼 | 동작 |
|------|------|
| ⋮⋮ | 드래그 핸들 |
| ⚪ | 색상 탭 (순환) |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 클리어 |
| 👁 | 숨기기 |

### Quick Settings 타일
상태바 → Quick Settings 편집 → **Laser Pen** 추가

### 알림 액션
알림 패널: ON/OFF, 색상, 클리어, 종료

## 🎨 색상 (스와이프 순서)

⚪ → 🟡 → ⚫ → 🔴 → 🔵 → ⚪ (순환)

## 🏗️ 아키텍처

```
┌─────────────────────────────────┐
│ Quick Settings Tile             │
│ Notification Actions            │
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ OverlayService                  │
│ ├── OverlayCanvasView           │
│ │   ├── STYLUS + Pressure       │
│ │   └── FINGER → Pass-through   │
│ └── FloatingControlBar          │
│     ├── Swipe: 색상 전환        │ ← v2.5
│     └── Drag: 위치 이동         │
└─────────────────────────────────┘
```

## 📋 버전 기록

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| **v2.5.0** | 2025-12-13 | 스와이프 색상 전환 (좌/우) |
| v2.4.0 | 2025-12-13 | 드래그 가능 컨트롤 바 |
| v2.3.0 | 2025-12-13 | 플로팅 컨트롤 바 |
| v2.2.0 | 2025-12-13 | S Pen 압력 감지, 5색 |
| v2.1.0 | 2025-12-13 | Quick Settings Tile |
| v2.0.0 | 2025-12-13 | 시스템 오버레이 |

## ⚖️ 헌법 준수

[CONSTITUTION.md](../../CONSTITUTION.md)
