# Parksy Audio Tools v2.0

**Screen Audio Capture + MIDI Converter for AIVA**

## 🎯 목적
AIVA용 MIDI 소스 생성을 위한 안드로이드 앱
- 유튜브/스트리밍에서 화면 녹음
- MP3 파일에서 직접 변환
- 1~3분 구간 추출 → MIDI

## 기능

### 🎬 Track A: 화면 녹음 → MIDI
1. MediaProjection으로 내부 오디오 캡처
2. 1/2/3분 프리셋 선택
3. 녹음 → WAV → MP3 → MIDI 자동 파이프라인
4. share_plus로 결과 공유

### 📁 Track B: 파일 → MIDI  
1. MP3/WAV/M4A 파일 선택
2. 슬라이더로 시작점 설정
3. 프리셋 구간 트림
4. MP3 → MIDI 변환

### ✂️ Legacy: 오디오 트림
- 자유 구간 선택
- WAV 출력

## 기술 스택

| Component | Library | Version |
|-----------|---------|---------|
| Screen Recording | system_audio_recorder | 0.0.6 |
| Audio Processing | ffmpeg_kit_flutter_audio | 6.0.3 |
| Playback | just_audio | 0.9.36 |
| MIDI Conversion | Cloud Run API | - |
| File Picker | file_picker | 8.0.0 |
| Sharing | share_plus | 7.2.1 |
| Permissions | permission_handler | 11.1.0 |

## 권한

```xml
<!-- 화면 녹음 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- 오버레이 -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>

<!-- 네트워크 -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- 파일 -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
```

## 요구사항

- Android 10+ (API 29+)
- MediaProjection 지원 디바이스

## 빌드

```bash
cd apps/parksy-audio-tools
flutter pub get
flutter build apk --debug      # 개발용
flutter build apk --release    # 배포용
```

## 서버 연동

MIDI 변환 서버: `https://midi-converter-prod-uc.a.run.app`

```
POST /convert
Content-Type: multipart/form-data
Body: file=@audio.mp3

Response: audio/midi (MIDI bytes)
```

## 아키텍처

```
lib/
├── main.dart
├── core/
│   ├── config/app_config.dart    # 앱 설정
│   ├── result/result.dart        # Result 타입
│   └── utils/duration_utils.dart # 시간 유틸
├── services/
│   ├── audio_service.dart        # FFmpeg 처리
│   ├── midi_service.dart         # 서버 API
│   ├── file_manager.dart         # 파일 관리
│   └── permission_service.dart   # 권한
├── screens/
│   ├── home_screen.dart
│   ├── capture/                  # Track A
│   ├── converter/                # Track B
│   └── trimmer/                  # Legacy
└── widgets/
    ├── preset_selector.dart
    └── result_card.dart
```

## 데이터 플로우

```
┌─────────────┐     ┌─────────────┐
│  Screen     │     │  File       │
│  Capture    │     │  Import     │
└──────┬──────┘     └──────┬──────┘
       │ WAV              │ MP3/WAV
       └─────────┬─────────┘
                 │
       ┌─────────┴─────────┐
       │  FFmpeg Trim      │
       │  (preset 1/2/3m)  │
       └─────────┬─────────┘
                 │ WAV
       ┌─────────┴─────────┐
       │  FFmpeg MP3       │
       │  (libmp3lame)     │
       └─────────┬─────────┘
                 │ MP3
       ┌─────────┴─────────┐
       │  Cloud Run API    │
       │  (basic-pitch)    │
       └─────────┬─────────┘
                 │ MIDI
                 ▼
         AIVA Ready .mid
```

## AIVA 호환

- ✅ 최대 3분 제한 준수
- ✅ Standard MIDI File 출력
- ✅ 단선율/다선율 모두 지원
- ✅ share_plus로 AIVA 직접 전송
