# Parksy Cloud AppStore 백서

> **APK Lab의 쌍둥이. 설치 없는 앱스토어.**
> 네이티브가 필요 없는 모든 것은 URL로 배포한다.

---

## 1. 기원: 왜 두 번째 스토어인가

### 문제 인식

Parksy APK Lab은 성공적이다. 8개 앱, 28K 줄, Vercel 스토어까지 돌아간다.
그런데 모든 아이디어가 APK일 필요는 없었다.

```
바둑 정석 연습기를 만들고 싶다
→ 카메라? ❌  마이크? ❌  파일시스템? ❌  센서? ❌
→ Flutter 2000줄? 과잉. HTML 한 장이면 끝.
→ APK 빌드 → 설치 → 권한 허용? 불필요한 마찰.
→ "이 링크 열어" 한 마디면 될 것을.
```

**판단 기준은 단순하다:**

| 질문 | Yes → APK | No → Cloud |
|------|-----------|------------|
| 네이티브 API 필요? (카메라, 마이크, 센서, 오버레이) | APK Lab | Cloud AppStore |
| 백그라운드 서비스 필요? | APK Lab | Cloud AppStore |
| 파일시스템 깊은 접근? | APK Lab | Cloud AppStore |
| 위 전부 아니면? | — | **무조건 Cloud** |

### 한 줄 요약

> **APK Lab = 디바이스 기능이 필요한 도구**
> **Cloud AppStore = 브라우저만 있으면 되는 모든 것**

---

## 2. 투 트랙 아키텍처

### 2.1 전체 그림

```
┌─────────────────────────────────────────────────────┐
│                 Parksy Franchise OS                  │
│                                                     │
│   ┌─────────────────┐     ┌─────────────────────┐   │
│   │   APK Lab       │     │   Cloud AppStore     │   │
│   │   (Native)      │     │   (Web)              │   │
│   │                 │     │                      │   │
│   │ Flutter + Kotlin│     │ HTML + JS + Canvas   │   │
│   │ .apk 배포       │     │ URL 배포             │   │
│   │ GitHub Releases │     │ Vercel / Pages       │   │
│   │                 │     │                      │   │
│   │ ✍️ Pen          │     │ ♟ Baduk Drill        │   │
│   │ 💾 Capture      │     │ ♞ Chess Openings     │   │
│   │ 🌊 Wavesy       │     │ 🍷 Wine Flashcard    │   │
│   │ 🎙️ TTS          │     │ 🎵 Classical Quiz    │   │
│   │ 📞 ChronoCall   │     │ 🎨 Art Period Drill  │   │
│   │ ✏️ Liner         │     │ ...                  │   │
│   │ 🎯 Axis         │     │                      │   │
│   │ 🖊️ Subtitle      │     │                      │   │
│   └─────────────────┘     └─────────────────────┘   │
│                                                     │
│   공통: Parksy 브랜드 / 다크테마 / 골드 액센트       │
│   공통: Vercel 스토어 프론트엔드                     │
│   공통: Git 서사 (레포지토리는 소설이다)              │
└─────────────────────────────────────────────────────┘
```

### 2.2 APK Lab (기존)

| 항목 | 값 |
|------|-----|
| 레포 | `dtslib-apk-lab` |
| 기술 | Flutter + Kotlin |
| 배포 | GitHub Releases → APK 다운로드 |
| 스토어 | `dtslib-apk-lab.vercel.app` |
| 앱 수 | 8개 (2026-03-02 기준) |
| 대상 | 네이티브 기능 필수 도구 |

### 2.3 Cloud AppStore (신규)

| 항목 | 값 |
|------|-----|
| 레포 | `cloud-appstore` (신규 생성) |
| 기술 | HTML + CSS + JavaScript (바닐라) |
| 배포 | Vercel (각 앱 = 서브디렉토리 or 별도 경로) |
| 스토어 | `cloud-appstore.vercel.app` (가칭) |
| 앱 수 | 0개 → 첫 번째: Baduk Drill |
| 대상 | 브라우저만 있으면 되는 도구/게임/교육 |

### 2.4 스토어 프론트엔드: 카피 전략

Cloud AppStore의 스토어 페이지는 **APK Lab 스토어를 그대로 카피**한다.

```
APK Lab 스토어 (현재)          Cloud AppStore 스토어 (신규)
─────────────────────         ─────────────────────
다크 배경 #0D0D0D             다크 배경 #0D0D0D        ← 동일
골드 액센트 #D4AF37           골드 액센트 #D4AF37      ← 동일
Cinzel 서체                   Cinzel 서체              ← 동일
3열 그리드                    3열 그리드               ← 동일
Production / Prototype        Production / Prototype   ← 동일
앱 카드 → APK 다운로드         앱 카드 → URL 바로 열기   ← 차이점
shimmer 애니메이션             shimmer 애니메이션        ← 동일
apps.json 데이터 소스          apps.json 데이터 소스     ← 동일
```

**차이점은 딱 하나:** 카드를 누르면 APK 다운로드가 아니라 **앱 URL로 바로 이동**한다.

같은 디자인 시스템, 같은 브랜드, 같은 구조. 사용자 입장에서 "Parksy 앱스토어가 두 개 있고, 하나는 설치형이고 하나는 웹"이라는 인식.

---

## 3. 첫 번째 콘텐츠 라인: 허세 교양 시리즈

### 3.1 컨셉

```
"교양 있는 척 하려면 최소한 이것만 외워라"
```

바둑, 체스, 와인, 클래식 — 이른바 "교양"이라 불리는 분야들.
진짜 마스터가 되려면 수십 년이 걸리지만, **최소한의 패턴을 외워서 손따라 하는 수준**은 게임 형식으로 반복하면 된다.

이것은:
- ❌ AI 대국 엔진이 아니다
- ❌ 전문가용 분석 도구가 아니다
- ✅ **플래시카드처럼 정해진 수순을 반복하는 드릴**이다

### 3.2 왜 게임 형식인가

교양 드릴은 **교육 자료이면서 게임**이다. 이 두 가지는 같은 루프를 공유한다:

```
문제 출제 → 사용자 입력 → 정답/오답 판정 → 다음 문제
     ↑                                         │
     └─────────── 반복 (스코어 누적) ────────────┘
```

이 루프를 구현하는 데 네이티브 기능은 **단 하나도 필요 없다.**

| 필요한 것 | 구현 | 네이티브 필요? |
|-----------|------|---------------|
| 바둑판/체스판 | `<canvas>` | ❌ |
| 돌/말 놓기 | 클릭/터치 이벤트 | ❌ |
| 정답 판정 | JavaScript 비교 | ❌ |
| 진행 저장 | `localStorage` | ❌ |
| 수순 데이터 | JSON 파일 | ❌ |
| 사운드 피드백 | Web Audio API | ❌ |
| 오프라인 | PWA Service Worker | ❌ |

**결론: APK가 아니라 HTML 한 장이다.**

### 3.3 라인업

| 앱 ID | 이름 | 콘텐츠 | 핵심 메카닉 |
|--------|------|--------|------------|
| `baduk-drill` | Parksy Baduk | 바둑 정석 | 19x19 캔버스, 수순 따라두기, 활로 계산 |
| `chess-openings` | Parksy Chess | 체스 오프닝 | 8x8 캔버스, 오프닝 수순 암기 |
| `wine-flashcard` | Parksy Sommelier | 와인 테이스팅 | 카드 뒤집기, 향/맛/산지 매칭 |
| `classical-quiz` | Parksy Maestro | 클래식 음악 | 오디오 재생 → 곡명/작곡가 맞추기 |
| `art-periods` | Parksy Gallery | 미술 사조 | 이미지 → 시대/화가 맞추기 |

### 3.4 공유 엔진 구조

모든 허세 교양 앱은 **같은 엔진 위에 콘텐츠만 교체**하는 구조다.

```
cloud-appstore/
├── _engine/                    ← 공유 드릴 엔진
│   ├── drill-core.js           #   문제 출제 → 입력 → 판정 루프
│   ├── score-tracker.js        #   localStorage 기반 진행도
│   ├── theme.css               #   Parksy 다크테마 + 골드
│   └── components.js           #   공통 UI (진행 바, 스코어, 타이머)
│
├── baduk-drill/                ← 바둑 정석
│   ├── index.html              #   진입점
│   ├── board.js                #   19x19 캔버스 렌더러
│   ├── rules.js                #   활로 계산, 따먹기 판정
│   └── data/
│       ├── joseki-basic.json   #   기본 정석 20선
│       ├── joseki-star.json    #   화점 정석
│       └── joseki-komoku.json  #   소목 정석
│
├── chess-openings/             ← 체스 오프닝
│   ├── index.html
│   ├── board.js                #   8x8 캔버스 렌더러
│   └── data/
│       ├── italian-game.json   #   이탈리안 게임
│       ├── sicilian.json       #   시실리안 디펜스
│       └── queens-gambit.json  #   퀸즈 갬빗
│
├── wine-flashcard/             ← 와인 암기
│   ├── index.html
│   └── data/
│       └── wines.json          #   품종, 산지, 테이스팅 노트
│
├── dashboard/                  ← 스토어 프론트엔드
│   ├── index.html              #   APK Lab 스토어 카피
│   └── apps.json               #   앱 목록 (URL 링크)
│
└── README.md
```

---

## 4. Baduk Drill 상세 설계 (첫 번째 앱)

### 4.1 왜 바둑이 첫 타자인가

```
규칙 단순함:     바둑 ★★★★★ > 체스 ★★★ > 와인 ★★ > 클래식 ★
시각적 명확함:   19x19 격자 + 흑백 돌 = 캔버스 렌더링 최적
데이터 표현:     좌표 (3,4) = 돌 위치. JSON으로 완벽하게 직렬화
교육 효과:       정석은 "이 자리에 두면 최선" → 드릴에 딱 맞음
문화 코드:       동양 교양의 상징 → "허세 교양" 시리즈 아이덴티티
```

### 4.2 화면 구성

```
┌─────────────────────────────┐
│  PARKSY BADUK               │
│  정석 드릴 · 화점 기본 3/20  │
├─────────────────────────────┤
│                             │
│     ┌───────────────┐       │
│     │               │       │
│     │   19x19 바둑판  │       │
│     │               │       │
│     │   ● ○ ●       │       │
│     │     ● ○       │       │
│     │       ●       │       │
│     │               │       │
│     └───────────────┘       │
│                             │
│  "흑의 차례입니다. 어디에     │
│   두시겠습니까?"             │
│                             │
│  ┌──────┐ ┌──────┐ ┌─────┐ │
│  │ 힌트  │ │ 정답  │ │다음 │ │
│  └──────┘ └──────┘ └─────┘ │
│                             │
│  ━━━━━━━━━━━━━━━ 60%       │
│  진행: 12/20  정답률: 75%    │
└─────────────────────────────┘
```

### 4.3 인터랙션 플로우

```
1. 앱 로드 → 정석 세트 선택 (화점/소목/고목)
2. 첫 번째 문제 로드 → 바둑판에 기존 돌 배치
3. "여기에 두세요" 프롬프트
4. 사용자 터치/클릭 → 좌표 판정
   ├── 정답 → 돌 놓기 애니메이션 + "딱" 사운드 + 다음 수순
   └── 오답 → 흔들림 애니메이션 + "여기가 아닙니다" + 재시도
5. 한 정석 완주 → 스코어 기록 → 다음 정석
6. 세트 완주 → 요약 (정답률, 소요 시간, 약한 정석)
```

### 4.4 정석 데이터 포맷

```json
{
  "id": "star-basic-001",
  "name": "화점 기본 정석 1",
  "category": "star",
  "difficulty": 1,
  "description": "화점에 걸침 → 한 칸 뛰기 대응",
  "board_size": 19,
  "initial_stones": [],
  "sequence": [
    {
      "move": 1,
      "color": "black",
      "position": [3, 3],
      "comment": "흑, 화점에 착수"
    },
    {
      "move": 2,
      "color": "white",
      "position": [4, 2],
      "comment": "백, 소목 걸침",
      "is_drill": false
    },
    {
      "move": 3,
      "color": "black",
      "position": [5, 4],
      "comment": "흑, 한 칸 뛰어 받음 — 가장 기본적인 대응",
      "is_drill": true,
      "hint": "걸침에 대한 가장 안정적인 대응은?"
    }
  ]
}
```

`is_drill: true`인 수만 사용자에게 맞추게 하고, 나머지는 자동으로 재생한다.

### 4.5 활로 계산 (바둑 규칙 엔진)

드릴에서 따먹기가 발생하는 정석을 다루려면 최소한의 바둑 규칙이 필요하다:

```javascript
// 활로 = 돌에 인접한 빈 교차점 수
// 활로가 0이면 돌이 잡힌다 (따먹기)

function getLiberties(board, x, y) {
  // flood fill로 같은 색 연결 그룹 탐색
  // 그룹의 인접 빈 칸 수 = 활로
}

function captureCheck(board, x, y) {
  // 돌을 놓은 후 상대 돌의 활로 체크
  // 활로 0인 그룹 제거
  // 자충수 체크 (자기 돌의 활로도 0이면 착수 불가)
}
```

---

## 5. 기술 스택 비교

### APK Lab vs Cloud AppStore

| 차원 | APK Lab | Cloud AppStore |
|------|---------|----------------|
| **언어** | Dart + Kotlin | JavaScript (바닐라) |
| **프레임워크** | Flutter | 없음 (raw HTML/CSS/JS) |
| **렌더링** | Flutter 엔진 | Canvas API + DOM |
| **빌드** | `flutter build apk` | 빌드 없음 (정적 파일) |
| **배포** | GitHub Releases → APK | Vercel → URL |
| **설치** | APK 다운로드 + 설치 + 권한 | URL 열기 (끝) |
| **업데이트** | APK 재다운로드 + 재설치 | 새로고침 |
| **오프라인** | 네이티브 (항상) | PWA Service Worker (선택) |
| **저장** | SharedPreferences / SQLite | localStorage |
| **공유** | "이 APK 깔아봐" | "이 링크 열어봐" |
| **파일 크기** | ~20-50MB (APK) | ~100KB (HTML+JS+JSON) |
| **개발 속도** | 느림 (빌드 사이클) | 빠름 (저장→새로고침) |

### 왜 바닐라 JS인가

```
React?  → 바둑판 하나에 node_modules 200MB? 과잉.
Vue?    → 같은 이유.
Svelte? → 빌드 스텝 추가. 정적 파일의 장점 상실.
바닐라? → index.html 열면 끝. 빌드 없음. 의존성 없음.
```

Parksy 철학: **"없어도 되는 건 없앤다."**

---

## 6. 배포 아키텍처

### 6.1 레포 구조

```
GitHub: dtslib1979/cloud-appstore
│
├── 각 앱 = 서브디렉토리
│   ├── baduk-drill/index.html     → /baduk-drill
│   ├── chess-openings/index.html  → /chess-openings
│   └── wine-flashcard/index.html  → /wine-flashcard
│
├── dashboard/
│   ├── index.html                 → / (루트 = 스토어)
│   └── apps.json
│
└── vercel.json                    → 라우팅 설정
```

### 6.2 URL 체계

```
cloud-appstore.vercel.app/                  ← 스토어 (앱 목록)
cloud-appstore.vercel.app/baduk-drill/      ← 바둑 드릴 바로 실행
cloud-appstore.vercel.app/chess-openings/   ← 체스 오프닝
cloud-appstore.vercel.app/wine-flashcard/   ← 와인 플래시카드
```

각 앱은 **독립적으로 URL 공유 가능**하다. 스토어를 거치지 않아도 된다.

### 6.3 Vercel 설정

```json
{
  "rewrites": [
    { "source": "/", "destination": "/dashboard/index.html" }
  ]
}
```

각 앱 디렉토리의 `index.html`은 Vercel이 자동으로 서빙한다.

---

## 7. 두 스토어의 관계

### 7.1 크로스 링크

```
APK Lab 스토어 (dtslib-apk-lab.vercel.app)
├── footer: "Web Apps → cloud-appstore.vercel.app"
│
Cloud AppStore (cloud-appstore.vercel.app)
├── footer: "Native Apps → dtslib-apk-lab.vercel.app"
```

두 스토어는 서로를 참조한다. 하나의 Parksy 생태계, 두 개의 배포 채널.

### 7.2 apps.json 대조

**APK Lab의 apps.json:**
```json
{
  "id": "parksy-wavesy",
  "name": "Parksy Wavesy",
  "version": "v4.0.0",
  "status": "prototype",
  "downloadUrl": "https://github.com/.../app-debug.apk",  ← APK 다운로드
  "icon": "🌊"
}
```

**Cloud AppStore의 apps.json:**
```json
{
  "id": "baduk-drill",
  "name": "Parksy Baduk",
  "version": "v1.0.0",
  "status": "prototype",
  "appUrl": "/baduk-drill/",  ← URL 바로 이동
  "icon": "⚫",
  "category": "허세교양"
}
```

차이: `downloadUrl` (APK) vs `appUrl` (웹). 스토어 HTML은 이 필드만 분기하면 된다.

### 7.3 디자인 토큰 공유

```css
/* 두 스토어 모두 동일 */
--bg: #0D0D0D;
--bg-card: #1A1A1A;
--accent: #D4AF37;
--text: #F5F5DC;
--font-display: 'Cinzel', serif;
--font-body: 'Inter', sans-serif;
```

---

## 8. 콘텐츠 확장 로드맵

### Phase 1: 기반 구축

```
[ ] cloud-appstore 레포 생성
[ ] APK Lab 스토어 HTML/CSS 카피 → Cloud 버전 적응
[ ] 공유 드릴 엔진 (_engine/) 구현
[ ] Baduk Drill v1.0 — 화점 기본 정석 5선
[ ] Vercel 배포
```

### Phase 2: 허세 교양 시리즈 확장

```
[ ] Baduk Drill v1.1 — 소목, 고목 정석 추가 (20선 → 60선)
[ ] Chess Openings v1.0 — 이탈리안, 시실리안, 퀸즈갬빗
[ ] Wine Flashcard v1.0 — 주요 품종 30종 매칭
[ ] 스토어에 "허세교양" 카테고리 뱃지 추가
```

### Phase 3: 장르 확장

```
[ ] Classical Quiz — 유명 클래식 30곡 (Web Audio API)
[ ] Art Periods — 인상파/표현주의/팝아트 구분 드릴
[ ] Poetry Cards — 시조/하이쿠 빈칸 채우기
[ ] 스토어에 카테고리 필터 추가
```

### Phase 4: 엔진 고도화

```
[ ] 스페이스드 리피티션 (에빙하우스 망각 곡선 기반 복습)
[ ] 글로벌 리더보드 (선택적, Vercel KV or Supabase)
[ ] PWA 오프라인 모드 (Service Worker)
[ ] 크로스 앱 통합 점수 (교양 지수?)
```

---

## 9. 전략적 의미

### 9.1 Parksy 생태계 완성

```
Before:  Parksy = 안드로이드 도구 앱 모음
After:   Parksy = 네이티브 도구 + 웹 교육 게임 = 생태계
```

### 9.2 콘텐츠 파이프라인 확장

CONTENT_MARKETING_PLAN에서 정의한 "5대 무기"에 새로운 탄약이 추가된다:

```
기존 5대 무기:
  1. "31번 빌드한 앱"    → APK Lab 서사
  2. "코드 0줄"          → VDD 방법론
  3. "소스풀 파이프라인"  → 합법적 참조
  4. "나만의 앱스토어"    → 반상업 선언
  5. "레포는 소설이다"    → git 서사

새 무기:
  6. "허세 교양 시리즈"   → "앱 개발자가 만든 교양 게임"
     → 바둑 유튜브 커뮤니티
     → 체스 커뮤니티 (체스닷컴 대안)
     → 와인 입문자 커뮤니티
     → "설치 없이 링크 하나로" → 바이럴 유리
```

### 9.3 기술적 다각화

```
APK Lab:    Flutter/Dart + Kotlin + Android SDK
Cloud:      Vanilla JS + Canvas API + Web APIs

개발자로서 포트폴리오가 "Flutter 앱만 만드는 사람"에서
"네이티브도 웹도 만드는 사람"으로 확장된다.
```

### 9.4 배포 마찰 제거

```
APK:   "이 앱 써봐" → 링크 클릭 → APK 다운로드 → 설치 허용
       → 권한 허용 → 앱 실행 (마찰: 4단계)

Web:   "이거 해봐" → 링크 클릭 → 바로 실행 (마찰: 0단계)
```

허세 교양 시리즈는 **공유가 핵심**이다. "야 이거 한번 해봐" 한 마디에 URL 하나.
설치 장벽이 없으니 전파가 빠르다.

---

## 10. 원칙

### APK Lab 헌법 계승

Cloud AppStore도 동일한 헌법을 따른다:

1. **레포지토리는 소설이다** — 커밋이 문장, 브랜치가 챕터
2. **삭제는 없다, 반대 분개만 있다** — git revert로 정정
3. **증빙 없는 거래는 없다** — 커밋에 이유와 맥락
4. **BOM 확인 후 착공** — 의존성 명세 먼저 (비록 바닐라 JS라 의존성이 0이지만)
5. **재공품 방치 금지** — WIP 브랜치 정기 소화

### Cloud 전용 원칙 추가

6. **빌드 스텝 금지** — HTML 파일 열면 바로 실행. npm, webpack, bundler 없음.
7. **100KB 법칙** — 앱 하나의 총 용량(HTML+JS+CSS+데이터)이 100KB를 넘지 않는다. 이미지/오디오는 예외.
8. **URL이 곧 배포** — 링크 공유 = 앱 배포. 스토어를 거칠 필요 없음.
9. **같은 얼굴, 다른 몸** — 스토어 디자인은 APK Lab과 동일. 브랜드 일관성.

---

## 부록 A: 판단 플로우차트

```
새 아이디어가 떠오름
         │
         ▼
  네이티브 기능 필요?
  (카메라/마이크/센서/오버레이/파일시스템)
         │
    ┌────┴────┐
    Yes       No
    │         │
    ▼         ▼
 APK Lab   Cloud AppStore
    │         │
    ▼         ▼
 Flutter   HTML+JS
    │         │
    ▼         ▼
 .apk 배포  URL 배포
```

## 부록 B: Cloud AppStore apps.json 스키마

```json
{
  "id": "string (kebab-case, 디렉토리명과 동일)",
  "name": "string (Parksy 접두사)",
  "version": "string (vX.Y.Z)",
  "status": "production | prototype",
  "description": "string (한 줄 설명)",
  "icon": "string (이모지)",
  "appUrl": "string (상대 경로, /app-id/)",
  "category": "string (허세교양 | 도구 | 유틸)",
  "lastUpdated": "string (YYYY-MM-DD)"
}
```

## 부록 C: 기존 Parksy 앱 분류표

| 앱 | 네이티브 기능 | 현재 트랙 | 올바른 트랙 |
|----|-------------|----------|------------|
| Pen | 오버레이, S Pen | APK | APK ✅ |
| Capture | 인텐트 수신, GitHub API | APK | APK ✅ |
| Wavesy | FFmpeg, 파일시스템 | APK | APK ✅ |
| TTS | 클라우드 API, 파일 내보내기 | APK | APK ✅ |
| ChronoCall | FFmpeg, Whisper, 녹음 접근 | APK | APK ✅ |
| Liner | 카메라, 이미지 처리 | APK | APK ✅ |
| Axis | 오버레이, IPC | APK | APK ✅ |
| Subtitle | 오버레이 | APK | APK ✅ |
| Baduk Drill | 없음 | — | **Cloud** ✅ |
| Chess Openings | 없음 | — | **Cloud** ✅ |
| Wine Flashcard | 없음 | — | **Cloud** ✅ |

> 기존 8개 APK는 전부 네이티브 기능이 필수인 앱이다. 판단 기준은 정확했다.

---

**문서 버전:** v1.0.0
**작성일:** 2026-03-02
**작성 맥락:** APK Lab 세션에서 Cloud AppStore 구상이 구체화됨
**다음 액션:** cloud-appstore 레포 생성 → Baduk Drill 프로토타입
