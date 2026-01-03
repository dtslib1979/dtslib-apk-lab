# Firebase Configuration for Parksy Audio Tools

## Setup Instructions

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: `parksy-audio-tools`
3. Enable Google Analytics for the project

### 2. Register Android App
1. Package name: `kr.parksy.audiotools`
2. Download `google-services.json`
3. Place in `android/app/` directory

### 3. Enable Crashlytics
1. Go to Firebase Console → Crashlytics
2. Click "Enable Crashlytics"
3. Build and run the app to verify connection

### 4. Enable Analytics
1. Go to Firebase Console → Analytics
2. Analytics is auto-enabled with Firebase Core

### 5. GitHub Secrets Required
Add these secrets to your repository:
- `GOOGLE_SERVICES_JSON`: Base64 encoded google-services.json

```bash
# Encode google-services.json
base64 -i android/app/google-services.json | pbcopy
```

## Event Tracking

| Event | Parameters | Trigger |
|-------|------------|---------|
| `recording_start` | `preset_seconds` | User starts recording |
| `recording_complete` | `duration_seconds` | Recording finishes |
| `midi_conversion_start` | `source` | Conversion begins |
| `midi_conversion_success` | `processing_ms` | Conversion succeeds |
| `midi_conversion_error` | `error_code` | Conversion fails |
| `file_share` | `file_type` | User shares file |

## Crashlytics Integration

Non-fatal errors are automatically logged via `AnalyticsService.recordError()`.
Fatal errors are caught by the global error handler in `main.dart`.
