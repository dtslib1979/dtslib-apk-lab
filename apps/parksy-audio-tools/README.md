# Parksy Audio Tools v2

**Screen Audio Capture + MIDI Converter for AIVA**

## 기능

### 🎬 Track A: 화면 녹음 → MIDI
- 내부 오디오 캡처 (MediaProjection)
- 1/2/3분 프리셋
- 자동 타이머 종료
- MP3 → MIDI 자동 변환

### 📁 Track B: 파일 → MIDI  
- MP3/WAV/M4A 파일 선택
- 시작점 설정
- 프리셋 구간 트림
- MIDI 변환

### ✂️ Legacy: 오디오 트림
- 자유 구간 선택
- WAV 출력

## 기술 스택

| Component | Library |
|-----------|--------|
| Screen Recording | system_audio_recorder |
| Audio Processing | ffmpeg_kit_flutter_audio |
| MIDI Conversion | Cloud Run (Basic Pitch) |
| File Picker | file_picker |
| Sharing | share_plus |

## 권한

- `FOREGROUND_SERVICE_MEDIA_PROJECTION` - 화면 녹음
- `RECORD_AUDIO` - 마이크 (선택)
- `SYSTEM_ALERT_WINDOW` - 오버레이 (향후)
- `INTERNET` - MIDI 서버 통신

## AIVA 호환

- 최대 3분 제한 준수
- MIDI 출력 → AIVA 직접 업로드 가능

## 빌드

```bash
cd apps/parksy-audio-tools
flutter pub get
flutter build apk --release
```

## 아키텍처

```
┌─────────────┐     ┌─────────────┐
│  Screen     │     │  File       │
│  Capture    │     │  Import     │
└──────┬──────┘     └──────┬──────┘
       │                   │
       └─────────┬─────────┘
                 │
       ┌─────────┴─────────┐
       │  Preset Trim      │
       │  (1/2/3 min)      │
       └─────────┬─────────┘
                 │
       ┌─────────┴─────────┐
       │  MP3 Encode       │
       └─────────┬─────────┘
                 │
       ┌─────────┴─────────┐
       │  MIDI Convert     │
       │  (Basic Pitch)    │
       └─────────┬─────────┘
                 │
                 ▼
         AIVA Ready MIDI
```
