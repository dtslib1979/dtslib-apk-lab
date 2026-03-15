---
### 2026-03-15 | Parksy Studio 첫 빌드 성공 + 음악 파이프라인 APK 정리

**작업**:
1. **Parksy Studio CI 빌드 수복** (run 23102742083 — 21번 실패 후 첫 성공)
   - 원인: `ffmpeg_kit_flutter_min_gpl 6.0.3` → Maven arthenica 비LTS 아티팩트 404
   - 해결: `ffmpeg_kit_flutter_min_gpl` 완전 제거
   - `apps/parksy-studio/pubspec.yaml`: `video_player: ^2.8.1`만 유지
   - `apps/parksy-studio/lib/screens/trimmer_screen.dart`: FFmpeg 로직 제거, "변환 기능 v2.0 예정" 플레이스홀더

2. **app-registry.json SSOT 구조 확립**
   - `download_active` 필드 추가 → 3개만 활성: capture-pipeline, laser-pen-overlay, parksy-axis
   - `scripts/build_store_index.py` 수정: `download_active` 체크 로직 추가
   - `publish-store-index.yml`이 매 커밋마다 apps.json 덮어씀 → registry가 SSOT

3. **앱 상태 정리**
   - `tts-factory`: discontinued (Edge TTS/Grok 품질로 대체, Google Cloud 과금)
   - `midi-converter`: discontinued (PC WSL2 Basic Pitch 파이프라인으로 흡수)
   - `parksy-audio-tools`: discontinued (Wavesy + Telegram 봇으로 대체)

4. **parksy-studio 스토어 등록** (8번째 슬롯, broadcast 카테고리)
   - release_tag: `parksy-studio-v1.0.0`
   - download_active: false (첫 빌드 성공 직후, 검증 필요)

**결정**:
- **음악 파이프라인 = PC WSL2 + parksy-audio**로 확정
  - APK에서 MP3→MIDI 변환 시도 불필요
  - Basic Pitch (Spotify) on PC WSL2 parksy-audio
  - Wavesy: 트리밍 전용으로 존속, Telegram send 버튼 추가 예정
  - 흐름: Wavesy(폰) → Telegram bot(@parksy_bridge_bot) → PC WSL2 Basic Pitch → MIDI

- **Parksy Melody 통합 APK 계획 → 보류**
  - Audio Tools + MIDI Converter + Wavesy 통합 검토했으나
  - Basic Pitch Termux 설치 불가 (scikit-learn aarch64 빌드 실패)
  - MT3 불안정 (flax/t5x/optax 버전 충돌, 51개 미해결 이슈)
  - 결론: APK 레벨 음악 파이프라인은 무의미, PC에서 처리

- **nightly.link → GitHub Release URL 전환**
  - nightly.link는 private repo 지원 안 함 (404)
  - GitHub Release URL (`/releases/download/TAG/app-debug.apk`) 사용

**결과**:
- 11개 앱 registry (store-registered: 8, discontinued: 3, development: 0)
- 다운로드 활성 3개: Capture v10.0.8, Pen v1.0.31, Axis v11.1.0
- parksy-studio 스토어 페이지 노출 (다운로드 비활성)
- CI 빌드 성공: Studio build #23102742083

**교훈**:
- `ffmpeg_kit_flutter_min_gpl` = GPL 라이선스 문제로 Maven Central 없음. 아테나 CDN만 있는데 6.0 이후 불안정. 쓰지 말 것.
- apps.json 직접 편집 금지 → app-registry.json만 수정
- nightly.link = public repo 전용

**재구축 힌트**:
```
Claude에게: "dtslib-apk-lab app-registry.json SSOT 구조 설명하고,
Parksy Studio trimmer_screen.dart에 FFmpeg 없이 미리보기만 되는 이유,
download_active 필드가 어떻게 apps.json 생성에 영향주는지 설명해줘"
```

**다음 세션 TODO**:
- [ ] Wavesy에 Telegram send 버튼 추가 (`@parksy_bridge_bot` 폰→PC)
- [ ] parksy-audio WSL2에 Basic Pitch hook 추가 (audio_bridge.py)
- [ ] Parksy Studio download_active → true 전환 (검증 후)
---
