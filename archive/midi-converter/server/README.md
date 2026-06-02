# MIDI Converter Server

MP3 → MIDI 변환 API 서버 (Spotify Basic Pitch 사용)

## API Endpoints

### POST /convert (권장)
동기 변환 - MIDI 바이트 직접 반환
```bash
curl -X POST -F "file=@song.mp3" \
  https://midi-converter-prod-uc.a.run.app/convert \
  --output output.mid
```

### POST /v1/jobs (비동기)
작업 생성 → 폴링 → 다운로드
```bash
# 1. 작업 생성
curl -X POST -F "file=@song.mp3" \
  https://midi-converter-prod-uc.a.run.app/v1/jobs

# 2. 상태 확인
curl https://midi-converter-prod-uc.a.run.app/v1/jobs/{job_id}
```

### GET /health
```bash
curl https://midi-converter-prod-uc.a.run.app/health
```

## 수동 배포 (Cloud Shell)

```bash
# 1. 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID

# 2. 클론
git clone https://github.com/dtslib1979/dtslib-apk-lab.git
cd dtslib-apk-lab/apps/midi-converter/server

# 3. Cloud Run 배포
gcloud run deploy midi-converter-prod-uc \
  --source . \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300s \
  --concurrency 10 \
  --min-instances 0 \
  --max-instances 3 \
  --allow-unauthenticated

# 4. 확인
curl https://midi-converter-prod-uc-xxxxx.a.run.app/health
```

## GitHub Actions 자동 배포

### Secrets 설정 필요
1. `GCP_PROJECT_ID`: GCP 프로젝트 ID
2. `GCP_SA_KEY`: 서비스 계정 JSON 키

### 서비스 계정 생성
```bash
# 서비스 계정 생성
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# 권한 부여
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# 키 생성
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com

# key.json 내용을 GCP_SA_KEY 시크릿으로 설정
```

## 로컬 테스트

```bash
cd apps/midi-converter/server

# Docker 빌드
docker build -t midi-converter .

# 실행 (GCS 없이 /convert만 테스트)
docker run -p 8080:8080 midi-converter

# 테스트
curl -X POST -F "file=@test.mp3" http://localhost:8080/convert --output test.mid
```

## 제한 사항

- 최대 파일 크기: 20MB
- 최대 처리 시간: 5분
- 지원 포맷: MP3만
- 출력: Standard MIDI File (.mid)
