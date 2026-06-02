# TTS Factory

> Personal use only. No distribution.

Google Cloud Text-to-Speech 기반 배치 TTS 생성 도구.

## 구성

```
apps/tts-factory/
├── lib/              # Flutter 클라이언트
├── server/           # Cloud Run 서버
├── android/          # Android 빌드 설정
└── pubspec.yaml
```

## 기능

- 텍스트 파일 로드 → 라인별 TTS 유닛 변환
- 최대 25개 유닛 / 배치
- 유닛당 최대 1100자
- 음성 프리셋: neutral, calm, bright (ko-KR Neural2)
- ZIP 다운로드 (audio/*.mp3 + logs/report.csv)

## APK 다운로드

1. [GitHub Actions](https://github.com/dtslib1979/dtslib-apk-lab/actions/workflows/build-tts-factory.yml) 이동
2. 최신 성공 빌드 클릭
3. Artifacts → `tts-factory-debug` 다운로드
4. APK 설치

또는 [nightly.link](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-tts-factory/main/tts-factory-debug.zip) 직접 다운로드

## 서버 배포

### 필수 GCP 설정

1. Cloud Run API 활성화
2. Artifact Registry 저장소 생성
   ```bash
   gcloud artifacts repositories create tts-factory \
     --repository-format=docker \
     --location=asia-northeast3
   ```
3. 서비스 계정 생성 (roles: Cloud Run Admin, Artifact Registry Writer)
4. Text-to-Speech API 활성화

### GitHub Secrets

| Secret | 설명 |
|--------|------|
| `GCP_PROJECT_ID` | GCP 프로젝트 ID |
| `GCP_SA_KEY` | 배포용 서비스 계정 JSON |
| `TTS_APP_SECRET` | API 인증 시크릿 (임의 생성) |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | TTS API용 서비스 계정 JSON |
| `TTS_SERVER_URL` | Cloud Run 배포 후 URL |

### 배포 트리거

- `apps/tts-factory/server/**` 변경 시 자동 배포
- 수동: Actions → Deploy TTS Server → Run workflow

## 제한사항

- Galaxy 디바이스 전용 (테스트 환경)
- Debug APK only (서명 없음)
- 서버 파일 영구 보관 금지 (다운로드 완료 후 즉시 삭제)

## 문제해결

### APK 설치 실패
- 설정 → 보안 → 출처를 알 수 없는 앱 허용
- 기존 버전 삭제 후 재설치

### 서버 연결 실패
- GitHub Secrets에 `TTS_SERVER_URL` 설정 확인
- Cloud Run 서비스 상태 확인

### TTS 생성 실패
- 유닛당 1100자 초과 확인
- GCP Text-to-Speech API 할당량 확인
