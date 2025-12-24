# MIDI Converter

> **Personal use only. No distribution.**

MP3를 MIDI로 변환하는 앱.

## 기능

- MP3 파일 선택 (최대 20MB, 4분)
- Cloud Run 서버로 업로드
- Basic Pitch로 MIDI 변환
- 결과 다운로드 + 공유

## 설치

### 빠른 다운로드 (로그인 불필요)

👉 [**midi-converter-debug.apk**](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-midi-converter/main/midi-converter-debug.zip)

### GitHub Actions에서 직접

1. [Actions](../../../actions) 탭 → `Build MIDI Converter` 워크플로우
2. 최신 성공 빌드 클릭
3. **Artifacts** → `midi-converter-debug` 다운로드
4. ZIP 해제 → `app-debug.apk`
5. Galaxy 디바이스에 설치

## Tech Stack

- Flutter 3.24
- Dio (HTTP)
- file_picker
- share_plus

## Server

- Cloud Run (Python FastAPI)
- Basic Pitch (Spotify)
- Google Cloud Storage
