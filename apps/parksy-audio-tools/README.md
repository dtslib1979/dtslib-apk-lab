# Parksy Audio Tools

> **Personal use only. No distribution.**

Audio Trimmer + MIDI Converter 통합 앱.

## 기능

### Trimmer 탭
- 오디오 파일 불러오기 (mp3, wav, m4a)
- IN/OUT 마킹
- 프리셋 길이 (30s / 60s / 120s / 180s)
- 자동 페이드 인/아웃
- WAV 내보내기 + 공유

### MIDI 탭
- MP3 → MIDI 변환 (Cloud Run 서버)
- 결과 다운로드 + 공유

## 설치

### 빠른 다운로드 (로그인 불필요)

👉 [**parksy-audio-tools-debug.apk**](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-audio-tools/main/parksy-audio-tools-debug.zip)

## Tech Stack

- Flutter 3.24
- ffmpeg_kit_flutter_audio
- just_audio
- dio
- file_picker
- share_plus
