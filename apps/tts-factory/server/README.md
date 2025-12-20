# TTS Factory Server

> Personal use only. No distribution.

Google Cloud Text-to-Speech 기반 배치 처리 서버.

## 환경 변수

| Key | Description |
|-----|-------------|
| `APP_SECRET` | API 인증 시크릿 |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | GCP 서비스 계정 JSON (문자열) |

## API Endpoints

```
POST /v1/jobs           # 배치 작업 생성
GET  /v1/jobs/{job_id}  # 상태 조회
GET  /v1/jobs/{job_id}/download  # ZIP 다운로드 (완료 후 자동 삭제)
GET  /health            # 헬스체크
```

## Local Dev

```bash
cd apps/tts-factory/server
pip install -r requirements.txt
uvicorn main:app --reload
```

## Cloud Run Deploy

GitHub Actions 자동 배포 (main push 시).

필수 Secrets:
- `GCP_PROJECT_ID`
- `GCP_SA_KEY` (서비스 계정 JSON)
- `TTS_APP_SECRET`
- `GOOGLE_APPLICATION_CREDENTIALS_JSON`

## Limits

- 최대 25개 유닛/요청
- 유닛당 최대 1100자
- ZIP 다운로드 완료 후 서버 파일 즉시 삭제
