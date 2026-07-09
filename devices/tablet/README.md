# Tablet — 확장 슬롯 (planned)

> **상태: planned — 아직 구체적 용도/앱 미정, 슬롯만 선점**
> [`devices/phone`](../phone)의 확장. 큰 화면이 필요한 작업 전용.

## 왜 필요한가

폰(S25 Ultra)이 중심이지만, 화면이 작아서 안 되는 작업이 있다 — 방송 제작 시 여러 트랙 동시 확인,
문서/악보 보면서 작업, PC 원격 제어 화면을 크게 보는 것 등.

이미 `dtslib-localpc/tools/pc-launcher` (태블릿 탭 → ADB 터널 → PC 프로그램 실행)로
일부 활용 중이지만, apk-lab 소관의 전용 APK는 아직 없음.

## 하드웨어
Tab S9 5G (SM-X716N) — Snapdragon 8 Gen 2, 7GB RAM

## 다음 액션 (착수 시점 도래하면)
- 구체적 용도 확정 (방송 보조 화면? 원격 제어 확장? 별도 입력 장치?)
- `apps/{앱명}/` 슬롯 생성 + registry 등록 (`planned` → `in-development`)
