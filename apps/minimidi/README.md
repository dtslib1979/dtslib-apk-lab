# MiniMidi

> **Personal use only. No distribution.**

오디오에서 멜로디 스켈레톤 MIDI를 추출하는 앱.

## 파이프라인

```
[오디오 파일] → [트리밍] → [Mono PCM] → [YIN Pitch] → [2A] → [2B] → [MIDI]
```

## 기능

### Stage 1: Audio Trimmer
- 오디오 파일 불러오기 (mp3, wav, m4a)
- IN/OUT 마킹 (현재 위치 기준)
- 프리셋 길이 (30s / 60s / 120s / 180s)
- 자동 페이드 인/아웃 (10ms)
- WAV 내보내기 (PCM 16-bit, 44.1kHz, stereo)

### Stage 2A: Melody Skeleton
- Mono PCM 변환 (44.1kHz, 16-bit)
- YIN pitch detection (frame 2048, hop 512, threshold 0.1)
- Post-processing:
  - Pitch clamp: MIDI 36-84 (C2-C6)
  - Median filter (5 frames)
  - Min duration 120ms
  - Merge ≤ 50 cents
- Single-track MIDI export (tempo 120, PPQ 480, vel 80)

### Stage 2B: DAW-Ready (Toggle ON/OFF)
- **Note Density Control**: 16th note 이하 분해 금지
- **Rhythm Snap**: 16th note grid로 스냅 (100%)
- **Note Length Normalization**: overlap 금지, 다음 노트 시작 - 10ms
- **Key-Safe** (Optional): Major/Minor 스케일로 자동 스냅

## UI 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| Stage 2B | ON | DAW-ready 후처리 적용 |
| Key-Safe | OFF | 스케일 스냅 (자동 키 감지) |

## 제약 조건

- **오프라인 전용**: ML 없음, 클라우드 없음
- **단일 멜로디 트랙**: 폴리포니 미지원

## 설치

1. [Actions](../../../actions) 탭 → `Build MiniMidi` 워크플로우
2. 최신 성공 빌드 클릭
3. **Artifacts** → `minimidi-debug` 다운로드
4. ZIP 해제 → `app-debug.apk`
5. Android 디바이스에 설치

## Tech Stack

- Flutter 3.24
- ffmpeg_kit_flutter_audio
- just_audio
- file_picker
- share_plus
