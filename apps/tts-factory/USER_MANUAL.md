# Parksy TTS 사용자 매뉴얼

## 이 앱은 뭐하는 앱인가?

**여러 문장을 한번에 음성(MP3)으로 변환하는 배치 TTS 클라이언트**

텍스트를 줄 단위로 입력하면, 각 줄을 개별 MP3 파일로 변환해서 ZIP으로 묶어 다운로드한다.

### 왜 필요한가?

- Google Cloud TTS를 직접 호출하려면 API 설정, 인증, 비용 관리가 복잡함
- 이 앱은 별도 TTS 서버를 통해 간편하게 배치 처리
- 유튜브 나레이션, 외국어 학습, 프레젠테이션 음성 등에 활용

---

## 사전 준비

### 필요한 것

1. **TTS 서버** - 이 앱은 클라이언트만 있음. 서버를 별도 운영해야 함
2. **Server URL** - TTS 서버 주소 (예: `https://my-tts-server.run.app`)
3. **App Secret** - 서버 인증 키

---

## 최초 설정

1. 앱 실행
2. 우측 상단 **⚙️ Settings** 터치 (주황색 경고 표시됨)
3. **Server URL** 입력
4. **App Secret** 입력
5. **Save** 터치

---

## 기본 사용법

### Step 1: 텍스트 입력

#### 방법 A - 클립보드에서 붙여넣기
1. 다른 앱에서 텍스트 복사 (여러 줄)
2. **[Paste]** 버튼 터치
3. 각 줄이 하나의 TTS 아이템으로 등록됨

#### 방법 B - 직접 입력
1. **[+]** 버튼 터치
2. 텍스트 입력 (줄바꿈으로 구분)
3. **Add** 터치

### Step 2: 옵션 선택

| 옵션 | 선택지 |
|------|--------|
| **Lang (언어)** | English, 日本語, 中文, Español, 한국어 |
| **Voice (음색)** | Neutral(기본), Calm(차분), Bright(밝음) |

### Step 3: 변환 시작

1. **[Start]** 버튼 터치
2. 진행률이 실시간 표시됨
3. 완료 시 자동으로 ZIP 다운로드

### Step 4: 결과 확인

다운로드 위치:
```
내 파일 > Download > TTS-Factory > tts_YYYYMMDD_HHMMSS.zip
```

ZIP 내용:
```
tts_20251229_143052.zip
├── 01.mp3  (첫 번째 문장)
├── 02.mp3  (두 번째 문장)
├── 03.mp3  (세 번째 문장)
└── ...
```

---

## 아이템 관리

| 동작 | 방법 |
|------|------|
| 문장 수정 | 해당 아이템의 **연필 아이콘** 터치 |
| 문장 삭제 | 해당 아이템의 **X 아이콘** 터치 |
| 전체 삭제 | **휴지통 버튼** 터치 |
| 추가 입력 | **[+] 버튼** 터치 |

---

## 제한사항

| 항목 | 제한 |
|------|------|
| 최대 아이템 수 | 25개 |
| 아이템당 최대 글자수 | 1,100자 |

※ 제한 초과 시 빨간색으로 경고 표시됨

---

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| "Server not configured" | 서버 설정 안됨 | Settings에서 URL/Secret 입력 |
| "Network error" | 연결 실패 | 인터넷 확인, 서버 상태 확인 |
| "Invalid app secret" | 인증 실패 | Secret 키 재확인 |
| "Max 25 items allowed" | 아이템 초과 | 25개 이하로 줄이기 |
| "Item N exceeds 1100 chars" | 글자수 초과 | 해당 문장 줄이기 |

---

## 서버 API 명세

이 앱이 호출하는 API:

```
POST /v1/jobs
Headers: x-app-secret: {secret}
Body: {
  "batch_date": "2025-12-29",
  "preset": "neutral",
  "language": "ko",
  "items": [
    {"id": "01", "text": "첫 번째 문장", "max_chars": 1100},
    {"id": "02", "text": "두 번째 문장", "max_chars": 1100}
  ]
}
Response: {"job_id": "abc123"}

GET /v1/jobs/{job_id}
Headers: x-app-secret: {secret}
Response: {"status": "processing", "progress": 3, "total": 10}

GET /v1/jobs/{job_id}/download
Headers: x-app-secret: {secret}
Response: ZIP 파일 (binary)
```

---

## 버전 정보

- **앱 이름**: Parksy TTS
- **버전**: v1.1.0
- **다운로드 폴더**: /Download/TTS-Factory/
