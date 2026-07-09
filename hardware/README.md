# Hardware — 물성화된 플러그

> **`devices/`가 "몸에 걸치는 확장"이라면, `hardware/`는 "손으로 만들어 조종하는 확장"이다.**
> 저가 ESP32급 보드로 직접 만드는 물리적 장난감/기기. 폰이 컴패니언 앱(ADB/WiFi/BT)으로 조종하는
> 대상이지, 폰이 착용하는 대상이 아니다 — 그래서 `devices/`와 분리한다.

## 위계에서의 위치

```
PC (WSL2)           연산 두뇌
  │
  │  ADB
  ▼
Phone (devices/phone) ── 확장(착용) ──▶ Tablet / Wearable-Audio / Smart Glass   (devices/)
  │
  │  컴패니언 앱 (WiFi/BT) ──▶ ESP32 기반 물리 하드웨어                          (hardware/) ← 여기
  ▼
저가 IoT 보드 + 커스텀 펌웨어
```

## 왜 필요한가 (커뮤니티 리서치, 2026-07-09)

`docs/PARKSY_APK_PHILOSOPHY.md`의 "Phase: 하드웨어" 로드맵 — *"저가 중국 IoT 제품 + 커스텀 칩,
Claude Code로 펌웨어 개발, 직접 움직이는 장난감"* — 이 실제로 커뮤니티에서 표준 패턴으로
검증되어 있다:

- **저가 ESP32 보드가 이미 취미/DIY 생태계의 기본 단위.** AliExpress 기준 Keeyees ESP32S,
  ESP32-C6, ESP32-S3 계열이 정품보다 훨씬 저렴하게 유통되며 WiFi+BT 내장 — 학생/취미러가
  IoT·임베디드 프로젝트에 표준으로 쓰는 보드. ([AliExpress ESP32 kit](https://www.aliexpress.com/w/wholesale-esp32-kit.html))
- **ESP32 + Android 컴패니언 앱 = 이미 검증된 조합.** ESP32 로봇카/로봇팔을 Bluetooth/WiFi로
  안드로이드 앱에서 직접 조종하는 오픈소스 프로젝트가 다수 존재 — BTROBOT 앱으로 조종하는
  ESP32 블루투스 로봇카 ([Tarunsundar/ESP32-Bluetooth-Robot-Car](https://github.com/Tarunsundar/ESP32-Bluetooth-Robot-Car---Control-with-Your-Phone-)),
  Bluetooth로 WiFi 자격증명을 넘기는 ESP32↔Android 페어링 구조
  ([willbeez/ESP32-WiFi-Bluetooth-Android](https://github.com/willbeez/ESP32-WiFi-Bluetooth-Android)),
  MicroROS 기반 WiFi 조종 로봇 ([noshluk2/MicroROS-ESP32-WiFi-Controlled-Robot](https://github.com/noshluk2/MicroROS-ESP32-WiFi-Controlled-Robot)).
- **완제품 키트로도 이미 시장이 성숙.** Seeed Studio의 ESP32-S3 기반 미니 드론 키트($59.99,
  ESP-Drone Android 앱으로 조종)처럼 저가 완제품 키트도 STEM/취미 시장에 자리잡음
  ([ESP-FLY DIY Kit — CNX Software](https://www.cnx-software.com/2026/05/01/esp-fly-diy-kit-tiny-esp32-s3-based-diy-micro-drone-kit/)).

즉 "폰 컴패니언 앱이 저가 ESP32 하드웨어를 조종한다"는 이 레포의 확장 방향은 이미 커뮤니티가
반복 검증한 검증된 패턴이지, 새로 개척하는 영역이 아니다. `parksy-printer`가 그 첫 번째
구체 사례(출판 하드카피 출력)이고, `toy-kit`이 그 개념의 일반형(로봇/드론류) 슬롯이다.

## 슬롯

| 슬롯 | 상태 | 설명 |
|---|---|---|
| [`parksy-printer`](parksy-printer) | planned | ESP32 + 열지 프린터 — 출판사 실물 하드카피 출력 |
| [`toy-kit`](toy-kit) | planned | ESP32 로봇/드론류 저가 키트 — 용도 미정, 슬롯만 선점 |

## `devices/`와의 구분 기준

| | devices/ | hardware/ |
|---|---|---|
| 관계 | 폰이 착용/휴대 | 폰이 컴패니언 앱으로 조종 |
| 예시 | 태블릿, 이어폰, 스마트글래스 | ESP32 프린터, 로봇, 드론 |
| 소프트웨어 위치 | apps/ (구현되면) | apps/ 또는 hardware/{slot}/firmware (펌웨어는 Flutter/Kotlin이 아니므로 별도) |
