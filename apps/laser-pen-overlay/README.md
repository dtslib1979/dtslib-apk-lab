# Laser Pen Overlay v2.3.0

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 📥 빠른 다운로드

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip)

## 🎯 핵심 기능

### v2.3 신규 - 플로팅 컨트롤 바 ⭐
- ✅ **화면 내 컨트롤** - 오버레이 모드에서 하단에 떠있는 버튼들
- ✅ **즉시 제어** - 색상/Undo/Redo/Clear/숨기기 원탭
- ✅ **알림 없이도 제어 가능**

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

### 기본 기능
- ✅ 3초 후 페이드아웃
- ✅ Undo/Redo/Clear

## 📱 대상 기기

- Galaxy Tab S9 (개인 기기)

## 🚀 사용법

### ⭐ 추천: 플로팅 컨트롤 바 (v2.3)
1. 앱 실행 → 오버레이 ON
2. 화면 하단에 컨트롤 바 자동 표시:

| 버튼 | 동작 |
|------|------|
| ⚪ | 색상 순환 |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 클리어 |
| 👁 | 오버레이 숨기기 |

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
│ └── FloatingControlBar (하단)   │ ← v2.3
│     └── 색상/Undo/Redo/Clear/Hide│
└─────────────────────────────────┘
```

## 📋 버전 기록

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| **v2.3.0** | 2025-12-13 | 플로팅 컨트롤 바 (화면 내 제어) |
| v2.2.0 | 2025-12-13 | S Pen 압력 감지, 5색 지원 |
| v2.1.0 | 2025-12-13 | Quick Settings Tile, 알림 액션 |
| v2.0.0 | 2025-12-13 | 시스템 오버레이 |
| v1.0.0 | 2025-12-13 | MVP |

## ⚠️ 제한사항

- Galaxy Tab S9 전용
- Debug 빌드

## ⚖️ 헌법 준수

[CONSTITUTION.md](../../CONSTITUTION.md)
