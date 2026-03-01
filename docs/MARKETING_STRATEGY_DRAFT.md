# PARKSY APK — Global Marketing Strategy (DRAFT)

> **작성일:** 2026-03-01
> **문서 성격:** 글로벌 마케팅 전략 초안
> **상태:** DRAFT — 검토 및 수정 필요
> **한 줄 요약:** "코드 한 줄 안 치고 앱 10개 만든 사람" → 글로벌 콘텐츠

---

## 0. 한 줄 포지션

**"The guy who built 10 Android apps without writing a single line of code."**

이게 전부. 이 한 문장이 클릭을 만든다.

---

## 1. 왜 글로벌인가

| 요소 | 한국 한정? | 글로벌? |
|------|-----------|--------|
| AI로 앱 만들기 | — | 2025-26 최대 화두 |
| "Vibe Coding" 트렌드 | — | 영어권에서 터진 용어 |
| 비개발자가 했다 | — | 증거가 있으면 언어 불문 바이럴 |
| F-Droid 오픈소스 | — | 국제 커뮤니티 (유럽 특히 강함) |
| Samsung Galaxy + S Pen | — | 글로벌 1위 안드로이드 |
| Claude Code / Termux | — | 영어권 개발자 도구 |
| 반 플레이스토어 | — | 인디/프라이버시 진영 공감 |

한국 로컬 요소가 **하나도 없음.** 전부 글로벌 소재.

---

## 2. 타겟 오디언스 (4-Tier)

### Tier 1: AI Early Adopters (가장 큼)
- Hacker News, Reddit r/ClaudeAI r/artificial r/androiddev
- Twitter/X AI 커뮤니티
- 이 사람들이 첫 바이럴을 만듦
- 훅: "I built 10 apps with zero coding using Claude"

### Tier 2: Non-Developer Makers
- 코딩 못하지만 도구 만들고 싶은 직장인/교사/크리에이터
- YouTube, Medium, Substack
- 훅: "If I can do it, you can too"

### Tier 3: Open Source / Privacy Community
- F-Droid, FOSS 커뮤니티, Mastodon, Lemmy
- 훅: "Personal F-Droid repo — my own app store, no Google"

### Tier 4: Educators
- EAE University 연결 — AI 활용 교육 사례
- 학회, 교육 유튜브, 블로그
- 훅: "28 GitHub repos = one curriculum"

---

## 3. 콘텐츠 무기 5개

니 레포에서 이미 존재하는 소재만으로 구성. 새로 만들 거 없음.

### 무기 1: "The 31 Builds" — 바이럴 영상

```
제목: I Failed 31 Times Building One App. Here's What Happened.
포맷: 5-10분 YouTube
소재: LASER-PEN-RETROSPECTIVE.md (이미 작성됨)
서사: v7 시작 → v20 FLAG_SECURE 전멸 → v24 ghost mode 각성 → v25 완성
```

**왜 먹히냐:** 실패 서사는 만국 공통. 31번 빌드 기록이 git log에 전부 남아있음. 조작 불가. 진짜 삽질 증거.

### 무기 2: "Zero Lines of Code" — 증거 영상

```
제목: 10 Android Apps. Zero Lines of Code. Just My Voice.
포맷: 15-20분 YouTube (데모 + 철학)
소재: VDD-Report.md + 10개 앱 실기기 시연
서사: 폰 켜기 → Termux → 음성 → Claude → 빌드 → 설치 → 실사용
```

**왜 먹히냐:** "Vibe Coding"이 트렌드인데, 대부분 개발자가 하고 있음. **진짜 비개발자**가 증거 들고 나오면 다른 차원. VDD-Report.md가 이미 방법론 논문 수준으로 작성돼 있음.

### 무기 3: "Source Pool Pipeline" — 기술 데모

```
제목: I Turn Open Source Apps Into My Own Tools Using AI
포맷: 10분 YouTube + 블로그
소재: SOURCE_POOL_SCM_WHITEPAPER.md + 실제 파이프라인 데모
서사: F-Droid 앱 선택 → clone → Claude 편집 → 빌드 → 내 폰에 설치
```

**왜 먹히냐:** "편집이 창작이다" 테제가 오픈소스 커뮤니티 논쟁을 유발함. 논쟁 = 트래픽.

### 무기 4: "My Own App Store" — 철학 선언

```
제목: I Left Google Play. Built My Own App Store Instead.
포맷: 8분 YouTube + Reddit/HN 포스트
소재: CONSTITUTION.md + phoneparis 컨셉 + Vercel 스토어 페이지
서사: 플레이스토어 탈출 → 개인 F-Droid → phoneparis 변수 OS
```

**왜 먹히냐:** 탈구글 서사는 프라이버시 진영에서 영웅 서사. CONSTITUTION.md의 "개인용 only, debug APK only" 원칙이 진정성 증거.

### 무기 5: "Repository is a Novel" — 메타 콘텐츠

```
제목: My Git Log is a Story. Every Commit is a Sentence.
포맷: Medium/Substack + YouTube
소재: 헌법 제1조 + narrative-extract.py + 실제 git log 시연
서사: 커밋 이력을 소설처럼 읽는 시연 → 서사 추출 도구 데모
```

**왜 먹히냐:** 개발자 문화에서 "git commit message" 논쟁은 끝없는 떡밥. "커밋이 문장이다"는 프레이밍이 신선함.

---

## 4. 배포 채널 전략

| 채널 | 언어 | 계정 | 콘텐츠 |
|------|------|------|--------|
| YouTube (EAE) | EN/KO 자막 | 계정 C | 무기 1,2 (교육 프레이밍) |
| YouTube (dtslib) | EN | 계정 B | 무기 3,4 (기술 프레이밍) |
| Hacker News | EN | — | 무기 2,4 (Show HN 포스트) |
| Reddit | EN | — | 무기 1,2,3 (r/ClaudeAI, r/androiddev, r/opensource) |
| Twitter/X | EN | — | 무기 2 클립 (30초~1분) |
| Medium/Substack | EN | — | 무기 3,5 (롱폼 글) |
| F-Droid 포럼 | EN | — | 무기 4 (커뮤니티 직접 진입) |
| parksy.kr | KO | — | 전체 허브 |

---

## 5. 바이럴 시나리오 (최선 경로)

```
Phase 0: 소재 정비 (현재)
  백서, VDD-Report, 회고록 — 이미 있음

Phase 1: Show HN 포스트
  "Show HN: I built 10 Android apps without coding, using only voice + Claude"
  → HN 프론트페이지 가능성 있음 (AI + non-coder + real apps = HN 취향)
  → Reddit r/ClaudeAI 크로스포스트
  → Twitter 클립 동시 투하

Phase 2: 반응 기반 YouTube
  HN/Reddit 반응에서 가장 많이 나온 질문 → 그걸 영상으로
  "How?" → 무기 2 (Zero Lines of Code)
  "Bullshit" → 무기 1 (31 Builds 증거)
  "Open source?" → 무기 3 (Source Pool)

Phase 3: 교육 시리즈 (EAE University)
  바이럴 트래픽 → "나도 해보고 싶다" → 교육 채널로 유도
  → 커리큘럼 28개 레포가 교재
```

---

## 6. 경쟁 분석

현재 "AI로 앱 만들기" 영어권 콘텐츠:

| 크리에이터 유형 | 약점 | Parksy 차별점 |
|----------------|------|--------------|
| 개발자가 AI로 빠르게 | "그래 넌 원래 개발자잖아" | **비개발자** |
| 한 번 만들고 끝 | 일회성 데모 | **10개 실사용 중** |
| ChatGPT/Copilot 사용 | 범용 도구 | **Termux + Claude Code** (하드코어) |
| 웹앱 만들기 | 브라우저에서 끝 | **네이티브 APK** 실기기 설치 |
| 출시가 목표 | 플레이스토어 종속 | **자체 앱스토어** 운영 중 |
| 성공 스토리만 | 실패 안 보여줌 | **31번 실패 git log** 공개 |

**포지션은 비어있음.** "Non-developer + voice-only + 10 native apps + own app store + all failures documented in git" — 이 조합을 가진 사람이 없음.

---

## 7. KPI

기존 유튜버 KPI(조회수, 구독자)가 아니라 공장 구조에 맞는 KPI:

| KPI | 측정 | 의미 |
|-----|------|------|
| HN upvotes | Show HN 반응 | 기술 커뮤니티 검증 |
| GitHub stars (dtslib-apk-lab) | 소스 관심도 | 소재 재사용 가능성 |
| F-Droid 포럼 반응 | 커뮤니티 진입 | phoneparis 정당성 |
| EAE 강의 등록 | 교육 전환율 | 본업 연결 |
| "How did you do this?" 댓글 수 | 궁금증 유발 | Phase 2 콘텐츠 수요 증거 |

---

## 8. 실행 우선순위

지금 바로 할 수 있는 것만:

1. **Show HN 글 초안** — 영어, 500단어, 링크 3개 (GitHub + Store + VDD-Report)
2. **Reddit r/ClaudeAI 포스트** — "I built 10 apps using Claude without writing code" + 스크린샷
3. **Twitter/X 쓰레드** — 10개 앱 각각 한 줄 + 스크린샷

영상 제작은 반응 확인 후. 글 먼저, 영상 나중. **마케팅 먼저, 제작 나중.**

---

## 9. 점수 평가

| 항목 | 점수 | 이유 |
|------|------|------|
| 소재 풍부도 | **9/10** | 28개 레포 + 10개 앱 + 문서 다 있음 |
| 차별화 | **9/10** | 글로벌 포지션 비어있음 확인 |
| 타겟 명확성 | **9/10** | 4-Tier 분리, 채널별 매칭 |
| 실행 준비도 | **7/10** | 글 기반 먼저, 영상 나중 전략 |
| 시장 크기 | **8/10** | 글로벌 영어권 |
| **종합** | **8.4/10** | |

---

## 부록: 관련 문서

| 문서 | 위치 | 역할 |
|------|------|------|
| VDD-Report.md | 프로젝트 루트 | 방법론 논문 (무기 2 소재) |
| SOURCE_POOL_SCM_WHITEPAPER.md | docs/ | 소스풀 백서 (무기 3 소재) |
| LASER-PEN-RETROSPECTIVE.md | docs/ | 31번 빌드 회고록 (무기 1 소재) |
| PARKSY_APK_PHILOSOPHY.md | docs/ | 개발 철학서 (무기 4 소재) |
| CONSTITUTION.md | 프로젝트 루트 | 헌법 (무기 4 증거) |
| CLAUDE.md | 프로젝트 루트 | 레포 운영 규정 |

---

*이 문서는 Parksy APK Lab의 글로벌 마케팅 전략 초안이다.*
*최종 갱신: 2026-03-01*
*상태: DRAFT*
