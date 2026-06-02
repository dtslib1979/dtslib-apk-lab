# TTS Factory 기술 백서

---

## 1. 시스템 아키텍처

```
┌─────────────────┐     HTTPS      ┌─────────────────┐
│   Flutter App   │ ──────────────▶│   Cloud Run     │
│   (Android)     │◀────────────── │   (FastAPI)     │
└─────────────────┘                └────────┬────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │  Google Cloud   │
                                   │  Text-to-Speech │
                                   └─────────────────┘
```

---

## 2. 기술 스택

### 클라이언트

| 구성요소 | 기술 |
|----------|------|
| 프레임워크 | Flutter 3.24.5 |
| 언어 | Dart 3.5 |
| 상태관리 | StatefulWidget |
| HTTP | http 패키지 |
| 파일처리 | path_provider, archive |
| 플랫폼 | Android (API 26+), Web |

### 서버

| 구성요소 | 기술 |
|----------|------|
| 프레임워크 | FastAPI 0.104+ |
| 언어 | Python 3.11 |
| 비동기 | asyncio, BackgroundTasks |
| 검증 | Pydantic v2 |
| 컨테이너 | Docker |
| 배포 | Google Cloud Run |

### 인프라

| 구성요소 | 서비스 |
|----------|--------|
| 컨테이너 | Cloud Run |
| TTS API | Google Cloud Text-to-Speech |
| 시크릿 | Secret Manager |
| CI/CD | GitHub Actions |
| 정적 호스팅 | Vercel (Web 버전) |

---

## 3. API 설계

### 3.1 작업 생성 (POST /v1/jobs)

**Request:**
```json
{
  "batch_date": "2025-12-30",
  "preset": "neutral",
  "language": "ko",
  "items": [
    {"id": "001", "text": "변환할 텍스트", "max_chars": 1100}
  ]
}
```

**Response:**
```json
{
  "job_id": "job_20251230_152609_cb784975",
  "status": "queued"
}
```

### 3.2 상태 조회 (GET /v1/jobs/{job_id})

**Response:**
```json
{
  "status": "completed",
  "progress": 5,
  "total": 5,
  "error": ""
}
```

### 3.3 다운로드 (GET /v1/jobs/{job_id}/download)

- Content-Type: `application/zip`
- 스트리밍 응답
- 다운로드 완료 후 서버 파일 자동 삭제

---

## 4. 보안 설계

### 4.1 인증

- 헤더 기반 API Key 인증
- `x-app-secret` 헤더 필수
- Secret Manager로 키 관리

### 4.2 데이터 보호

- HTTPS 전용 통신
- 임시 파일 즉시 삭제
- 메모리 내 작업 상태 관리 (영구 저장 없음)

### 4.3 접근 제어

- Cloud Run: 비인증 허용 (API Key로 보호)
- Secret Manager: IAM 기반 접근 제어

---

## 5. 처리 흐름

### 5.1 TTS 변환 파이프라인

```
1. 클라이언트 → POST /v1/jobs
2. 서버: 작업 큐 등록 (status: queued)
3. BackgroundTask 시작 (status: processing)
4. 각 아이템별 Google TTS API 호출
5. MP3 파일 임시 저장
6. 전체 완료 시 ZIP 압축 (status: completed)
7. 클라이언트 → GET /download
8. 스트리밍 전송 후 파일 삭제
```

### 5.2 에러 처리

| 상태 코드 | 원인 |
|-----------|------|
| 401 | 인증 실패 |
| 400 | 요청 형식 오류, 제한 초과 |
| 404 | 작업 없음 |
| 500 | 서버 내부 오류 |

---

## 6. 성능 최적화

### 6.1 서버

- 비동기 처리로 동시 요청 처리
- 스트리밍 응답으로 메모리 효율화
- Cloud Run 자동 스케일링 (max 3 인스턴스)

### 6.2 클라이언트

- 청크 단위 다운로드
- 진행률 실시간 표시
- 오프라인 감지 및 재시도

---

## 7. 제한 사항

| 항목 | 제한 | 근거 |
|------|------|------|
| 유닛당 글자 | 1,100자 | Google TTS API 제한 |
| 요청당 유닛 | 25개 | 서버 부하 관리 |
| 타임아웃 | 300초 | Cloud Run 최대값 |
| 파일 보관 | 다운로드 즉시 삭제 | 보안/비용 |

---

## 8. 배포 정보

### 8.1 GitHub Actions

트리거:
- `apps/tts-factory/server/**` 변경 시
- 수동 실행 (workflow_dispatch)

### 8.2 배포 명령 (수동)

```bash
gcloud run deploy tts-server \
  --source . \
  --region asia-northeast3 \
  --project tts-factory \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 3
```

---

## 9. 모니터링

### Cloud Run 콘솔

- 요청 수, 지연 시간, 에러율
- 인스턴스 수, 메모리 사용량

### 로그

```bash
gcloud logs read --service=tts-server --region=asia-northeast3
```

---

## 10. 버전 히스토리

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0.0 | 2025-12-30 | 초기 릴리즈 |

---

*Last updated: 2025-12-30*