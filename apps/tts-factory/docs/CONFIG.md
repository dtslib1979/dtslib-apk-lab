# TTS Factory 설정 가이드

---

## 앱 설정

### 서버 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| Server URL | `https://tts-server-498465562814.asia-northeast3.run.app` | Cloud Run 서버 주소 |
| App Secret | (관리자 문의) | API 인증 키 |
| Timeout | 300초 | 요청 타임아웃 |

### 저장 설정

| 항목 | 기본값 | 설명 |
|------|--------|------|
| 저장 경로 | `Downloads/TTS-Factory/` | MP3 저장 위치 |
| 파일명 형식 | `{batch_date}_{id}.mp3` | 출력 파일명 패턴 |
| 자동 삭제 | OFF | 다운로드 후 서버 파일 삭제 |

### 변환 설정

| 항목 | 기본값 | 범위 |
|------|--------|------|
| 기본 언어 | ko | ko, en, ja, zh |
| 기본 프리셋 | neutral | neutral, news, story |
| 자동 분할 | ON | 1100자 초과 시 |

---

## 서버 환경 변수

### 필수

```bash
APP_SECRET=<인증키>
GOOGLE_APPLICATION_CREDENTIALS_JSON=<GCP 서비스 계정 JSON>
```

### 선택

```bash
PORT=8080                    # 서버 포트
MAX_ITEMS=25                 # 최대 유닛 수
MAX_CHARS=1100               # 유닛당 최대 글자
```

---

## Cloud Run 설정

### 현재 배포 정보

| 항목 | 값 |
|------|-----|
| 서비스명 | tts-server |
| 리전 | asia-northeast3 (서울) |
| 메모리 | 512Mi |
| CPU | 1 |
| 최대 인스턴스 | 3 |
| 타임아웃 | 300초 |
| 인증 | 비인증 허용 (공개) |

### Secret Manager

| 시크릿명 | 용도 |
|----------|------|
| tts-gcp-creds | GCP TTS API 인증 |

---

## API 엔드포인트

### Base URL

```
https://tts-server-498465562814.asia-northeast3.run.app
```

### 엔드포인트 목록

| Method | Path | 설명 |
|--------|------|------|
| GET | /health | 헬스체크 |
| POST | /v1/jobs | 배치 작업 생성 |
| GET | /v1/jobs/{job_id} | 작업 상태 조회 |
| GET | /v1/jobs/{job_id}/download | ZIP 다운로드 |

---

## 인증 헤더

모든 API 요청에 필수:

```
x-app-secret: <APP_SECRET 값>
```

---

*Last updated: 2025-12-30*