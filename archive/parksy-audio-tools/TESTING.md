# Testing Guide - Parksy Audio Tools v2.0

## 📱 Prerequisites

- Android 10+ device (API 29+)
- Internet connection (for MIDI conversion)
- Test audio files (MP3/WAV/M4A)

## 🔧 APK Installation

1. Download `parksy-audio-tools-debug.apk` from GitHub Actions artifacts
2. Enable "Install from Unknown Sources" in Settings
3. Install APK

## ✅ Test Checklist

### Track B: File Import (Test First)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1 | Launch app | Home screen with 3 tabs | |
| 2 | Tap "파일 → MIDI" tab | Converter screen loads | |
| 3 | Tap "파일 선택" | File picker opens | |
| 4 | Select MP3 file | Duration shown, slider appears | |
| 5 | Adjust start position | Slider moves, time updates | |
| 6 | Select 1min preset | "1분" highlighted | |
| 7 | Tap "MIDI 변환" | Progress: 트림 → MP3 → MIDI | |
| 8 | Wait for completion | Result card with share buttons | |
| 9 | Tap "MP3 공유" | Share sheet opens | |
| 10 | Tap "MIDI 공유" | Share sheet opens | |

### Track A: Screen Capture (Requires MediaProjection)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1 | Tap "화면 녹음" tab | Capture screen loads | |
| 2 | Select 1min preset | "1분" highlighted | |
| 3 | Tap "녹음 시작" | Permission dialog appears | |
| 4 | Grant permission | Timer starts counting | |
| 5 | Play audio (YouTube, etc) | Recording in progress | |
| 6 | Wait for auto-stop | Processing begins | |
| 7 | Completion | Result card with share buttons | |

### Legacy: Audio Trimmer

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1 | Tap "트림" tab | Trimmer screen loads | |
| 2 | Select audio file | Waveform or duration shown | |
| 3 | Set start/end | Slider updates | |
| 4 | Tap "트림" | WAV file created | |
| 5 | Share result | Share sheet opens | |

## ⚠️ Known Limitations

### Current Build (MIDI Server Not Deployed)

- ❌ MIDI conversion will fail with "인터넷 연결을 확인해주세요" or timeout
- ✅ MP3 conversion works (local FFmpeg)
- ✅ File selection works
- ✅ Trimming works

### After Server Deployment

- ✅ Full MIDI conversion pipeline

## 🐛 Error Messages Reference

| Message | Cause | Action |
|---------|-------|--------|
| 인터넷 연결을 확인해주세요 | No network or server down | Check WiFi/data |
| 서버 연결 시간 초과 | Server not responding | Retry later |
| 응답 시간 초과 | Audio too long | Use shorter segment |
| 파일이 너무 큽니다 | >20MB file | Use shorter audio |
| 오디오 파일을 읽을 수 없습니다 | Unsupported format | Use MP3/WAV/M4A |

## 📊 Log Collection

If crash or error:
```bash
adb logcat -s Flutter | grep -i parksy
```

## 🎯 AIVA Integration Test

After MIDI export:
1. Open AIVA app
2. "Create" → "From MIDI"
3. Import shared MIDI file
4. Verify notes detected
