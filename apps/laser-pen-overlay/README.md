# Laser Pen Overlay

> **Personal use only. No distribution.**

S Pen 웹 오버레이 판서 앱 (레이저펜 효과).

## 기능

- ✅ 시스템 오버레이 (다른 앱 위 표시)
- ✅ S Pen 판서 (손가락은 하위 앱으로 통과)
- ✅ 3초 후 페이드아웃
- ✅ 색상 전환 (흰/노/검) - 스와이프
- ✅ Undo/Redo/Clear/Exit
- ✅ 입력 모드 토글 (S Pen 전용 ↔ 모든 입력)

## 대상 기기

- Galaxy Tab S9 (개인 기기)

## 설치

1. [GitHub Actions](https://github.com/dtslib1979/dtslib-apk-lab/actions) 접속
2. **Build Laser Pen Overlay** 워크플로우 클릭
3. 최신 성공 빌드 (✓ 녹색) 클릭
4. 하단 **Artifacts** → `laser-pen-overlay-debug` 다운로드
5. ZIP 해제 → `app-debug.apk`
6. Galaxy 기기로 전송
7. 설정 → 보안 → 출처를 알 수 없는 앱 허용
8. APK 설치

## 사용법

1. 앱 실행 → 오버레이 권한 허용 (1회)
2. 반투명 검정 화면 표시
3. **S Pen으로 판서** → 3초 후 자동 소멸
4. **손가락으로 스크롤/탭** → 하위 앱 조작

### 컨트롤 바

| 버튼 | 동작 |
|------|------|
| 🎨 | 색상 순환 (스와이프/탭) |
| ◀ | Undo |
| ▶ | Redo |
| 🧹 | 전체 삭제 |
| 🚪 | 종료 |

### 입력 모드

우측 상단 배지 탭:
- **S Pen**: S Pen 전용 (손가락 pass-through)
- **All**: 모든 입력 허용

## 테스트 시나리오

| TC | 시나리오 | 기대 결과 |
|----|----------|----------|
| 01 | S Pen으로 선 그리기 | 선 표시됨 |
| 02 | 3초 대기 | 선 사라짐 |
| 03 | 손가락으로 스크롤 | 하위 앱 스크롤됨 |
| 04 | 색상 버튼 스와이프 | 색상 변경됨 |
| 05 | Undo 탭 | 마지막 선 제거 |
| 06 | Clear 탭 | 모든 선 제거 |

## 기술 스택

- Flutter 3.24 + Kotlin Native
- MethodChannel (터치 분기)
- MotionEvent.getToolType() → STYLUS/FINGER 구분
- SYSTEM_ALERT_WINDOW

## 알려진 제한사항

- Galaxy Tab S9 전용
- Debug 빌드 (최적화 없음)
- 일부 앱에서 터치 전달 안 될 수 있음
- 실제 오버레이 모드는 추후 구현 필요

## 버전 기록

- **v1.0.0**: MVP (판서 + 페이드아웃 + 터치 분리)
- **v1.0.1**: 빌드 트리거 (2025-12-13)
