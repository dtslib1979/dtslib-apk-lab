# Parksy Axis v5.3.1

방송용 사고 단계 오버레이 - FSM 기반 상태 전이

## Features

- 🎯 FSM 상태 전이: tap → (s+1) mod n
- 🎨 6개 테마: Amber, Cyan, Lime, Rose, Violet, Mono
- 📝 5개 폰트: Mono, Sans, Serif, Condensed, Rounded
- 📐 반응형 스케일: scale = (w/260 + h/300) / 2
- 🔧 실시간 커스터마이징
- 📍 4방향 오버레이 위치

## Changelog

### v5.3.1
- 🔧 **설정 동기화 강화**: 오버레이 시작 전 현재 설정 강제 저장
- ⏱️ 100ms 딜레이로 저장 완료 보장 후 오버레이 실행

### v5.3.0
- 🐛 **버그 수정**: 편집한 설정이 오버레이에 반영 안 되던 문제 해결
- ✨ `loadFresh()` 추가: 오버레이 시작 시 항상 최신 설정 로드
- 🔄 `SharedPreferences.reload()` 호출로 네이티브 캐시 동기화

## Architecture

```
lib/
├── main.dart          # Entry + Overlay FSM
├── app.dart           # MaterialApp
├── models/
│   └── theme.dart     # AxisTheme + AxisFont
├── services/
│   └── settings_service.dart  # SharedPrefs wrapper
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
