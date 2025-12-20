# TTS Factory 배포 가이드

## 1. GCP 프로젝트 설정

### 1.1 API 활성화

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  texttospeech.googleapis.com
```

### 1.2 Artifact Registry 저장소 생성

```bash
gcloud artifacts repositories create tts-factory \
  --repository-format=docker \
  --location=asia-northeast3 \
  --description="TTS Factory Docker images"
```

### 1.3 서비스 계정 생성 (배포용)

```bash
# 계정 생성
gcloud iam service-accounts create tts-factory-deploy \
  --display-name="TTS Factory Deployer"

# 권한 부여
PROJECT_ID=$(gcloud config get-value project)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-factory-deploy@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-factory-deploy@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-factory-deploy@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# 키 생성
gcloud iam service-accounts keys create gcp-sa-deploy.json \
  --iam-account=tts-factory-deploy@$PROJECT_ID.iam.gserviceaccount.com
```

### 1.4 서비스 계정 생성 (TTS API용)

```bash
# 계정 생성
gcloud iam service-accounts create tts-factory-api \
  --display-name="TTS Factory API"

# 권한 부여
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-factory-api@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/texttospeech.client"

# 키 생성
gcloud iam service-accounts keys create gcp-sa-tts.json \
  --iam-account=tts-factory-api@$PROJECT_ID.iam.gserviceaccount.com
```

## 2. GitHub Secrets 등록

Repository → Settings → Secrets and variables → Actions

| Name | Value |
|------|-------|
| `GCP_PROJECT_ID` | `gcloud config get-value project` 결과 |
| `GCP_SA_KEY` | `gcp-sa-deploy.json` 파일 내용 전체 |
| `TTS_APP_SECRET` | 임의 생성 (예: `openssl rand -hex 32`) |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | `gcp-sa-tts.json` 파일 내용 전체 |

## 3. 첫 배포

### 3.1 수동 트리거

1. GitHub → Actions → "Deploy TTS Server to Cloud Run"
2. Run workflow → main 브랜치 선택
3. 배포 완료 대기 (~3분)

### 3.2 서비스 URL 확인

```bash
gcloud run services describe tts-factory \
  --region=asia-northeast3 \
  --format="value(status.url)"
```

### 3.3 TTS_SERVER_URL Secret 등록

위에서 확인한 URL을 `TTS_SERVER_URL` Secret으로 등록.

## 4. 클라이언트 APK 빌드

서버 URL 등록 후 Flutter APK 재빌드:

1. Actions → "Build TTS Factory" → Run workflow
2. Artifacts에서 APK 다운로드

## 5. 검증

### 5.1 서버 헬스체크

```bash
curl https://YOUR_CLOUD_RUN_URL/health
# {"status":"ok"}
```

### 5.2 APK 테스트

1. 텍스트 파일 준비 (라인당 1개 TTS 유닛)
2. APK에서 파일 로드
3. Start 버튼
4. ZIP 다운로드 확인

## 6. 비용 관리

- Cloud Run: 요청 시에만 과금 (콜드 스타트 포함)
- Text-to-Speech: Neural2 음성 월 100만 자 무료
- Artifact Registry: 저장 용량 기준 과금 (최소)

### 권장 설정

```bash
# 최대 인스턴스 제한 (이미 워크플로우에 설정됨)
--max-instances 3

# 유휴 인스턴스 최소화
--min-instances 0
```
