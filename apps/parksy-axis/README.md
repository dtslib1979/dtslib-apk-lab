# Parksy Axis v10.0.0

방송용 사고 단계 오버레이 - FSM 기반 상태 전이 (Ultimate Edition)

## Features

- 🎯 FSM 상태 전이: tap → (s+1) mod n
- 🎨 6개 테마: Amber, Cyan, Lime, Rose, Violet, Mono
- 📝 5개 폰트: Mono, Sans, Serif, Condensed, Rounded
- 📐 반응형 스케일: scale = (w/260 + h/300) / 2
- 🔧 실시간 커스터마이징
- 📍 4방향 오버레이 위치
- 👆 핀치 줌: 태블릿에서 두 손가락으로 크기 조절

## Changelog

### v7.3
- 🔧 **하드코딩 경로 사용**: `path_provider` 제거, 오버레이 프로세스 platform channel 문제 해결
- 📁 설정 파일 경로: `/data/data/kr.parksy.axis/files/axis_overlay_config.json`

### v7.2
- 🐛 **설정 적용 버그 수정**: `_loadTemplates()` 호출이 `_preview`를 덮어쓰는 문제 해결
- 🔄 **오버레이 재시작 수정**: 종료 후 딜레이 추가로 재시작 안정성 향상

### v7.1
- ⏱️ **파일 쓰기 딜레이 증가**: 100ms → 300ms (안정성 향상)

### v7.0
- 🔄 **파일 기반 설정 동기화**: SharedPreferences → JSON 파일 직접 저장
- ✨ **핀치 줌 개선**: RawGestureDetector로 태블릿 호환성 향상
- 🐛 **설정 적용 버그 수정**: 체크 버튼 누르면 즉시 저장 및 적용
- 📦 `path_provider` 의존성 추가

### v6.0.0
- 템플릿 시스템 도입 (프리셋 4개, 사용자 템플릿)

### v5.3.1
- 설정 동기화 강화: 오버레이 시작 전 현재 설정 강제 저장

### v5.3.0
- `loadFresh()` 추가: 오버레이 시작 시 항상 최신 설정 로드

## Architecture

```
lib/
├── main.dart          # Entry + Overlay FSM (RawGestureDetector)
├── app.dart           # MaterialApp
├── models/
│   └── theme.dart     # AxisTheme + AxisFont
├── services/
│   └── settings_service.dart  # 파일 기반 설정 저장/로드
├── screens/
│   ├── home.dart      # Main UI
│   └── settings.dart  # Customization
└── widgets/
    └── tree_view.dart # Responsive tree
```

## Download

[nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip)

## License

Personal use only. No distribution.
