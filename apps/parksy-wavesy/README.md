# Parksy Wavesy

> **Personal use only. No distribution.**

음원 편집 가위 — MP3/MIDI 트리밍 앱.

## 기능

- 오디오 파일 불러오기 (MP3, WAV, M4A, MIDI)
- MIDI 파일 재생 (FluidSynth + SoundFont)
- IN/OUT 마킹 (현재 위치 기준)
- 프리셋 길이 (30s / 60s / 120s / 180s)
- 자동 페이드 인/아웃 (10ms)
- WAV 내보내기 (PCM 16-bit, 44.1kHz, stereo)
- Android Share Sheet으로 공유

## 설치

### 빠른 다운로드 (로그인 불필요)

[**parksy-wavesy-debug.apk**](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-wavesy/main/parksy-wavesy-debug.zip)

### GitHub Releases

[Releases](https://github.com/dtslib1979/dtslib-apk-lab/releases/tag/parksy-wavesy-latest)

## SoundFont

MIDI 재생에 SoundFont 파일이 필요합니다.
CI 빌드 시 `TimGM6mb.sf2` (~6MB)를 자동 다운로드합니다.

## Tech Stack

- Flutter 3.24
- flutter_midi_pro (FluidSynth)
- ffmpeg_kit_flutter_audio
- just_audio
- file_picker
- share_plus

## History

- v1.0.0: Initial AIVA Trimmer
- v2.0.0: Parksy brand rebranding
- v3.0.0: Renamed to **Parksy Wavesy**, added MIDI playback
