# Parksy Axis

방송용 사고 단계 오버레이 (박씨 좌표)

## v4.0.0 Pro Edition

| Feature | Description |
|---------|-------------|
| 🎨 6 Themes | Amber, Cyan, Lime, Pink, Purple, Mono |
| 📝 5 Fonts | Mono, Sans, Serif, Condensed, Rounded |
| 📐 Responsive | 크기에 비례하는 텍스트 스케일링 |
| 🌫️ Opacity | 배경 투명도 자유 조절 |
| ✨ Stroke | 테두리 굵기 커스텀 |
| 💾 Persist | 모든 설정 자동 저장 |

## 수학 모델
```
state: ℤ_n (mod n, n = stages.length)
tap(): s → (s+1) mod n
scale(): (w,h) → fontSize × ((w/260 + h/300) / 2)

Domain: {tap, scale} → {state, style}
Codomain: 반응형 FSM UI
```

## 다운로드

[![APK Download](https://img.shields.io/badge/APK-Download-green)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip)

## 사용법

1. 앱 실행 → 권한 허용
2. "커스터마이징"에서 테마/폰트/크기 설정
3. "오버레이 시작" 탭
4. 오버레이 탭 → 다음 스테이지
5. 스테이지 직접 탭 → 해당 스테이지로 이동

---

*Personal use only. Not for distribution.*
