# DTS APK Lab - Claude Code Instructions

## Project Overview
개인용 Android 앱 모음 프로젝트. Vercel에 스토어 페이지가 배포되어 있음.
- Store URL: https://dtslib-apk-lab.vercel.app/

## Brand Guidelines
모든 앱은 **Parksy** 브랜드를 사용:
- Parksy Capture (capture-pipeline)
- Parksy Pen (laser-pen-overlay)
- Parksy AIVA (aiva-trimmer)
- Parksy TTS (tts-factory)

## Project Structure
```
apps/
├── capture-pipeline/    # 공유 텍스트 캡처 앱
├── laser-pen-overlay/   # S Pen 오버레이 앱
├── aiva-trimmer/        # 오디오 트리밍 앱
└── tts-factory/         # TTS 변환 앱

dashboard/
├── apps.json            # 스토어 표시용 앱 목록
└── index.html           # 스토어 페이지
```

## Version Management
버전은 항상 `pubspec.yaml`이 source of truth:
- `pubspec.yaml` → 실제 앱 버전 (예: 2.0.0+1)
- `app-meta.json` → 메타데이터 (예: v2.0.0)
- `dashboard/apps.json` → 스토어 표시 (예: v2.0.0)

## Key Files to Sync
앱 정보 변경 시 동기화 필요한 파일들:

| 파일 | 역할 |
|------|------|
| `apps/{app}/pubspec.yaml` | Flutter 앱 버전 (source of truth) |
| `apps/{app}/app-meta.json` | 앱 메타데이터 (이름, 버전, 설명) |
| `dashboard/apps.json` | 스토어 페이지 표시 정보 |
| `apps/{app}/android/.../AndroidManifest.xml` | Android 앱 라벨 (아이콘 이름) |
| `apps/{app}/android/.../strings.xml` | Android 문자열 리소스 |

## Available Commands
- `/sync-store` - pubspec.yaml 기준으로 스토어 메타데이터 동기화
