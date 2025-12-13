# AIVA Trimmer

> **Personal use only. No distribution.**

AIVA 음악을 2분으로 트리밍하는 앱.

## 기능

- 오디오 파일 불러오기 (mp3, wav, m4a)
- IN/OUT 마킹 (현재 위치 기준)
- 프리셋 길이 (30s / 60s / 120s / 180s)
- 자동 페이드 인/아웃 (10ms)
- WAV 내보내기 (PCM 16-bit, 44.1kHz, stereo)
- Android Share Sheet으로 공유

## 설치

1. [Actions](../../../actions) 탭 → `Build AIVA Trimmer` 워크플로우
2. 최신 성공 빌드 클릭
3. **Artifacts** → `aiva-trimmer-debug` 다운로드
4. ZIP 해제 → `app-debug.apk`
5. Galaxy 디바이스에 설치

## Tech Stack

- Flutter 3.24
- ffmpeg_kit_flutter_audio
- just_audio
- file_picker
- share_plus
