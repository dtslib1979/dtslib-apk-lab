# Toy Kit — 저가 ESP32 장난감/로봇 슬롯 (planned)

> **상태: planned — 아직 미보유, 미빌드, 구체적 용도 미정**
> [`hardware/`](..) 개념의 일반형 슬롯. `parksy-printer`가 "출력" 특화형이라면
> 이건 "움직임/조종" 특화형 — 로봇카, 로봇팔, 미니 드론 등.

## 왜 필요한가

`docs/PARKSY_APK_PHILOSOPHY.md` 로드맵의 "직접 움직이는 장난감" 항목. 폰이 컴패니언 앱으로
저가 ESP32 하드웨어를 직접 조종하는 것 — 이 레포의 핵심 개념(폰↔ADB/브릿지)을 물리 세계로
확장한 형태.

## 커뮤니티 검증된 참고 패턴 (2026-07-09 리서치)

- **로봇카**: ESP32 + BTROBOT Android 앱으로 Bluetooth 조종
  ([Tarunsundar/ESP32-Bluetooth-Robot-Car](https://github.com/Tarunsundar/ESP32-Bluetooth-Robot-Car---Control-with-Your-Phone-))
- **WiFi 조종 로봇**: ESP32 + 웹서버 방식 원격 조종
  ([Random Nerd Tutorials — ESP32 Wi-Fi Car Robot](https://randomnerdtutorials.com/esp32-wi-fi-car-robot-arduino/))
- **로봇팔**: xArm-ESP32, MicroPython 기반 오픈소스 데스크탑 로봇팔
  ([Hiwonder xArm-ESP32](https://www.hiwonder.com/products/xarm-esp32))
- **미니 드론**: Seeed Studio ESP32-S3 기반 DIY 드론 키트, ESP-Drone Android 앱 조종
  ([ESP-FLY DIY Kit](https://www.cnx-software.com/2026/05/01/esp-fly-diy-kit-tiny-esp32-s3-based-diy-micro-drone-kit/))
- **저가 보드 소싱**: Keeyees ESP32S / ESP32-C6 / ESP32-S3 계열이 정품 대비 저렴하게 유통
  ([AliExpress ESP32 kit 검색](https://www.aliexpress.com/w/wholesale-esp32-kit.html))

## 다음 액션 (착수 시점 도래하면)

1. 구체적 용도 확정 — 방송 콘텐츠용(움직이는 장난감이 콘텐츠 소재) vs 실용(원격 심부름류) vs 순수 STEM 학습
2. 위 참고 프로젝트 중 하나를 베이스로 저가 키트 실물 구매 (AliExpress, 만원~5만원대)
3. 펌웨어는 Claude Code로 작성 (Arduino/MicroPython, ESP32 표준 툴체인)
4. 컴패니언 앱: 별도 Flutter APK보다 `apps/blackhole`(이미 있는 브릿지 앱)에
   BLE/WiFi 조종 모듈을 얹는 방향도 검토 — 새 앱보다 기존 브릿지 확장이 이 레포 철학에 더 맞음
5. 구매 후 `app-meta.json` 추가, registry status `planned` → `in-development`로 전환
