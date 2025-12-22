# Parksy Axis

방송용 사고 단계 오버레이

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

## 기술
- Flutter overlay (flutter_overlay_window)
- FSM: ℤ₅ (mod 5)
- Permission: SYSTEM_ALERT_WINDOW

## 빌드
```bash
cd apps/parksy-axis
flutter pub get
flutter build apk --release
```

## 파일 구조
```
lib/
├── main.dart          # entry + overlay entry
├── app.dart           # MaterialApp
├── screens/home.dart  # 권한 요청 + 오버레이 시작
├── core/state.dart    # FSM 로직
└── widgets/tree_view.dart  # 트리 UI
```
