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
- Parksy Axis (parksy-axis)
- Parksy DualSub (overlay-dual-sub)

## Termux Build Instructions

Termux에서는 Flutter 직접 빌드 불가. **GitHub Actions로 빌드** 진행.

### 빌드 트리거 방법
1. 코드 수정 후 커밋 & 푸시
2. PR 생성 → main 머지
3. GitHub Actions 자동 빌드 시작
4. nightly.link에서 APK 다운로드

### Termux 환경 설정
```bash
# 필수 패키지
pkg install git nodejs openssh

# Claude Code 설치
npm install -g @anthropic-ai/claude-code

# 저장소 클론
git clone https://github.com/dtslib1979/dtslib-apk-lab.git
cd dtslib-apk-lab

# Claude Code 실행
claude
```

### 워크플로우 수동 트리거 (gh CLI 있을 때)
```bash
# 특정 앱 빌드 트리거
gh workflow run build-parksy-axis.yml
gh workflow run build-capture-pipeline.yml
gh workflow run build-laser-pen.yml
```

### APK 다운로드 링크
| 앱 | 다운로드 |
|----|----------|
| Parksy Capture | [nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-capture-pipeline/main/capture-pipeline-debug.zip) |
| Parksy Pen | [nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip) |
| Parksy Axis | [nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip) |
| Parksy DualSub | [nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/overlay-dual-sub/main/overlay-dual-sub-debug.zip) |

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
