# Parksy APK Lab — 글로벌 콘텐츠 마케팅 전략

> **작성일:** 2026-03-01
> **작성자:** dtslib (Parksy)
> **문서 성격:** 글로벌 시장을 타겟으로 한 콘텐츠 마케팅 전략서
> **한 줄 피치:** "코드 한 줄 안 치고 Android 앱 10개 만든 사람의 방법론"

---

## Executive Summary

이건 제품 마케팅 플랜이 아니다. 팔 제품이 없다.

이건 **인터넷 어디에도 없는 이야기**에 대한 콘텐츠 마케팅 플랜이다: 비개발자가 AI에게 말로만 시켜서 개인용 앱 공장을 만든 이야기 — 10개 Android 앱, 28개 연결된 레포지토리, 60번 이상 성공한 빌드 — 코드 한 줄 안 치고.

콘텐츠 기회는 **과정 자체**에 있다. 방법론(VDD: Vibe Driven Development), 인프라(Source Pool SCM), 철학("APK는 팹 장비지 완제품이 아니다") — 전부 글로벌하게 신선하고 문서화 가능한 소재다.

### 자체 평가 점수

| 차원 | 점수 | 이유 |
|------|------|------|
| 소재 풍부도 | 9/10 | 28개 레포가 원재료. 모든 커밋이 이야기. git log = 줄거리. |
| 차별화 | 8/10 | 이 조합은 아무도 없다: 비개발자 + AI-only + 절대 안 팜 + 앱 10개 |
| 시장 크기 | 4/10 | **무관.** 이건 제품 플레이가 아니다. 콘텐츠에 TAM이 필요 없다. |
| 실행 준비도 | 5/10 | 문서 있음. 앱 있음. 파이프라인 있음. 부족한 것: 외부 소비용 포장. |

**목표:** 실행 준비도를 5에서 8로 올린다. 기존 재료를 출판 가능한 콘텐츠로 포장한다.

---

## 1. 포지셔닝

### 원라이너

> **"코드 한 줄 안 짰습니다. AI에게 말로 시켜서 Android 앱 10개 만들었습니다."**

### 왜 이게 글로벌에서 먹히는가

"AI가 개발자를 대체한다" 서사는 이미 넘쳐난다. 근데 항상 **개발자가** 말한다. Parksy 이야기는 다르다:

| 기존 서사 | Parksy 서사 |
|----------|------------|
| "AI가 코딩 속도를 높여줘요" | **"AI만 코딩합니다. 저는 안 해요"** |
| "AI로 SaaS 하나 만들었어요" | **"AI로 개인 도구 10개 만들었고 — 절대 안 팝니다"** |
| "AI 코딩 튜토리얼이에요" | **"60번 넘게 빌드한 과정의 다큐멘터리에요"** |
| "프로토타입 봐주세요" | **"프로토타입을 찍어내는 공장을 봐주세요"** |
| 개발자가 AI를 자랑 | **비개발자가 방법론을 자랑** |

차별화는 "AI 썼다"가 아니다. 그건 누구나 말한다. 차별화는:

1. **코딩 능력 제로** — "파이썬 알지만 AI 썼다"가 아님. 진짜 제로.
2. **앱 10개, 1개 아님** — 데모가 아니라 포트폴리오.
3. **설계적 반상업** — "아직 수익화 안 했다"가 아님. **헌법으로 금지함.**
4. **공장, 작업실이 아님** — 자동화 파이프라인, 라이선스 감사, 스토어 동기화, 크로스레포 오케스트레이션.
5. **전부 기록됨** — 28개 레포 풀 커밋 히스토리. "레포지토리는 소설이다."

### 안티-포지셔닝

Parksy가 **아닌 것**:
- 노코드(no-code) 플랫폼 이야기 아님 (이건 AI-code, 노코드 아님)
- 사이드 프로젝트 이야기 아님 (이건 산업 파이프라인)
- "코딩 배우기" 이야기 아님 (핵심이 코딩 안 배우는 것)
- 스타트업 이야기 아님 (비즈니스 모델 없음, 헌법으로 금지)
- 튜토리얼 채널 아님 (이건 다큐멘터리)

---

## 2. 콘텐츠 3축 구조

### 축 1: VDD — Vibe Driven Development (교육축)

**핵심 테제:** 비개발자가 AI로 실제 소프트웨어를 만드는 반복 가능한 방법론이 있다. 마법도 운도 아니다 — 실패 유형과 회복 패턴이 식별 가능한 학습 가능한 프로세스다.

**타겟 오디언스:** AI 개발에 호기심 있는 비개발자. 크리에이터. 콘텐츠 프로듀서. 커스텀 도구가 필요한 소상공인.

**콘텐츠 포맷:** 블로그 시리즈, 유튜브 다큐 에피소드, 트위터/X 스레드.

**핵심 증거물:**
- Parksy Pen: 31번 빌드해서 완성. 매 실패 기록됨.
- ChronoCall: 풀 STT 파이프라인 (FFmpeg 전처리 → Whisper API → 세그먼트 뷰어) — 코드 안 치고 설계, 구현, 테스트.
- Wavesy: MP3 + MIDI 편집 단일 앱. 메이저 버전 4번.
- 전 앱 합산 60번 이상 성공 빌드.

**서사 아크 (글로벌 영어 콘텐츠):**
```
Episode 1: "What is VDD?" — 방법론 설명
Episode 2: "Build #1 to Build #31" — Parksy Pen 케이스 스터디
Episode 3: "When AI Gets It Wrong" — 실패 분류학과 회복
Episode 4: "The Factory Floor" — 앱 1개에서 10개로 가는 법
Episode 5: "Your Turn" — 자기만의 VDD 프로젝트 시작 프레임워크
```

### 축 2: Source Pool SCM (기술축)

**핵심 테제:** 오픈소스 코드를 소싱하고, 감사하고, 개인 도구로 변환하는 전문가 수준의 방법론이 있다 — 완전한 법적 방어, 자동화된 라이선스 감사, 문서화된 출처 관리 포함.

**타겟 오디언스:** 오픈소스 방법론에 관심 있는 개발자. DevOps 엔지니어. 테크 법무/컴플라이언스 전문가.

**콘텐츠 포맷:** 기술 백서 (이미 존재), 컨퍼런스 톡, dev.to/Medium 아티클.

**핵심 증거물:**
- 3-Tier 소스풀 아키텍처 (F-Droid 1차 → 삼성 SDK 2차 → 구조 참조 3차)
- 자동화 라이선스 감사: 9개 앱, 68개 의존성, GPL 위반 0건
- Independent Implementation 방법론: 클린룸과 법적으로 구분되는 정직한 정의
- `.extraction-audit.json`으로 모든 디컴파일 참조에 감사 추적

**서사 아크 (글로벌 영어 콘텐츠):**
```
Article 1: "How I Legally Source Code for 10 Apps" — 3-Tier 시스템
Article 2: "Automated License Compliance for Solo Developers" — 도구 체인
Article 3: "Independent Implementation vs Clean Room" — 정직한 법적 포지셔닝
Article 4: "F-Droid as a Developer's Reference Library" — 아직 아무도 안 다룬 금광
```

### 축 3: phoneparis — 콘텐츠 팩토리 (플랫폼축)

**핵심 테제:** 개인 도구 → 콘텐츠 생산 파이프라인 → 멀티플랫폼 콘텐츠 공장. APK는 제품이 아니다. **콘텐츠 팹 라인의 장비**다.

**타겟 오디언스:** 자기 플랫폼을 만드는 크리에이터. 1인 미디어 운영자. 자기 스택을 소유하고 싶은 크리에이터 이코노미.

**콘텐츠 포맷:** 장편 비디오 에세이, 팟캐스트 에피소드, parksy.kr 에디토리얼.

**핵심 증거물:**
- 플라이휠: `앱 개발 과정 → YouTube (개발기) → 앱 활용 → YouTube (활용기) → parksy.kr → eae.kr (교육)`
- 앱 1개로 동시 5개 아웃풋 (도구, 개발 콘텐츠, 활용 콘텐츠, 스토어 트래픽, 커리큘럼)
- 크로스레포 오케스트레이션: 1대 PC에서 3개 프로덕션 레포, JSON 매니페스트가 연결 조직
- "레포지토리는 소설이다" — 커밋이 문장, 브랜치가 챕터

**서사 아크 (글로벌 영어 콘텐츠):**
```
Essay 1: "APKs Are Fab Equipment" — 절대 안 파는 도구를 왜 만드는가
Essay 2: "One App, Five Outputs" — 콘텐츠 곱하기 플라이휠
Essay 3: "28 Repos, One Story" — git 히스토리가 서사가 되는 법
Essay 4: "The Phone Is the Factory" — 온디바이스 전부, 클라우드 제로
```

---

## 3. 차별화 매트릭스

### vs. "AI 앱 빌더" 콘텐츠

| 차원 | 일반적인 AI 빌더 콘텐츠 | Parksy |
|------|----------------------|--------|
| 만드는 사람 | AI를 가속기로 쓰는 개발자 | **AI가 유일한 빌더인 비개발자** |
| 규모 | 앱 1개, 영상 1개 | **앱 10개, 레포 28개, 진행 중인 시리즈** |
| 수익화 | "출시해서 유저 받자" | **"절대 안 팔고, 만드는 과정을 콘텐츠로"** |
| 깊이 | 주말 프로젝트 | **수개월 반복, 60번+ 빌드** |
| 법적 인식 | 제로 (그냥 분위기) | **백서 있음, 자동화 컴플라이언스** |
| 문서화 | README가 전부 | **철학서 + 백서 + 헌법** |
| 인프라 | 없음 | **자동화 파이프라인, 스토어, 크로스레포 싱크** |
| 실패 이야기 | 편집해서 삭제 | **git에 보존. "레포지토리는 소설이다."** |

### vs. 노코드(No-Code) 콘텐츠

| 차원 | 노코드 무브먼트 | Parksy VDD |
|------|---------------|------------|
| 도구 | 비주얼 빌더 (Bubble, Webflow) | **AI 대화 (Claude Code)** |
| 산출물 | 웹앱, 랜딩 페이지 | **네이티브 Android APK** |
| 복잡도 천장 | 낮음~중간 | **높음 (FFmpeg 파이프라인, Platform Channel, S Pen SDK)** |
| 소유권 | 플랫폼 종속 | **소스 코드 100% 소유, 셀프 호스팅** |
| 서사 | "쉽죠!" | **"지저분하고, 반복적이지만, 진짜"** |

### vs. 개발자 콘텐츠

| 차원 | 개발자 콘텐츠 | Parksy |
|------|-------------|--------|
| 전제 지식 | 코딩 능력 필요 | **코딩 능력 제로** |
| 교육 방식 | "X를 구현하는 법" | **"AI에게 X 시켰더니 이런 일이"** |
| 관객 | 다른 개발자 | **AI에 호기심 있는 모든 사람** |
| 갈등 | 기술적 문제 | **인간-AI 협업 문제** |
| 드라마 | 낮음 (버그는 비개발자에겐 지루) | **높음 (비개발자가 AI랑 씨름하는 건 보편적으로 공감)** |

---

## 4. 콘텐츠 자산 인벤토리

아래 전부 **이미 존재**한다. 희망사항이 아니다. 포장만 하면 된다.

### 문서 (출판 대기)

| 자산 | 위치 | 분량 | 글로벌 관련성 |
|------|------|------|-------------|
| 소스풀 SCM 백서 v2 | `docs/SOURCE_POOL_SCM_WHITEPAPER.md` | ~4,500단어 | 높음 — 신선한 오픈소스 방법론 |
| 개발 철학서 | `docs/PARKSY_APK_PHILOSOPHY.md` | ~1,200단어 | 매우 높음 — 보편적 "왜" 서사 |
| ChronoCall 핸드오프 매뉴얼 | `CLAUDE.md` (섹션) | ~3,000단어 | 중간 — 기술 딥다이브 |
| S Pen 오버레이 백서 | `docs/SPen_Overlay_Whitepaper.md` | ~2,000단어 | 중간 — 니치하지만 유니크 |
| 레이저 펜 회고록 | `docs/LASER-PEN-RETROSPECTIVE.md` | ~1,500단어 | 높음 — Build #31 실패 스토리 |
| TTS Factory 현황 | `docs/TTS_FACTORY_STATUS.md` | ~800단어 | 낮음 — 상태 문서 |

### 앱 (시연 가능 제품)

| 앱 | 증명하는 것 | 콘텐츠 앵글 |
|----|-----------|------------|
| Parksy Pen v1.0.31 | 31번 반복 = 끈기 | "31번 빌드의 여정" |
| Parksy Capture v10.0.8 | 성숙한 도구 (v10!) | "AI가 만든 앱이 v10에 도달하면" |
| Parksy Wavesy v4.0.0 | 복잡한 오디오 파이프라인 | "AI가 오디오 에디터를 만들었다" |
| Parksy ChronoCall v1.0.0 | 풀 STT 파이프라인 | "코드 안 치고 음성→텍스트" |
| Parksy TTS v1.0.2 | 클라우드 TTS 연동 | "텍스트→음성→콘텐츠 파이프라인" |
| Parksy Liner v1.0.0 | 이미지 처리 (XDoG) | "AI가 쓴 알고리즘으로 사진→스케치" |
| Parksy Axis v11.1.0 | 앱 허브 (v11!) | "앱 10개를 한 허브에서 관리" |
| Parksy Subtitle v0.0.0 | 초기 단계 | "제로에서 시작 — VDD 생중계" |

### 인프라 (규모의 증거)

| 자산 | 증명하는 것 |
|------|-----------|
| `dashboard/` + Vercel 스토어 | 로컬 빌드가 아닌 실제 배포 파이프라인 |
| `scripts/license-audit.py` | 프로급 컴플라이언스 도구 |
| `scripts/source-pool-clone.sh` | 체계적 방법론 (즉흥 아님) |
| `scripts/constitution_guard.py` | 자체 부과 거버넌스 — "반상업 헌법" |
| 크로스레포 JSON 매니페스트 | 개인 규모에서의 산업적 오케스트레이션 |
| 28개 연결된 레포지토리 | 이야기를 신뢰할 수 있게 만드는 규모 |

### Git 히스토리 (원천 서사)

> **"레포지토리는 소설이다. 커밋이 문장이고, 브랜치가 챕터이고, `git log --reverse`가 줄거리다."**
>
> 이건 콘텐츠 전략의 비유가 아니다. 이것 자체가 콘텐츠 전략이다. 원재료는 이미 써져 있다 — git 안에.

---

## 5. 축별 증거물 맵

각 콘텐츠 축에 대해, 이미 존재하는 증거물과 새로 만들어야 할 것.

### 축 1: VDD (교육)

| 증거 유형 | 상태 | 위치 |
|----------|------|------|
| 철학 문서 | 있음 | `docs/PARKSY_APK_PHILOSOPHY.md` |
| 빌드 반복 데이터 (Pen #31) | 있음 | Git 히스토리 |
| 실패/회복 패턴 | 있음 | Git 히스토리 (fix: 커밋들) |
| VDD 방법론 글 | **만들어야 함** | → 블로그 / 영상 스크립트 |
| 비포/애프터 비교 | **만들어야 함** | → 스크린샷 + git diff |
| "시작하는 법" 프레임워크 | **만들어야 함** | → 가이드 문서 |

### 축 2: Source Pool SCM (기술)

| 증거 유형 | 상태 | 위치 |
|----------|------|------|
| 백서 v2 전문 | 있음 | `docs/SOURCE_POOL_SCM_WHITEPAPER.md` |
| 라이선스 감사 결과 | 있음 | 스크립트 출력 (GPL 위반 0건) |
| 자동화 스크립트 | 있음 | `scripts/` (6개, 전부 실행 가능) |
| 3-Tier 아키텍처 다이어그램 | 있음 | 백서 (ASCII) |
| F-Droid 레퍼런스 맵 | 있음 | 백서 부록 B |
| 법적 방어 프레임워크 | 있음 | 백서 섹션 3 |
| 백서 영어 번역 | **만들어야 함** | → 영어 버전 |
| 컨퍼런스 톡 슬라이드 | **만들어야 함** | → 프레젠테이션 |

### 축 3: phoneparis / 콘텐츠 팩토리 (플랫폼)

| 증거 유형 | 상태 | 위치 |
|----------|------|------|
| 플라이휠 다이어그램 | 있음 | 철학서 |
| "앱 1개 → 5개 아웃풋" 테이블 | 있음 | 철학서 |
| 크로스레포 오케스트레이션 | 있음 | `CLAUDE.md` + status.json |
| 스토어 페이지 (라이브) | 있음 | dtslib-apk-lab.vercel.app |
| 콘텐츠 팩토리 선언문 | **만들어야 함** | → 에세이 / 영상 스크립트 |
| 플랫폼 아키텍처 개요 | **만들어야 함** | → 기술 다이어그램 |

---

## 6. 퍼블리싱 채널

### 1차 (자체 플랫폼)

| 채널 | 유형 | 오디언스 | 콘텐츠 |
|------|------|---------|--------|
| parksy.kr | 허브 | 일반 | 전 콘텐츠, 한국어 + 영어 |
| @technician-parksy (YouTube) | 영상 | 글로벌 | 개발 다이어리, VDD 방법론 |
| eae.kr / PatchTech | 교육 | 학습자 | 구조화된 커리큘럼 |
| dtslib-apk-lab.vercel.app | 스토어 | 기술 | 앱 쇼케이스 + 다운로드 |
| GitHub (28 repos) | 소스 | 개발자 | 오픈소스 전부 |

### 2차 (글로벌 배포)

| 채널 | 유형 | 퍼블리싱할 콘텐츠 |
|------|------|-----------------|
| dev.to | 아티클 | Source Pool SCM 기술 시리즈 |
| Medium | 아티클 | VDD 방법론 시리즈 |
| Hacker News | 링크 | 철학서 + 백서 |
| Reddit r/androiddev | 포스트 | "비개발자가 AI로 Android 앱 10개 만들었다" |
| Reddit r/artificial | 포스트 | VDD 방법론 |
| Twitter/X | 스레드 | 핵심 인사이트, 빌드 스토리 |
| Product Hunt | 런치 | 스토어 페이지 (개별 앱 아님) |
| IndieHackers | 스토리 | "헌법으로 상용화를 금지한 앱" 앵글 |

### 3차 (증폭)

| 채널 | 유형 | 기회 |
|------|------|------|
| AI 팟캐스트 | 게스트 | "앱 공장을 만든 비개발자" |
| 개발 컨퍼런스 | 발표 | Source Pool SCM + VDD 방법론 |
| 대학 강의 | 게스트 | "코딩 능력 없는 AI 네이티브 개발" |
| 뉴스레터 피처 | 인터뷰 | Stratechery, TLDR, The Pragmatic Engineer |

---

## 7. 콘텐츠 캘린더 — 첫 90일

### Phase 1: 기반 구축 (1~30일)

**목표:** 기존 문서 영어 번역. 글로벌 존재감 확보.

| 주차 | 산출물 | 소스 재료 | 채널 |
|------|--------|----------|------|
| 1 | "The Parksy Manifesto" — 영어 철학서 | `PARKSY_APK_PHILOSOPHY.md` | 블로그, GitHub |
| 2 | "Source Pool SCM" — 영어 백서 | `SOURCE_POOL_SCM_WHITEPAPER.md` | dev.to, GitHub |
| 3 | "10 Apps, Zero Code" — 오버뷰 스레드 | `apps.json` + 스크린샷 | Twitter/X |
| 4 | "Build #1 to #31" — Parksy Pen 스토리 | Git 히스토리 + 회고록 | 블로그, YouTube 스크립트 |

### Phase 2: 심화 (31~60일)

**목표:** 딥다이브 콘텐츠 퍼블리싱. 첫 외부 트랙션 확보.

| 주차 | 산출물 | 축 | 채널 |
|------|--------|---|------|
| 5 | "What is Vibe Driven Development?" | VDD | 블로그 + Medium |
| 6 | "Automated License Compliance for Solo Developers" | Source Pool | dev.to |
| 7 | YouTube Ep.1: "I've never written code. Here are my 10 apps." | VDD | YouTube |
| 8 | "APKs Are Fab Equipment" — 콘텐츠 팩토리 테제 | phoneparis | 블로그 |

### Phase 3: 배포 (61~90일)

**목표:** 크로스포스트. 커뮤니티 참여. 컨퍼런스 제출.

| 주차 | 산출물 | 채널 |
|------|--------|------|
| 9 | Hacker News + Reddit 제출 | HN, Reddit |
| 10 | 개발 컨퍼런스 CFP 제출 (Source Pool SCM) | CFPs |
| 11 | YouTube Ep.2: "When AI Gets It Wrong — My Failure Taxonomy" | YouTube |
| 12 | "The Anti-Commercial Constitution" — 왜 앱을 절대 안 파는가 | IndieHackers, 블로그 |

---

## 8. 실행 로드맵 — 5/10에서 8/10으로

### 현재 막히는 것 (현 상태: 5/10)

| 블로커 | 영향 | 해결 |
|--------|------|------|
| 전 문서 한국어 | 글로벌 리치 불가 | 영어 번역 |
| 콘텐츠용 비주얼 에셋 없음 | 소셜/영상 불가 | 스크린샷, 다이어그램, OG 이미지 제작 |
| YouTube 존재감 없음 | 최대 콘텐츠 채널 미활용 | 첫 에피소드 녹화 |
| 영어 블로그 없음 | 번역 콘텐츠 홈 없음 | parksy.kr 영어 섹션 셋업 |
| 소셜 미디어 스레드 없음 | 디스커버리 표면 제로 | 런치 스레드 작성 |

### 우선순위 액션 (8/10 도달용)

| 우선순위 | 액션 | 공수 | 임팩트 |
|---------|------|------|--------|
| P0 | 철학서 + 백서 영어 번역 | 1일 (AI 활용) | 전 영어 콘텐츠 해금 |
| P0 | 앱 8개 전부 스크린샷 | 1일 | 소셜 + 영상 해금 |
| P1 | "10 Apps Zero Code" 오버뷰 글 작성 | 2시간 | 첫 글로벌 콘텐츠 |
| P1 | YouTube 에피소드 1 녹화 | 1세션 | 영상 존재감 확보 |
| P2 | 영어 블로그 섹션 셋업 | 1일 | 지속 콘텐츠의 홈 |
| P2 | Twitter/X 프레젠스 구축 | 2시간 | 디스커버리 + 배포 |
| P3 | HN / Reddit 포스팅 | 각 30분 | 커뮤니티 트랙션 |
| P3 | 컨퍼런스 CFP 제출 | 2시간 | 권위 구축 |

---

## 9. 성공 지표

상업 벤처가 아니다. 지표는 콘텐츠 중심이지, 매출 중심이 아니다.

### 선행 지표 (1~3개월)

| 지표 | 타겟 | 의미 |
|------|------|------|
| 영어 아티클 퍼블리싱 | 6개+ | 글로벌 소비용 콘텐츠 존재 |
| YouTube 에피소드 | 2개+ | 영상 존재감 확보 |
| GitHub 스타 (dtslib-apk-lab) | 50+ | 개발자 커뮤니티 인정 |
| HN/Reddit 업보트 | 단일 포스트 100+ | 이야기가 공감을 얻음 |
| 외부 언급/링크 | 3개+ | 남들이 이야기함 |

### 후행 지표 (3~6개월)

| 지표 | 타겟 | 의미 |
|------|------|------|
| 뉴스레터 피처 | 1개+ | 권위 인정 |
| 컨퍼런스 톡 수락 | 1개+ | 전문적 검증 |
| YouTube 구독자 | 500+ | 지속 가능한 오디언스 |
| "VDD" 용어 외부 사용 | 아무 사용이든 | 방법론에 생명력 |
| 인바운드 인터뷰 요청 | 아무 요청이든 | 이야기에 중력 |

### 비지표 (의도적 제외)

| 안 재는 것 | 이유 |
|-----------|------|
| 앱 다운로드 수 | 이건 개인 도구지, 제품이 아님 |
| 매출 | 헌법이 금지 |
| DAU/MAU | 유저 1명. 영원히. |
| 전환율 | 뭘로 전환? |
| 시장 점유율 | 무슨 시장? |

---

## 10. 마스터 서사 아크

모든 콘텐츠가 — 3축 전부 — 하나의 마스터 내러티브로 흘러간다:

```
ACT 1: "비개발자가 AI가 코드를 짤 수 있다는 걸 발견한다."
  → VDD 에피소드 1, 오버뷰 글, 철학 선언문

ACT 2: "앱 하나를 만든다. 그 다음 둘. 그 다음 열."
  → Build #31 스토리, 앱별 딥다이브, 기술 백서

ACT 3: "앱이 제품이 아니라는 걸 깨닫는다. 프로세스가 제품이다."
  → 콘텐츠 팩토리 테제, 플라이휠 에세이, "APK는 팹 장비"

ACT 4: "공장을 만든다. 그리고 공장을 문서화한다."
  → Source Pool SCM, 자동화 파이프라인, 크로스레포 오케스트레이션

ACT 5: "문서가 콘텐츠가 된다. 콘텐츠가 플랫폼이 된다."
  → 이 문서. 메타 레이어. 자기 꼬리를 먹는 뱀.
```

> **레포지토리는 소설이다.**
> **이 마케팅 플랜은 뒤표지다.**
> **이제 출판한다.**

---

## 부록 A: 콘텐츠용 핵심 인용구

기존 문서에서 추출. 헤드라인, 트윗 훅, 영상 제목으로 바로 사용 가능.

| 인용구 (영어 번역 포함) | 소스 | 최적 용도 |
|----------------------|------|----------|
| "APK는 팹 장비지 완제품이 아니다" / "APKs are fab equipment, not end products." | 철학서 | 영상 제목 |
| "레포지토리는 소설이다. 커밋이 문장이다" / "Repository is a novel. Commits are sentences." | 헌법 | 트위터 스레드 오프너 |
| "상용화를 포기한 게 아니라 족쇄를 벗어던졌다" / "I didn't give up commercialization — I threw off its chains." | 철학서 | 블로그 헤드라인 |
| "편집이 창작이다. 제로에서 시작은 낭만이지 효율이 아니다" / "Editing is creation. Starting from zero is romance, not efficiency." | 백서 | 아티클 훅 |
| "지저분한 영역을 점령한다. 그래서 아무도 없다" / "I occupy the messy territory. That's why nobody else is here." | 철학서 원칙 1 | 포지셔닝 |
| "사람이 뭘 만들지 결정. Claude가 어떻게 만들지 실행" / "The human decides WHAT. Claude decides HOW." | 백서 | VDD 설명 |
| "내 폰에서 돌아감. 그게 유일한 QA" / "It works on my phone. That's the only QA that matters." | 헌법 | 소셜 미디어 |
| "9개 앱, 68개 의존성, GPL 위반 0건" / "9 apps, 68 dependencies, 0 GPL violations." | 라이선스 감사 | 기술 신뢰도 |
| "빌드 31번. 매 실패 기록됨" / "Build 31. Each failure documented." | Pen 회고록 | 끈기 서사 |
| "앱 1개 → 아웃풋 5개" / "One app → five outputs." | 철학서 | 플라이휠 설명 |

## 부록 B: 콘텐츠 제목 브레인스토밍

### 블로그 / 아티클 (영어)

1. "I've Never Written a Line of Code. Here Are My 10 Android Apps."
2. "Vibe Driven Development: A Non-Developer's Framework for Building with AI"
3. "Why I Built 10 Apps I'll Never Sell"
4. "Source Pool SCM: How I Legally Source Code for 10 Android Apps"
5. "Build #1 to Build #31: A Laser Pen Overlay's Journey"
6. "The Anti-Commercial Constitution: My Apps Have a Bill of Rights"
7. "APKs Are Fab Equipment: When Your App Is a Means, Not an End"
8. "Automated License Compliance for the Solo AI Developer"
9. "F-Droid: The Developer Reference Library Nobody Talks About"
10. "28 Repos, One Story: Treating Git History as Narrative"

### YouTube 에피소드 (영어)

1. "I Made 10 Android Apps Without Writing Code" (훅)
2. "My App Failed 31 Times. Here's Every Failure." (빌드 스토리)
3. "When AI Gets Your Code Wrong: A Failure Taxonomy" (교육)
4. "The Factory That Makes Apps That Make Content" (메타/플라이휠)
5. "Live VDD Session: Building an App from Scratch with Voice" (시연)

### Twitter/X 스레드 (영어)

1. "I shipped 10 Android apps. I've never written a line of code. Here's how: 🧵"
2. "My app has a constitution that forbids commercialization. Here's why: 🧵"
3. "I built a license auditing pipeline for my personal apps. Am I insane? Yes. 🧵"
4. "The non-developer's guide to F-Droid as a code reference library: 🧵"

---

*이 문서는 Parksy 개발 철학서, 소스풀 SCM 백서 v2, VDD 방법론, 크로스레포 아키텍처를 통합한 글로벌 콘텐츠 마케팅 전략서다.*

*소스 재료 전부 존재. 앱 전부 빌드됨. 인프라 전부 라이브.*
*부족한 건 단 하나: publish 버튼을 누르는 것.*
