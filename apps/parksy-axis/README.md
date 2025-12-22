# Parksy Axis

방송용 사고 단계 오버레이 (박씨 좌표)

## 구조
```
[Idea]
├─ Capture  ◀ ●
├─ Note
├─ Build
├─ Test
└─ Publish
```

## 조작
- 탭: 다음 단계
- 순환: Publish → Capture

## 수학 모델
```
state: ℤ₅ (mod 5)
tap(): s → (s+1) mod 5

Domain: {tap} → {0,1,2,3,4}
Codomain: {Capture, Note, Build, Test, Publish}
```

## 기술
- Flutter overlay (flutter_overlay_window)
- FSM: ℤ₅ cyclic
- Permission: SYSTEM_ALERT_WINDOW

## 빌드
```bash
cd apps/parksy-axis
flutter pub get
flutter build apk --debug
```

## 다운로드

[![APK Download](https://img.shields.io/badge/APK-Download-green)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip)

## v1.0.0 완료
- [x] FSM 로직 (ℤ₅)
- [x] 터미널 스타일 트리 UI
- [x] 오버레이 시스템
- [x] GitHub Actions CI/CD
- [x] 스토어 등록
