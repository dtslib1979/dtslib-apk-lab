# AIVA Prep - Audio Trimmer

**Personal use only** - Not for distribution.

AIVA companion prep tool: trim long audio files to 2-minute clips for export.

## Features

- Import audio (mp3, wav, m4a) via Android SAF
- Play/pause, scrub timeline
- Mark IN/OUT points
- Preset lengths: 30s / 60s / 120s (default) / 180s
- Auto fade-in/out (10ms) to avoid clicks
- Export as WAV (PCM 16-bit, 44.1kHz, stereo)
- Share exported clips via Android Share Sheet

## Install Debug APK from GitHub Actions

1. Go to [Actions](../../actions) tab
2. Click the latest successful workflow run
3. Scroll down to **Artifacts** section
4. Download `app-debug` artifact (ZIP file)
5. Extract `app-debug.apk`
6. Transfer APK to your Android device
7. Enable "Install from unknown sources" if prompted
8. Install and run

## Limitations

- Debug build only (not optimized)
- No MP3 export in v1 (WAV only)
- No audio-to-MIDI conversion (planned for v2)
- Tested on Galaxy Tab S9 only

## Tech Stack

- Flutter 3.24
- ffmpeg_kit_flutter_audio
- just_audio
- file_picker
- share_plus
