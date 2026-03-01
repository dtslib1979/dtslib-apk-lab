# PARKSY APK LAB — 글로벌 콘텐츠 마케팅 백서 v2.0

> **작성일:** 2026-03-01
> **버전:** v2.0 Final — 실전 배포 가능
> **한 줄 피치:** "코드 한 줄 안 치고 앱 10개 만든 공방이, 공장이 되는 순간의 다큐멘터리"

---

## 팩트 시트

이 문서에서 주장하는 모든 수치의 출처. 과장 없음. git이 증거.

| 주장 | 실제 수치 | 증거 |
|------|----------|------|
| "앱 10개" | 앱 디렉토리 10개 | `ls apps/` → 10개 |
| "스토어 등록 8개" | `dashboard/apps.json` 8항목 | 파일 직접 확인 |
| "커밋 60개" | 전 브랜치 합산 60커밋 | `git log --oneline --all \| wc -l` |
| "개발 기간 30일" | 2026-01-31 ~ 2026-03-01 | `git log --format='%ad' --date=short` |
| "자동화 스크립트 6개" | `scripts/` 6파일 | `ls scripts/` |
| "68개 의존성 0 GPL 위반" | license-audit.py 출력 | 백서 v2 섹션 6.3 |
| "헌법 금지 패턴 10개" | CONSTITUTION.md §11.5 | regex 10줄 |
| "Parksy Pen 31빌드" | laser-pen-overlay git 히스토리 | RETROSPECTIVE.md |

### 소스 문서 계보

| 소스 | 기여 | 흡수한 것 |
|------|------|----------|
| `MARKETING_STRATEGY_DRAFT.md` | 무기 5개, 바이럴 경로, "글 먼저 영상 나중" | 실행력, 경쟁 분석, 4-Tier 타겟 |
| `CONTENT_MARKETING_PLAN.md` v1 | 3축 구조, 증거물 맵, 서사 아크, 지표 | 분석 프레임워크, 인벤토리 |
| 터묵스 Claude 세션 | **"공방→공장 전환, 파이프라인이 상품"** | 마스터 서사의 중심축 |
| `VDD-Report.md` | 방법론 논문 | 증거물 확인 |
| `CONSTITUTION.md` v1.3 | 반상업 헌법 | 포지셔닝의 법적 뼈대 |
| `SOURCE_POOL_SCM_WHITEPAPER.md` v2 | 소스풀 백서 | 기술축 근거 |
| `PARKSY_APK_PHILOSOPHY.md` | 5원칙 철학서 | 세계관 |

---

## 1. 중심 서사: 공방에서 공장으로

> **"앱 자체는 창작이 아니다. 베이스 베끼고 편집한 거다.**
> **근데 그걸 자동화한 시스템은 니 거고, 그 과정을 찍은 서사가 콘텐츠다.**
> **앱이 상품이 아니라 파이프라인이 상품이다."**
>
> — 터묵스 Claude, 2026-03-01

이게 전략의 중심축이다. 기존 두 문서가 놓친 레이어.

### 3단계 구조

```
STAGE 1: 공방 (Workshop)                    ← 이미 완료
  수작업으로 Claude한테 하나하나 말해서 앱 10개 만듦.
  빌드 60번+. git log에 전 과정 기록.
  → 콘텐츠: "나 이거 했다" (증거 제시)

STAGE 2: 공장 (Factory)                     ← 전환점. 지금 여기.
  Source Pool 자동화. F-Droid URL 하나 → clone → 파싱 → AI 편집 → 빌드.
  license-audit.py, constitution_guard.py, build_store_index.py 이미 실장.
  → 콘텐츠: "이렇게 돌아간다" (시스템 시연)

STAGE 3: 방송국 (Studio)                    ← 다음
  파이프라인 자체가 콘텐츠. 공장 돌리는 영상이 방송.
  도구 → 콘텐츠 → 교육 → 도구 개선 플라이휠.
  → 콘텐츠: "이것이 콘텐츠 팩토리다" (메타 서사)
```

**마케팅은 Stage 1의 이야기를 팔면서, Stage 2의 전환을 다큐멘터리로 찍는 것이다.**

### 공방 연대기 — git이 증거

실제 커밋 날짜 기반. 30일간의 기록.

```
2026-01-31  ■ DAY 1 — 첫 커밋. APK 다운로드 URL 수정.
            Capture → GitHub Releases 마이그레이션.
            스토어 랜딩 Dark+Gold 리디자인.

2026-02-10  ■ DAY 11 — Axis v10.0.0 대규모 업그레이드.
            shareData IPC 동기화, 8 테마.
            같은 날 v10.0.1 핫픽스. 빌드 2번.

2026-02-11  ■ DAY 12 — DEVLOG 시스템 도입.
            "삽질→DB 레코드 전환."
            Claude 세션 운전 설명서 (CONTROL_KEYS.md).

2026-02-14  ■ DAY 15 — Axis v11.0.0.
            Overlay Direction Declaration.
            터치 차단 버그 발견→v11.1.0 즉시 수정.
            6파일 동기화 프로토콜 확립.

2026-02-17  ■ DAY 18 — ChronoCall Phase 1 MVP 착수.
            통화 녹음 STT 파이프라인 스캐폴딩.
            같은 날 프로덕션 코드 완성 (9 Dart + 1 Kotlin).

2026-02-18  ■ DAY 19 — ChronoCall CI 삽질.
            compileSdk 35 수정, ffmpeg-kit Maven 충돌,
            결국 ffmpeg_kit 제거 → 원본 직접 전송으로 전환.
            4커밋 연속 fix. "빌드 60번 OK" 철학의 증거.

2026-02-24  ■ DAY 25 — Parksy Liner v1.0.0.
            Photo → Sketch (XDoG 선화 추출).
            CI: gradle-wrapper.properties 수동 추가.

2026-02-25  ■ DAY 26 — 헌법 제정.
            헌법 제1조 "레포지토리는 소설이다".
            헌법 제2조 "매트릭스 아키텍처".

2026-02-26  ■ DAY 27 — Wavesy v3.0.0 리라이트.
            AIVA Trimmer → Parksy Wavesy 리브랜딩.
            flutter_midi_pro API 삽질 3연속.
            libc++_shared.so 충돌 해결.

2026-02-28  ■ DAY 29 — 크로스레포 시스템 도입.
            Control Tower 부트스트랩.
            세션 종료 프로토콜 의무화.
            개발 철학서 작성 — "상용화의 족쇄를 벗어던졌다."

2026-03-01  ■ DAY 30 — 공장 전환일.
            Wavesy v4.0.0 (MIDI 편집 엔진).
            스토어 2섹션 구조 (Production / Prototype Lab).
            소스풀 백서 v2 + 자동화 스크립트 4종 실장.
            글로벌 마케팅 전략 v1→v2.
```

**30일. 60커밋. 10앱. 6자동화 스크립트. 문서 7개. 헌법 1부.**
이 타임라인 자체가 콘텐츠다.

---

## 2. 포지셔닝

### 원라이너

> **"The guy who built 10 Android apps without writing a single line of code."**

이게 전부. 이 한 문장이 클릭을 만든다.

### 왜 글로벌인가

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

### 차별화 — 포지션은 비어있다

| 크리에이터 유형 | 약점 | Parksy 차별점 |
|----------------|------|--------------|
| 개발자가 AI로 빠르게 | "그래 넌 원래 개발자잖아" | **비개발자** |
| 한 번 만들고 끝 | 일회성 데모 | **10개 실사용 중** |
| ChatGPT/Copilot 사용 | 범용 도구 | **Termux + Claude Code** (하드코어) |
| 웹앱 만들기 | 브라우저에서 끝 | **네이티브 APK** 실기기 설치 |
| 출시가 목표 | 플레이스토어 종속 | **자체 앱스토어** 운영 중 |
| 성공 스토리만 | 실패 안 보여줌 | **31번 실패 git log** 공개 |

**"Non-developer + voice-only + 10 native apps + own app store + all failures in git"** — 이 조합을 가진 사람이 없다.

### 안티-포지셔닝

Parksy가 **아닌 것**:
- 노코드 플랫폼 이야기 아님 (이건 AI-code)
- 사이드 프로젝트 이야기 아님 (이건 산업 파이프라인)
- "코딩 배우기" 이야기 아님 (핵심이 코딩 안 배우는 것)
- 스타트업 이야기 아님 (비즈니스 모델 없음, **헌법 v1.3으로 금지**)
- 튜토리얼 채널 아님 (이건 다큐멘터리)

---

## 3. 타겟 오디언스 (4-Tier)

### Tier 1: AI Early Adopters (가장 큼, 첫 바이럴)
- Hacker News, Reddit r/ClaudeAI r/artificial r/androiddev
- Twitter/X AI 커뮤니티
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

## 4. 콘텐츠 3축 구조

### 축 1: VDD — Vibe Driven Development (교육축)

**핵심 테제:** 비개발자가 AI로 실제 소프트웨어를 만드는 반복 가능한 방법론. 마법도 운도 아니라 학습 가능한 프로세스.

**참조 문서:** `VDD-Report.md` (방법론 논문 — 이미 존재)

**VDD 핵심 구조 (VDD-Report에서):**
```
[생각] → [말] → [삼성 STT] → [텍스트] → [Claude] → [코드]
```

**VDD vs 기존 방법론:**

| 항목 | 전통적 개발 | 노코드 | VDD |
|------|------------|--------|-----|
| 코딩 지식 | 필수 | 불필요 | 불필요 |
| 입력 방식 | 키보드 | 마우스/클릭 | **음성** |
| 자유도 | 최상 | 제한적 | 높음 |
| 학습 곡선 | 가파름 | 완만함 | **없음** |
| 커스터마이징 | 무제한 | 플랫폼 한계 | 무제한 |
| 필요 역량 | 코딩 실력 | 툴 숙련도 | **명확한 설명력** |

**"빌드 60번 OK" 원칙:**
```
일반 개발자:     빌드 실패 → 짜증 → 포기 고려
VDD 개발자:      빌드 실패 → 다시 말함 → 반복 → 완성
```

### 축 2: Source Pool SCM (기술축)

**핵심 테제:** 오픈소스 코드를 소싱·감사·변환하는 자동화된 방법론. 법적 방어 + 자동 컴플라이언스 포함.

**참조 문서:** `SOURCE_POOL_SCM_WHITEPAPER.md` v2 (이미 존재)

**3-Tier 아키텍처:**
- Tier 1: F-Droid 오픈소스 (Primary — clone → AI 편집 → 빌드)
- Tier 2: 삼성 공식 SDK (Secondary — API/문서 참조)
- Tier 3: 상용 앱 구조 참조 (Tertiary — 개념만, 코드 복사 금지)

**자동화 수치:** 9개 앱, 68개 의존성, GPL 위반 0건.

### 축 3: phoneparis — 콘텐츠 팩토리 (플랫폼축)

**핵심 테제:** APK는 제품이 아니라 팹 장비. 앱 1개 → 아웃풋 5개 플라이휠.

**참조 문서:** `PARKSY_APK_PHILOSOPHY.md` (이미 존재)

**플라이휠:**
```
APK 개발 과정 ──→ YouTube (개발기)
     ▼
APK 도구 사용 ──→ YouTube (활용기)
     ▼
parksy.kr ──→ 페르소나 "박씨" 방송국
     ▼
eae.kr ──→ PatchTech 교육 시리즈
     ▼
IoT 하드웨어 ──→ 중국 칩 + Claude Code
```

---

## 5. 콘텐츠 무기 5개

레포에서 이미 존재하는 소재만으로 구성. **새로 만들 거 없음.**

### 무기 1: "The 31 Builds" — 바이럴 영상

```
제목: I Failed 31 Times Building One App. Here's What Happened.
포맷: 5-10분 YouTube
소재: LASER-PEN-RETROSPECTIVE.md (이미 작성됨)
서사: v7 시작 → v20 FLAG_SECURE 전멸 → v24 ghost mode 각성 → v25 완성
```

왜 먹히냐: 실패 서사는 만국 공통. 31번 빌드 기록이 git log에 전부 남아있음. **조작 불가. 진짜 삽질 증거.**

### 무기 2: "Zero Lines of Code" — 증거 영상

```
제목: 10 Android Apps. Zero Lines of Code. Just My Voice.
포맷: 15-20분 YouTube (데모 + 철학)
소재: VDD-Report.md + 10개 앱 실기기 시연
서사: 폰 켜기 → Termux → 음성 → Claude → 빌드 → 설치 → 실사용
```

왜 먹히냐: "Vibe Coding"이 트렌드인데 대부분 개발자가 함. **진짜 비개발자**가 증거 들고 나오면 다른 차원. VDD-Report.md가 이미 방법론 논문 수준.

### 무기 3: "Source Pool Pipeline" — 기술 데모 + 공방→공장 전환

```
제목: I Turn Open Source Apps Into My Own Tools Using AI
포맷: 10분 YouTube + 블로그
소재: SOURCE_POOL_SCM_WHITEPAPER.md + 실제 파이프라인 데모
서사: F-Droid 앱 선택 → clone → Claude 편집 → 빌드 → 내 폰에 설치
```

왜 먹히냐: "편집이 창작이다" 테제가 오픈소스 커뮤니티 **논쟁을 유발**함. 논쟁 = 트래픽.

**공방→공장 앵글 추가:**
이 무기의 진짜 서사는 "수작업으로 하던 걸 자동화했다"다.
- Before: 매번 Claude한테 하나하나 말해서 빌드
- After: `F-Droid URL → clone → parse → AI edit → license audit → build → store sync` 원커맨드

### 무기 4: "My Own App Store" — 철학 선언

```
제목: I Left Google Play. Built My Own App Store Instead.
포맷: 8분 YouTube + Reddit/HN 포스트
소재: CONSTITUTION.md v1.3 + phoneparis 컨셉 + Vercel 스토어
서사: 플레이스토어 탈출 → 개인 F-Droid → 자체 앱스토어
```

왜 먹히냐: 탈구글 서사는 프라이버시 진영에서 **영웅 서사.** CONSTITUTION.md v1.3의 Forbidden Patterns (firebase, analytics, admob, play store 전부 자동 차단)이 진정성 증거.

### 무기 5: "Repository is a Novel" — 메타 콘텐츠

```
제목: My Git Log is a Story. Every Commit is a Sentence.
포맷: Medium/Substack + YouTube
소재: 헌법 제1조 + narrative-extract.py + 실제 git log 시연
서사: 커밋 이력을 소설처럼 읽는 시연 → 서사 추출 도구 데모
```

왜 먹히냐: 개발자 문화에서 "git commit message" 논쟁은 끝없는 떡밥. "커밋이 문장이다"는 프레이밍이 신선.

---

## 6. 콘텐츠 자산 인벤토리

전부 **이미 존재.** 포장만 하면 된다.

### 문서

| 자산 | 위치 | 글로벌 관련성 |
|------|------|-------------|
| VDD 방법론 논문 | `VDD-Report.md` | **최고** — 무기 2의 핵심 소재 |
| 반상업 헌법 v1.3 | `CONSTITUTION.md` | **최고** — 무기 4의 증거 |
| 소스풀 백서 v2 | `docs/SOURCE_POOL_SCM_WHITEPAPER.md` | 높음 — 무기 3 소재 |
| 개발 철학서 | `docs/PARKSY_APK_PHILOSOPHY.md` | 매우 높음 — 세계관 |
| Build #31 회고록 | `docs/LASER-PEN-RETROSPECTIVE.md` | 높음 — 무기 1 소재 |
| S Pen 오버레이 백서 | `docs/SPen_Overlay_Whitepaper.md` | 중간 — 니치 |
| TTS Factory 현황 | `docs/TTS_FACTORY_STATUS.md` | 낮음 |

### 앱 (시연 가능)

| 앱 | 버전 | 증명하는 것 | 무기 매핑 |
|----|------|-----------|----------|
| Parksy Pen | v1.0.31 | 31번 반복 = 끈기 | 무기 1 |
| Parksy Capture | v10.0.8 | 성숙도 (v10!) | 무기 2 |
| Parksy Wavesy | v4.0.0 | 복잡한 오디오 파이프라인 | 무기 2, 3 |
| Parksy ChronoCall | v1.0.0 | 풀 STT 파이프라인 | 무기 2, 3 |
| Parksy TTS | v1.0.2 | 클라우드 연동 | 무기 2 |
| Parksy Liner | v1.0.0 | 이미지 처리 | 무기 2 |
| Parksy Axis | v11.1.0 | 앱 허브 (v11!) | 무기 4 |
| Parksy Subtitle | v0.0.0 | 초기 단계 | 무기 5 (VDD 생중계) |

### 인프라 (규모의 증거)

| 자산 | 증명하는 것 | 무기 매핑 |
|------|-----------|----------|
| Vercel 스토어 (라이브) | 실제 배포 파이프라인 | 무기 4 |
| `scripts/license-audit.py` | 프로급 컴플라이언스 | 무기 3 |
| `scripts/source-pool-clone.sh` | 체계적 방법론 | 무기 3 |
| `scripts/constitution_guard.py` | 자동 헌법 감시 | 무기 4 |
| `CONSTITUTION.md` v1.3 Forbidden Patterns | `firebase\|analytics\|admob\|play.?store` 자동 차단 | 무기 4 |
| 28개 연결 레포 | 규모의 신뢰성 | 무기 5 |

---

## 7. 바이럴 전략: 글 먼저, 영상 나중

> **"마케팅 먼저, 제작 나중."**

### Phase 0: 소재 정비 (현재)
```
백서, VDD-Report, 회고록, 헌법 — 전부 이미 있음.
부족한 것: 영어 번역 + 스크린샷.
```

### Phase 1: Show HN 선제타격

```
"Show HN: I built 10 Android apps without coding, using only voice + Claude"
→ HN 프론트페이지 가능성 있음 (AI + non-coder + real apps = HN 취향)
→ Reddit r/ClaudeAI 크로스포스트
→ Twitter/X 클립 동시 투하
```

**HN 포스트 구조 (500단어):**
- Hook: 한 문장 원라이너
- Proof: GitHub 링크 + 스토어 링크 + VDD-Report 링크
- Numbers: 10 apps, 28 repos, 60+ builds, 0 GPL violations
- Philosophy: "I'll never sell these. CONSTITUTION.md forbids it."
- Ask: "AMA about the process"

### Phase 2: 반응 기반 YouTube (댓글이 대본)

HN/Reddit 반응에서 가장 많이 나온 질문 → 그걸 영상으로:

| 예상 반응 | 대응 콘텐츠 |
|----------|-----------|
| "How?" | 무기 2 — "Zero Lines of Code" 데모 |
| "Bullshit" / "Prove it" | 무기 1 — "31 Builds" git log 증거 |
| "Open source?" | 무기 3 — "Source Pool Pipeline" |
| "Why not sell it?" | 무기 4 — "My Own App Store" + 헌법 |
| "Show me the git log" | 무기 5 — "Repository is a Novel" |

### Phase 3: 교육 시리즈 (EAE University)

```
바이럴 트래픽 → "나도 해보고 싶다" → 교육 채널로 유도
커리큘럼 = 28개 레포가 교재
```

---

## 8. 배포 채널 매핑

### 1차 발사 (글 기반 — 즉시 실행 가능)

| 채널 | 언어 | 콘텐츠 | 무기 |
|------|------|--------|------|
| Hacker News | EN | Show HN 포스트 | 2, 4 |
| Reddit r/ClaudeAI | EN | 크로스포스트 + 스크린샷 | 1, 2 |
| Reddit r/androiddev | EN | 기술 포커스 | 2, 3 |
| Reddit r/opensource | EN | F-Droid + Source Pool | 3, 4 |
| Twitter/X | EN | 스레드 + 30초 클립 | 2 |

### 2차 심화 (글 + 영상)

| 채널 | 언어 | 콘텐츠 | 무기 |
|------|------|--------|------|
| YouTube (EAE) | EN/KO 자막 | 교육 프레이밍 | 1, 2 |
| YouTube (dtslib) | EN | 기술 프레이밍 | 3, 4 |
| Medium/Substack | EN | 롱폼 글 | 3, 5 |
| dev.to | EN | 기술 아티클 | 3 |
| IndieHackers | EN | "반상업 헌법" 앵글 | 4 |

### 3차 증폭

| 채널 | 기회 |
|------|------|
| F-Droid 포럼 | 커뮤니티 직접 진입, phoneparis 정당성 |
| AI 팟캐스트 | "앱 공장을 만든 비개발자" 게스트 |
| 개발 컨퍼런스 CFP | Source Pool SCM + VDD 발표 |
| 뉴스레터 피처 | Stratechery, TLDR, The Pragmatic Engineer |
| parksy.kr | 전체 허브 (한국어 + 영어) |

---

## 9. 콘텐츠 캘린더 — 첫 90일

### Phase 1: 선제타격 (1~30일)

| 주차 | 산출물 | 소스 | 채널 |
|------|--------|------|------|
| 1 | 핵심 문서 영어 번역 (철학서 + 백서 + VDD-Report) | 기존 3개 문서 | GitHub |
| 2 | 앱 8개 스크린샷 + OG 이미지 | 실기기 캡처 | 어디서든 |
| 3 | **Show HN 포스트 발사** | 전체 레포 | HN, Reddit, Twitter |
| 4 | 반응 분석 → YouTube 에피소드 1 스크립트 | HN/Reddit 댓글 | 내부 |

### Phase 2: 심화 (31~60일)

| 주차 | 산출물 | 무기 | 채널 |
|------|--------|------|------|
| 5 | YouTube Ep.1: 반응 최다 질문 대응 | 1 또는 2 | YouTube |
| 6 | "What is VDD?" 블로그 (영어) | 2 | Medium, dev.to |
| 7 | "Source Pool: 공방에서 공장으로" 블로그 | 3 | dev.to, HN |
| 8 | YouTube Ep.2: "The 31 Builds" 또는 "Source Pool Demo" | 1 또는 3 | YouTube |

### Phase 3: 확장 (61~90일)

| 주차 | 산출물 | 채널 |
|------|--------|------|
| 9 | "The Anti-Commercial Constitution" 블로그 | IndieHackers, Medium |
| 10 | 컨퍼런스 CFP 제출 (Source Pool SCM + VDD) | CFPs |
| 11 | YouTube Ep.3: "APKs Are Fab Equipment" | YouTube |
| 12 | parksy.kr 영어 섹션 런칭 | parksy.kr |

---

## 10. 증거물 맵: 있는 것 / 만들어야 할 것

### 축 1: VDD (교육)

| 증거 | 상태 | 위치/액션 |
|------|------|----------|
| VDD 방법론 논문 | **있음** | `VDD-Report.md` |
| 빌드 반복 데이터 (Pen #31) | **있음** | Git 히스토리 |
| 실패/회복 패턴 | **있음** | Git fix: 커밋들 |
| 듀얼 AI 시스템 (PC Claude + Termux Claude) | **있음** | VDD-Report |
| VDD 방법론 **영어** 글 | 만들어야 함 | VDD-Report 번역 + 블로그화 |
| 비포/애프터 스크린샷 | 만들어야 함 | 실기기 캡처 |

### 축 2: Source Pool SCM (기술)

| 증거 | 상태 | 위치/액션 |
|------|------|----------|
| 백서 v2 전문 | **있음** | `docs/SOURCE_POOL_SCM_WHITEPAPER.md` |
| 자동화 스크립트 6개 | **있음** | `scripts/` (전부 실행 가능) |
| 라이선스 감사 (9앱 68의존성 0위반) | **있음** | 스크립트 출력 |
| F-Droid 레퍼런스 맵 | **있음** | 백서 부록 B |
| Independent Implementation 법적 프레임워크 | **있음** | 백서 섹션 3 |
| 백서 **영어** 번역 | 만들어야 함 | 번역 |
| 파이프라인 데모 영상 | 만들어야 함 | 실행 녹화 |

### 축 3: 콘텐츠 팩토리 (플랫폼)

| 증거 | 상태 | 위치/액션 |
|------|------|----------|
| 플라이휠 다이어그램 | **있음** | 철학서 |
| "앱 1개 → 5개 아웃풋" | **있음** | 철학서 |
| 스토어 페이지 (라이브) | **있음** | dtslib-apk-lab.vercel.app |
| 헌법 v1.3 (Forbidden Patterns 포함) | **있음** | `CONSTITUTION.md` |
| 크로스레포 오케스트레이션 | **있음** | `CLAUDE.md` + status.json |
| 공방→공장 전환 다큐멘터리 | 만들어야 함 | 영상/블로그 |

---

## 11. 마스터 서사 아크 — 5막

```
ACT 1: 발견
  "비개발자가 AI가 코드를 짤 수 있다는 걸 발견한다."
  → VDD-Report, 오버뷰 글, 철학 선언문
  → 무기 2: "Zero Lines of Code"

ACT 2: 공방 (Workshop)
  "앱 하나를 만든다. 실패한다. 31번 만에 성공한다. 10개를 만든다."
  → Build #31 스토리, 앱별 딥다이브
  → 무기 1: "The 31 Builds"

ACT 3: 각성
  "앱은 창작이 아니다. 베끼고 편집한 거다. 그 자체를 자동화해야 한다."
  → 공방→공장 전환 서사, Source Pool 백서
  → 무기 3: "Source Pool Pipeline"

ACT 4: 공장 (Factory)
  "F-Droid URL 하나로 앱이 나오는 파이프라인을 만든다."
  → 자동화 시연, 헌법 선언, 자체 앱스토어
  → 무기 4: "My Own App Store"

ACT 5: 방송국 (Studio)
  "공장을 찍은 영상이 콘텐츠다. 콘텐츠가 플랫폼이 된다."
  → 메타 서사, 플라이휠 시연, "레포지토리는 소설이다"
  → 무기 5: "Repository is a Novel"
```

> **기존 전략이 놓친 것:** ACT 3 (각성). 공방에서 공장으로 가는 전환점.
> **터묵스가 준 것:** "앱이 상품이 아니라 파이프라인이 상품이다."
> **이게 서사의 클라이맥스다.**

---

## 12. 성공 지표

### 재는 것

| KPI | 측정 | 의미 |
|-----|------|------|
| HN upvotes | Show HN 반응 | 기술 커뮤니티 검증 |
| GitHub stars | 소스 관심도 | 소재 재사용 가능성 |
| "How did you do this?" 댓글 수 | 궁금증 유발 | Phase 2 콘텐츠 수요 증거 |
| 영어 아티클 퍼블리싱 | 6개+ (3개월) | 글로벌 콘텐츠 존재 |
| YouTube 에피소드 | 2개+ (3개월) | 영상 존재감 |
| "VDD" 용어 외부 사용 | 아무 사용이든 | 방법론에 생명력 |
| F-Droid 포럼 반응 | 커뮤니티 진입 | phoneparis 정당성 |
| EAE 강의 등록 | 교육 전환율 | 본업 연결 |

### 안 재는 것 (의도적 제외)

| 비지표 | 이유 |
|--------|------|
| 앱 다운로드 수 | 개인 도구. 유저 1명. 영원히. |
| 매출 | **헌법 v1.3이 금지.** |
| DAU/MAU | 뭘 재? |
| 전환율 | 뭘로 전환? |
| 시장 점유율 | 무슨 시장? |

---

## 13. 실행 우선순위 — 지금 바로

| 순서 | 액션 | 공수 | 산출물 |
|------|------|------|--------|
| 1 | 핵심 문서 3개 영어 번역 (VDD-Report, 철학서, 백서) | 1일 | 글로벌 콘텐츠 해금 |
| 2 | 앱 8개 스크린샷 | 1일 | 비주얼 에셋 해금 |
| 3 | **Show HN 글 초안** — 영어 500단어 + 링크 3개 | 2시간 | 첫 발사체 |
| 4 | Reddit r/ClaudeAI 포스트 + 스크린샷 | 30분 | 크로스포스트 |
| 5 | Twitter/X 스레드 — 앱 10개 각각 한 줄 | 30분 | 소셜 존재감 |
| 6 | 반응 분석 후 YouTube 에피소드 1 결정 | 1주 대기 | 댓글이 대본 |

**글 먼저, 영상 나중. 마케팅 먼저, 제작 나중.**

---

## 14. 점수 평가

| 항목 | 점수 | 이유 |
|------|------|------|
| 소재 풍부도 | **9/10** | 28개 레포 + 10개 앱 + 문서 7개 + 헌법 + VDD 논문 |
| 차별화 | **9/10** | 글로벌 포지션 비어있음 확인 + 공방→공장 전환 서사 |
| 타겟 명확성 | **9/10** | 4-Tier 분리 + 채널별 무기 매핑 |
| 실행 준비도 | **7/10** | 글 기반 먼저 전략 + "댓글이 대본" 반응형 |
| 글로벌 적합성 | **8/10** | 한국 로컬 요소 제로, 전부 글로벌 소재 |
| **종합** | **8.4/10** | |

---

## 부록 A: 핵심 인용구 (한영 병기)

| 인용구 | 영어 | 소스 | 최적 용도 |
|--------|------|------|----------|
| "앱이 상품이 아니라 파이프라인이 상품" | "The app isn't the product. The pipeline is." | 터묵스 세션 | **마스터 서사 키라인** |
| "공방에서 공장으로" | "From workshop to factory" | 터묵스 세션 | 전환점 서사 |
| "APK는 팹 장비지 완제품이 아니다" | "APKs are fab equipment, not end products." | 철학서 | 영상 제목 |
| "레포지토리는 소설이다" | "Repository is a novel. Commits are sentences." | 헌법 제1조 | 트위터 오프너 |
| "족쇄를 벗어던졌다" | "I threw off the chains of commercialization." | 철학서 | 블로그 헤드라인 |
| "편집이 창작이다" | "Editing is creation." | 백서 | 아티클 훅 |
| "지저분한 영역을 점령한다" | "I occupy the messy territory." | 철학서 1원칙 | 포지셔닝 |
| "내 폰에서 돌아감. 그게 유일한 QA" | "It works on my phone. That's the only QA." | 헌법 | 소셜 |
| "9앱, 68의존성, GPL 위반 0건" | "9 apps, 68 deps, 0 GPL violations." | 감사 결과 | 기술 신뢰 |
| "빌드 60번 OK" | "Build 60 times? OK." | VDD-Report | 끈기 서사 |

## 부록 B: 콘텐츠 제목 (영어)

### 블로그/아티클

1. "I've Never Written a Line of Code. Here Are My 10 Android Apps."
2. "Vibe Driven Development: A Non-Developer's Framework for Building with AI"
3. "From Workshop to Factory: How I Automated My App Pipeline"
4. "Why I Built 10 Apps I'll Never Sell"
5. "Source Pool SCM: How I Legally Source Code for 10 Android Apps"
6. "Build #1 to Build #31: A Laser Pen Overlay's Journey"
7. "The Anti-Commercial Constitution: My Apps Have a Bill of Rights"
8. "APKs Are Fab Equipment: When Your App Is a Means, Not an End"
9. "Automated License Compliance for the Solo AI Developer"
10. "F-Droid: The Developer Reference Library Nobody Talks About"
11. "28 Repos, One Story: Treating Git History as Narrative"
12. "The App Isn't the Product. The Pipeline Is."

### YouTube

1. "I Made 10 Android Apps Without Writing Code"
2. "My App Failed 31 Times. Here's Every Failure."
3. "When AI Gets Your Code Wrong: A Failure Taxonomy"
4. "From Workshop to Factory: Building an App Pipeline with AI"
5. "The Factory That Makes Apps That Make Content"
6. "Live VDD Session: Building an App from Scratch with Voice"

### Twitter/X 스레드

1. "I shipped 10 Android apps. I've never written a line of code. 🧵"
2. "My apps have a constitution that forbids selling them. Here's why: 🧵"
3. "I built a license auditing pipeline for my personal apps. Am I insane? 🧵"
4. "From workshop to factory — how I automated building apps with AI: 🧵"

## 부록 C: Show HN 실전 초안

> 이건 "나중에 쓰자"가 아니다. 복붙해서 바로 올릴 수 있는 초안이다.

---

**Title:** Show HN: I built 10 Android apps without writing code, using only voice + Claude

**Body:**

I've never written a line of code. I'm not a developer. I build Android apps by talking to AI.

Over 30 days, I shipped 10 native Android apps using only voice input (Samsung STT) → Claude Code on Termux → Flutter build → install on my Galaxy. 60+ commits. Zero lines typed by hand.

The apps:
- Parksy Pen (S Pen laser overlay, 31 builds to get it right)
- Parksy Capture v10 (text capture → GitHub auto-archive)
- Parksy Wavesy v4 (MP3/MIDI audio editor)
- Parksy ChronoCall (call recording → Whisper STT → transcript viewer)
- Parksy TTS (batch text-to-speech)
- Parksy Liner (photo → sketch via XDoG algorithm)
- ...and 4 more

I'll never sell these. My apps have a constitution (CONSTITUTION.md) that literally forbids commercialization. It auto-blocks `firebase`, `analytics`, `admob`, `play.store` in CI.

The apps aren't the product. The pipeline is. I built:
- A 3-tier source pool (F-Droid open source → Samsung SDK → structure reference)
- Automated license auditing (9 apps, 68 dependencies, 0 GPL violations)
- A personal app store on Vercel (not Google Play)
- Cross-repo orchestration with JSON manifests

Everything is open source. Everything is documented. Git history = plot. Repository is a novel.

Links:
- Store: https://dtslib-apk-lab.vercel.app/
- GitHub: https://github.com/dtslib1979/dtslib-apk-lab
- VDD Report: [link to VDD-Report.md]
- Constitution: [link to CONSTITUTION.md]

I started as a workshop. Now I'm building a factory. AMA.

---

**예상 HN 반응 대응표:**

| 반응 | 빈도 | 준비된 답변 |
|------|------|-----------|
| "Not bad, but what's the code quality?" | 높음 | "It works on my phone. That's my QA. CONSTITUTION.md §1: Success = it works on my device." |
| "This is just vibe coding" | 높음 | "Exactly. I call it VDD — Voice-Driven Development. Here's the methodology paper: [VDD-Report.md]" |
| "AI wrote bad code" | 중간 | "Build 31. Each failure documented in git. That's the point — failure is plot, not shame." |
| "Why not sell it?" | 높음 | "I have a constitution that forbids it. Literally. With CI enforcement. [CONSTITUTION.md]" |
| "Open source license issues?" | 중간 | "Automated audit: 9 apps, 68 deps, 0 GPL violations. Script: license-audit.py" |
| "Prove you didn't write code" | 높음 | "git log --all --format='%an' shows only Claude commits. VDD-Report documents the voice-only workflow." |
| "What's the store page built with?" | 낮음 | "Plain HTML + JSON on Vercel. dashboard/index.html + apps.json. No framework." |

---

## 부록 D: Twitter/X 첫 스레드 초안

> 복붙 가능. 앱 10개 각 한 줄 + 스크린샷 슬롯.

```
I shipped 10 Android apps. I've never written a line of code.

I talk to AI. AI writes code. I install it on my phone.

30 days. 60 commits. Here are all 10: 🧵

1/ Parksy Pen v1.0.31 — S Pen laser pointer overlay for screen recording.
   31 builds. Every failure in git. Build 20 was the worst (FLAG_SECURE killed everything).
   [screenshot]

2/ Parksy Capture v10.0.8 — Share text from any app → auto-archive to GitHub.
   Version TEN. This one has been through wars.
   [screenshot]

3/ Parksy Wavesy v4.0.0 — Audio editor. MP3 trimming + MIDI editing.
   4 major versions. Started as "AIVA Trimmer", rewritten twice.
   [screenshot]

4/ Parksy ChronoCall v1.0.0 — Call recording → Whisper STT → timestamped transcript.
   Samsung call folder auto-detection. Share intent receiver.
   [screenshot]

5/ Parksy TTS v1.0.2 — Batch text-to-speech generator.
   Feed it text, get audio files. Simple.
   [screenshot]

6/ Parksy Liner v1.0.0 — Photo → Sketch. XDoG edge detection.
   AI wrote the image processing algorithm. I don't know what XDoG means.
   [screenshot]

7/ Parksy Axis v11.1.0 — App hub. Overlay controller for all Parksy apps.
   Version ELEVEN. 8 themes. IPC sync.
   [screenshot]

8/ Parksy Subtitle v0.0.0 — Dual subtitle overlay. v0. Just born.
   [screenshot]

9/ These apps have a constitution. CONSTITUTION.md.
   It forbids: login, analytics, ads, Play Store, multi-user.
   CI auto-blocks: firebase, admob, tracking, payment.
   I will never sell these.

10/ The apps aren't the product. The pipeline is.
    Automated source pool. License auditing. Personal app store.
    Workshop → Factory.

    Store: https://dtslib-apk-lab.vercel.app/
    GitHub: https://github.com/dtslib1979/dtslib-apk-lab

    AMA.
```

---

## 부록 E: 참조 문서 매트릭스

| 문서 | 위치 | 역할 | 무기 매핑 |
|------|------|------|----------|
| VDD-Report.md | 프로젝트 루트 | 방법론 논문 | 무기 2 |
| CONSTITUTION.md | 프로젝트 루트 | 반상업 헌법 v1.3 | 무기 4 |
| SOURCE_POOL_SCM_WHITEPAPER.md | docs/ | 소스풀 백서 v2 | 무기 3 |
| PARKSY_APK_PHILOSOPHY.md | docs/ | 5원칙 철학서 | 무기 4, 5 |
| LASER-PEN-RETROSPECTIVE.md | docs/ | Build #31 회고록 | 무기 1 |
| CLAUDE.md | 프로젝트 루트 | 레포 운영 헌법 | 무기 5 |
| MARKETING_STRATEGY_DRAFT.md | docs/ | 이 문서의 전신 (DRAFT) | — |
| CONTENT_MARKETING_PLAN.md | docs/ | 이 문서의 전신 (PLAN) | — |

---

---

## 결론: 3줄 요약

1. **팔 앱이 없다. 팔 이야기가 있다.** — 30일, 60커밋, 10앱, 0줄 코딩. git이 증거.
2. **공방이 공장이 됐다.** — 수작업 VDD → Source Pool 자동화. 파이프라인이 상품이다.
3. **글 먼저, 영상 나중. 마케팅 먼저, 제작 나중.** — Show HN 초안은 부록 C에 있다. 복붙해서 쏘면 된다.

> **"앱이 상품이 아니라 파이프라인이 상품이다."**
> **그리고 그 파이프라인을 문서화한 이 백서 자체가 콘텐츠다.**
> **자기 꼬리를 먹는 뱀. 우로보로스. 그게 콘텐츠 팩토리다.**

---

*이 백서는 MARKETING_STRATEGY_DRAFT (실행력) + CONTENT_MARKETING_PLAN v1 (분석) + 터묵스 인사이트 (공방→공장)를 통합한 최종본이다.*
*v2.0 — 실전 배포 가능. Show HN 초안 + Twitter 스레드 + HN 반응 대응표 포함.*
*최종 갱신: 2026-03-01*
