# Parksy APK Lab — 소스풀 & SCM 프로세스 백서 v2

> **작성일:** 2026-03-01
> **최종 갱신:** 2026-03-01 (v2 — 자동화 파이프라인 실장, 법적 방어 재정의)
> **문서 성격:** 소스 확보 → 편집 → 빌드 → 콘텐츠화에 이르는 전체 파이프라인의 프로세스 정의서 겸 법적 방어 논리서
> **한 줄 요약:** F-Droid 오픈소스 풀 + 공식 SDK + AI 편집 = Parksy 앱 제조 공정 (전 과정 자동화)

---

## 0. 이 문서의 목적

Parksy 앱 시리즈 개발에 있어 소스코드를 어디서 가져오고, 어떻게 관리하고, 어떤 법적 근거로 사용하고, 최종적으로 어떤 형태(앱 / YouTube 콘텐츠)로 아웃풋하는지를 정의한다.

이 문서 하나로 다음 질문에 전부 답할 수 있어야 한다:

1. 코드를 어디서 가져오는가?
2. 그것이 합법인가?
3. 어떤 프로세스로 편집하는가?
4. 결과물은 어떻게 배포되는가?
5. YouTube 콘텐츠화 시 법적 리스크는 없는가?
6. **이 전체 과정은 어떻게 자동화되는가?**

### v2 변경사항 (v1 대비)

| 항목 | v1 (7.5/10) | v2 |
|------|-------------|-----|
| GPL 방어 | "클린룸 구현" 주장 | **Independent Implementation** — 정직한 재정의 |
| 도구 체인 | jadx 포함 (Termux 미동작) | **apktool 기반** (Termux 검증 완료) |
| 자동화 스크립트 | 문서에만 존재 (유령 코드) | **`scripts/` 실장** — 실제 실행 가능 |
| 소스풀 디렉토리 | "제안" 수준 | **`setup-source-pool.sh`** 로 자동 생성 |
| 라이선스 체크 | 수동 체크리스트 | **`license-audit.py`** 자동 감사 |
| 코딩 자동화 | 언급 없음 | **AI 편집 파이프라인** 정의 |

---

## 1. 소스풀 아키텍처 (3-Tier)

### Tier 1: F-Droid 오픈소스 풀 (Primary)

```
역할:    구현 참조 + 아키텍처 학습 + 검증된 패턴 채용
법적 근거: 각 앱의 오픈소스 라이선스 (Apache 2.0, MIT 등)
방법:    scripts/source-pool-clone.sh → ~/references/fdroid/
```

**F-Droid란:** 오픈소스 Android 앱 전용 앱스토어. 등록 조건이 "소스코드 100% 공개"이며, F-Droid 서버가 직접 소스에서 빌드하여 APK를 배포한다. 4,000개 이상의 검증된 오픈소스 Android 앱이 있다.

| 비교 항목 | GitHub | F-Droid |
|-----------|--------|---------|
| 대상 | 모든 종류의 코드 | Android 앱 전용 |
| 오픈소스 필수 | 아님 (private repo 가능) | **100% 필수** |
| 빌드 검증 | 없음 | **서버에서 직접 소스 빌드** |
| 결과물 | 코드 | 코드 + 설치 가능 APK |
| 품질 보증 | 없음 | 소스 = 바이너리 일치 검증 |

**핵심 가치:** 디컴파일 필요 없이 원본 소스코드, 주석, 커밋 히스토리, 이슈 토론까지 전부 확보 가능하다.

#### Parksy 앱별 F-Droid 소스맵

| Parksy 앱 | F-Droid 참조 앱 | 라이선스 | 참조 포인트 |
|-----------|----------------|----------|------------|
| Wavesy (음원 편집) | Ringdroid | Apache 2.0 | 파형 편집, 오디오 자르기 |
| ChronoCall (STT) | whisperIME, Transcribro | Apache 2.0 | STT 파이프라인, 음성 인식 |
| TTS Factory | sherpa-onnx (k2-fsa) | Apache 2.0 | TTS + STT + 화자분리 통합 |
| Pen (오버레이) | DrawAnywhere | — | 오버레이 권한, 캔버스 드로잉 |
| Capture (클립보드) | Clipboard Cleaner | MIT | 클립보드 감시 로직 |

> **소스맵 매니페스트:** `~/references/source-map.json` (setup-source-pool.sh가 자동 생성)

#### sherpa-onnx 특별 주목

- **라이선스:** Apache 2.0 (상업 사용 포함 자유)
- **GitHub Stars:** 10,400+
- **커버리지:** STT + TTS + Speaker Diarization + VAD
- **의미:** ChronoCall의 유료 Whisper API, TTS Factory의 Google Cloud TTS, 향후 화자분리 기능을 모두 이 하나의 라이브러리로 대체 가능
- **온디바이스 추론:** 서버 없이 폰에서 직접 실행 → API 비용 제로

### Tier 2: 삼성 공식 SDK & API (Secondary)

```
역할:    기기 최적화 + 플랫폼 특화 기능
법적 근거: 삼성 개발자 공식 문서 및 SDK 라이선스
방법:    공식 문서 참조 → API 호출 → 기기별 테스트
```

| 참조 대상 | 용도 | 출처 |
|-----------|------|------|
| One UI API | 삼성 고유 UI 패턴 | developer.samsung.com |
| S Pen SDK | 필압, 제스처, 오버레이 | Samsung S Pen Framework |
| 녹음 폴더 경로 패턴 | 통화 녹음 파일 탐지 | 공식 문서 + 커뮤니티 검증 |
| Good Lock / Sound Assistant | UI/UX 패턴 참조 | 삼성 공식 앱 |

### Tier 3: 상용 앱 구조 참조 (Tertiary — 제한적)

```
역할:    UI/UX 패턴 및 아키텍처 참조 (코드 복사 아님)
법적 근거: 리버스 엔지니어링의 제한적 합법성 (호환성 목적)
방법:    scripts/extract-apk.sh → 구조 분석 → 개념만 참고 → 독자 구현
도구:    ADB + apktool (Termux 검증 완료)
```

**이 Tier는 보조적 수단이다.** Tier 1 (F-Droid)에서 해결 가능하면 Tier 3에 가지 않는다.

---

## 2. SCM (Source Code Management) 프로세스

### 2.1 소스 확보 파이프라인 — 자동화

이 파이프라인은 수동이 아니다. 각 단계에 대응하는 스크립트가 `scripts/`에 실장되어 있다.

```
┌─────────────────────────────────────────────────────────────┐
│              소스 확보 프로세스 (자동화)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [F-Droid 카탈로그]                                          │
│       │                                                     │
│       ▼                                                     │
│  앱 발견 → source-map.json에 등록                            │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────┐                    │
│  │ ./scripts/source-pool-clone.sh      │ ← 실행 가능        │
│  │   git clone → ~/references/fdroid/  │                    │
│  │   라이선스 파일 자동 검증             │                    │
│  └─────────────────────────────────────┘                    │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────┐                    │
│  │ python3 scripts/license-audit.py    │ ← 실행 가능        │
│  │   pubspec.yaml 의존성 스캔           │                    │
│  │   라이선스 DB 대조                   │                    │
│  │   GPL 오염 감지 → FAIL/PASS         │                    │
│  └─────────────────────────────────────┘                    │
│       │                                                     │
│       ├── PASS → 안전하게 참조 가능                           │
│       ├── WARN → LGPL/UNKNOWN → 수동 확인                    │
│       └── FAIL → GPL 오염 → 해당 의존성 제거                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 편집 워크플로우 (AI 자동 코딩)

> **"코딩 자체도 자동화한다."**

Claude Code가 단순 보조가 아니라, 전체 코딩 파이프라인의 주 실행자다.

```
┌─────────────────────────────────────────────────────────────┐
│              AI 자동 코딩 파이프라인                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 1: 소스풀 참조                                         │
│    Claude가 ~/references/fdroid/ 소스를 읽고 분석             │
│    → 구현 패턴, 아키텍처, 엣지 케이스 처리 방법 학습            │
│       │                                                     │
│  Step 2: 요구사항 수신                                       │
│    사용자: "음원 편집 앱에 MIDI 트리밍 추가해"                  │
│       │                                                     │
│  Step 3: AI 코드 생성                                        │
│    Claude Code가 참조 소스 기반으로 코드 작성                   │
│    → 검증된 패턴 채용 + Parksy 구조에 맞게 조합                 │
│    → 0에서 짜는 게 아니라 "검증된 재료로 요리"                  │
│       │                                                     │
│  Step 4: 자동 감사                                           │
│    python3 scripts/license-audit.py --strict                 │
│    → 새 의존성의 라이선스 자동 체크                             │
│    → GPL 오염 시 빌드 차단                                    │
│       │                                                     │
│  Step 5: 빌드 & 커밋                                         │
│    flutter build apk → 실기기 테스트                          │
│    git commit (서사 보존 — "레포지토리는 소설이다")              │
│       │                                                     │
│  Step 6: 스토어 동기화                                       │
│    python3 scripts/build_store_index.py                      │
│    → pubspec.yaml → dashboard/apps.json 자동 반영             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**핵심:** 사람은 "뭘 만들지" 결정하고, Claude가 "어떻게 만들지" 실행한다. 참조 소스풀이 Claude의 지식을 보강하여 실전 검증된 코드를 생산한다.

### 2.3 소스 풀 디렉토리 구조

`scripts/setup-source-pool.sh`가 아래 구조를 자동 생성한다:

```
~/
├── dtslib-apk-lab/              # Parksy 메인 레포 (결과물)
│   ├── apps/                    # 9개 Parksy 앱
│   ├── dashboard/               # 스토어 페이지
│   ├── scripts/                 # ★ 자동화 스크립트 (실장 완료)
│   │   ├── license-audit.py     #   의존성 라이선스 자동 감사
│   │   ├── extract-apk.sh       #   APK 추출 + apktool 디컴파일
│   │   ├── setup-source-pool.sh #   소스풀 디렉토리 초기화
│   │   ├── source-pool-clone.sh #   F-Droid 참조 일괄 clone
│   │   ├── build_store_index.py #   스토어 메타데이터 동기화
│   │   └── constitution_guard.py #  헌법 위반 감지
│   └── docs/
│       └── SOURCE_POOL_SCM_WHITEPAPER.md  ← 이 문서
│
├── references/                  # 참조 소스풀 (setup-source-pool.sh가 생성)
│   ├── fdroid/                  # Tier 1: F-Droid 오픈소스
│   │   ├── ringdroid/           #   → Wavesy 참조
│   │   ├── sherpa-onnx/         #   → ChronoCall + TTS 참조
│   │   ├── transcribro/         #   → ChronoCall 참조
│   │   ├── whisper-keyboard/    #   → ChronoCall 참조
│   │   └── clipboard-cleaner/   #   → Capture 참조
│   ├── samsung/                 # Tier 2: 삼성 공식 SDK 샘플
│   ├── decompiled/              # Tier 3: 구조 참조용 (git 제외)
│   ├── apks/                    # APK 임시 저장 (git 제외)
│   ├── source-map.json          # 소스 매핑 매니페스트
│   ├── .gitignore               # decompiled/, apks/ 제외
│   └── README.md                # 소스풀 규칙 문서
│
└── tools/                       # (향후) 크로스레포 자동화 도구
```

---

## 3. 법적 방어 논리

### 3.1 Tier 1 (F-Droid 오픈소스) — 완전 합법

```
근거: 각 프로젝트의 오픈소스 라이선스
결론: 사용, 수정, 배포, YouTube 공개 모두 합법
조건: 라이선스 고지 의무 준수
감사: scripts/license-audit.py가 자동 검증
```

| 라이선스 | 코드 사용 | 수정 배포 | YouTube 공개 | 조건 |
|----------|----------|----------|-------------|------|
| Apache 2.0 | O | O | O | NOTICE 파일 포함 |
| MIT | O | O | O | 저작권 고지 포함 |
| GPL v3 | O | O* | O | *배포 시 소스 공개 의무 |
| BSD | O | O | O | 저작권 고지 포함 |
| LGPL 3.0 | O | O | O | 동적 링크 시 의무 없음 |

### 3.2 GPL 방어 전략 — Independent Implementation (정직한 정의)

> **v1에서 "클린룸 구현"이라고 썼던 것은 부정확했다. 정정한다.**

**클린룸 구현(Clean Room Implementation)의 엄격한 정의:**
- 원본 코드를 **전혀 보지 않은** 개발자가
- **기능 스펙(사양서)만 보고** 처음부터 독립적으로 작성하는 것
- 법적으로 가장 강력한 방어이나, 현실적으로 어렵다

**Parksy의 실제 방법론 — Independent Implementation:**
- F-Droid 오픈소스 코드를 **읽고 구조를 이해한다** (합법 — 오픈소스 라이선스가 허용)
- 해당 코드를 **복사하지 않는다** (fork/copy-paste 하지 않음)
- 이해한 **개념과 패턴을 기반으로** Claude Code가 **새 코드를 생성한다**
- 결과물은 원본과 코드 레벨에서 다르다 (다른 언어, 다른 구조, 다른 변수명)

**이것이 합법인 이유:**

| 구분 | 클린룸 | Independent Implementation | 복사 |
|------|--------|---------------------------|------|
| 원본 코드 열람 | X | **O (오픈소스이므로 합법)** | O |
| 원본 코드 복사 | X | **X** | O (위반) |
| 결과물 독립성 | 완전 독립 | **구조적 독립** (다른 코드) | 종속 |
| GPL 전파 | 없음 | **없음** (코드 복사 없으므로) | 발생 |
| 법적 강도 | 최강 | **강** | 위반 |

**GPL 코드에 대한 Parksy 원칙:**

1. **Apache 2.0 / MIT 우선 채택** — GPL 앱이 있어도 같은 기능의 Apache 앱이 있으면 그걸 쓴다
2. **GPL 소스는 읽되 복사하지 않는다** — 개념 학습용으로만 참조
3. **실제 코드는 Claude Code가 생성한다** — 참조 패턴을 이해한 AI가 독립적인 새 코드를 작성
4. **결과물에 GPL 코드가 포함되었는지 자동 검증한다** — `license-audit.py --strict`

**라이선스 자동 감사 결과 (2026-03-01 기준):**
```
$ python3 scripts/license-audit.py
SUMMARY: 0 violations, 2 warnings
STATUS: WARN — FFmpeg LGPL (동적 링크, 의무 없음)
```

9개 앱, 68개 의존성 전수 검사 → GPL 오염 0건.

### 3.3 Tier 2 (삼성 공식) — 합법

```
근거: 공식 SDK 라이선스, 개발자 문서 이용약관
결론: SDK 사용 및 API 호출은 의도된 용도
조건: SDK 라이선스 조건 준수
```

삼성이 공식으로 제공하는 SDK와 문서를 참조하는 것은 해당 SDK의 존재 이유 그 자체다.

### 3.4 Tier 3 (상용 앱 구조 참조) — 조건부 합법

```
근거: 저작권법 상 리버스 엔지니어링의 제한적 허용
결론: 호환성 목적의 구조 분석은 허용
조건: 코드 복사/재배포 금지, 보호 기술 우회 금지
도구: scripts/extract-apk.sh (apktool 기반, Termux 검증)
```

#### 한국 저작권법 근거

**저작권법 제101조의4 (프로그램코드역분석):**
> 정당한 권한에 의하여 프로그램을 이용하는 자 또는 그의 허락을 받은 자는
> 호환에 필요한 정보를 쉽게 얻을 수 없고 그 획득이 불가피한 경우에
> 해당 프로그램의 호환에 필요한 부분에 한하여 프로그램코드역분석을 할 수 있다.

**적용:**
- "정당한 권한에 의하여 프로그램을 이용하는 자" → 합법적으로 설치한 앱의 사용자
- "호환에 필요한 정보" → 삼성 녹음 폴더 경로, Intent 규격 등
- Parksy ChronoCall이 삼성 녹음 앱과 연동하기 위한 분석 → 호환성 목적

#### 방어 라인

| 행위 | 합법 여부 | 근거 |
|------|----------|------|
| 내가 설치한 앱의 APK 추출 | O | 정당한 사용자의 백업 권리 |
| AndroidManifest.xml 구조 분석 | O | 호환성 정보 확인 |
| UI/UX 패턴 관찰 후 독자 구현 | O | 아이디어는 저작권 보호 대상이 아님 |
| 디컴파일 코드를 통째로 복사 | **X** | 저작물 복제 |
| 디컴파일 코드를 YouTube에 전체 공개 | **X** | 저작물 공중 송신 |
| 보호 기술(DRM 등) 우회 | **X** | 기술적 보호 조치 무력화 금지 |

**원칙: Tier 3는 "개념 이해"용이지 "코드 복사"용이 아니다.**

#### 감사 추적 (Audit Trail)

`scripts/extract-apk.sh`는 디컴파일 시 자동으로 `.extraction-audit.json`을 생성한다:

```json
{
  "package": "com.example.app",
  "extracted_at": "2026-03-01T10:00:00Z",
  "tool": "extract-apk.sh",
  "purpose": "structure_reference_only",
  "code_copied": false,
  "notes": "Tier 3 참조용. 코드 복사 금지. 개념/구조만 참고."
}
```

이 JSON이 존재하는 것 자체가 "구조 참조 목적"이었다는 증빙이 된다.

### 3.5 LGPL 방어 (FFmpeg)

Parksy 앱 중 Wavesy와 Audio Tools가 `ffmpeg_kit_flutter`를 사용한다. 이것은 LGPL 3.0이다.

| 조건 | Parksy 충족 여부 |
|------|-----------------|
| 동적 링크로 사용 | O — Flutter plugin은 동적 로드 |
| 수정분 공개 | N/A — FFmpeg 자체를 수정하지 않음 |
| 사용자에게 재링크 가능성 제공 | O — 소스 공개 레포이므로 누구나 다른 FFmpeg 빌드로 교체 가능 |
| 라이선스 고지 | O — 앱 내 오픈소스 라이선스 화면에 포함 |

결론: **LGPL 의무 완전 충족. 위반 없음.**

### 3.6 YouTube 콘텐츠화 방어 논리

#### 안전 영역 (Green Zone)

```
O  F-Droid 오픈소스 코드를 화면에 띄우고 분석/설명
   → 라이선스가 명시적으로 허용

O  "이 오픈소스 앱의 코드를 참고해서 내 앱을 이렇게 만들었다"
   → 교육적 콘텐츠 + 원저작자 크레딧

O  오픈소스 앱의 구조 다이어그램, 아키텍처 설명
   → 아이디어/구조는 저작권 대상이 아님

O  내 Parksy 앱 코드를 보여주면서 "이건 Ringdroid에서 영감 받았다"
   → 내 코드 + 출처 표시

O  디컴파일 과정 자체를 교육 목적으로 시연
   → 도구 사용법 교육은 합법
```

#### 위험 영역 (Red Zone)

```
X  상용 앱 디컴파일 코드를 화면에 통째로 노출
   → 저작물 공중 송신

X  "이 앱의 핵심 알고리즘이 이거다" + 상세 코드 공개
   → 영업비밀 침해 가능

X  "이렇게 하면 유료 기능 우회된다"
   → 기술적 보호 조치 무력화 교사

X  상용 앱 코드를 복사해서 내 앱에 넣고 배포
   → 저작권 침해
```

#### 최적 콘텐츠 전략

```
시리즈: "오픈소스로 나만의 Android 앱 만들기"

에피소드 구성:
1. "F-Droid에서 쓸만한 앱 5개 찾았다"
   → 앱 소개 + 설치 + 소스코드 링크

2. "소스코드 까보니 이렇게 만들었다"
   → 오픈소스 코드 화면 노출 OK + 분석 설명

3. "이걸 참고해서 내 앱에 적용해봤다"
   → Parksy 개발 과정 (내 코드 중심)

4. "삼성 앱은 이런 패턴을 쓰더라"
   → 개념만 말로 설명 (디컴파일 코드 직접 노출 X)

5. "결과물: Parksy Wavesy v4.0"
   → 완성된 앱 시연 + 비포/애프터
```

---

## 4. 개발 철학: "편집이 창작이다"

### 4.1 선언

> **표절부터 시작한다. 편집이 창작이다.**
> 베이스가 있으면 시간이 단축된다. 제로에서 시작하는 건 낭만이지 효율이 아니다.

이것은 소프트웨어 업계의 표준 관행이다. 이름만 다를 뿐이다:

| 업계 용어 | 의미 | 예시 |
|-----------|------|------|
| Fork | 남의 코드를 복사해서 내 것으로 발전 | Linux → Android |
| Leverage | 기존 솔루션 위에 구축 | WebKit → Chrome (Blink) |
| 바퀴를 재발명하지 마라 | 있는 걸 또 만들지 마라 | npm, pip 생태계 전체 |
| Standing on shoulders of giants | 거인의 어깨 위에 서라 | 뉴턴 이래 모든 과학 |

### 4.2 AI(Claude)의 역할 재정의 — 코딩 자동화

> **Claude Code는 보조 도구가 아니다. 제조 라인의 메인 프로세서다.**

| 단계 | 사람 (지시자) | Claude (실행자) |
|------|-------------|----------------|
| 기획 | "MIDI 편집 기능 추가" | — |
| 참조 분석 | — | ~/references/fdroid/ringdroid 읽고 파형 편집 패턴 학습 |
| 코드 생성 | — | 참조 기반으로 새 코드 작성 (복사 아님) |
| 라이선스 감사 | — | `license-audit.py --strict` 자동 실행 |
| 빌드 | — | `flutter build apk` 실행 |
| 커밋 | — | 서사 보존 원칙에 따라 커밋 메시지 작성 |
| 스토어 동기화 | — | `build_store_index.py` 실행 |
| 코드 리뷰 | 결과물 확인 | — |

**코딩 자동화의 품질 등식:**

```
최종 품질 = 소스풀 품질 × AI 편집 정확도 × 자동 감사 신뢰도 × 테스트 깊이

- 소스풀     = F-Droid 검증된 코드 + 라이선스 자동 확인 (높음)
- AI 편집    = Claude Code, 참조 기반 생성 (높음)
- 자동 감사  = license-audit.py + constitution_guard.py (자동)
- 테스트     = 실기기 Termux 빌드 (실전)

>>> 0에서 AI가 짠 코드 (중간) × 수동 감사 (누락 가능) × 테스트 (실전)
```

### 4.3 자동화 vs 수동의 차이

| 항목 | 수동 (v1) | 자동화 (v2) |
|------|-----------|-------------|
| 소스풀 구축 | 수동 git clone | `source-pool-clone.sh` (일괄, 라이선스 자동 검증) |
| 라이선스 확인 | 체크리스트 눈으로 확인 | `license-audit.py` (자동 감사, CI 연동 가능) |
| APK 분석 | 수동 adb + jadx | `extract-apk.sh` (원커맨드, 감사 추적 자동 생성) |
| 디렉토리 구조 | "제안" | `setup-source-pool.sh` (자동 생성 + README + .gitignore) |
| 코드 작성 | 수동 + AI 보조 | **AI 메인 + 사람 지시** |
| 스토어 동기화 | 수동 JSON 편집 | `build_store_index.py` (pubspec → apps.json 자동) |
| 헌법 위반 감지 | 사람이 PR 리뷰 | `constitution_guard.py` (CI 자동 차단) |

---

## 5. 도구 체인 (Toolchain) — 실장 완료

### 5.1 자동화 스크립트 목록

모든 스크립트는 `scripts/` 디렉토리에 실제로 존재하며 실행 가능하다.

| 스크립트 | 용도 | 실행 환경 | 상태 |
|----------|------|-----------|------|
| `scripts/license-audit.py` | 의존성 라이선스 자동 감사 | Python 3, 어디서든 | **실장 완료** |
| `scripts/extract-apk.sh` | APK 추출 + apktool 디컴파일 | Termux (ADB 필요) | **실장 완료** |
| `scripts/setup-source-pool.sh` | 소스풀 디렉토리 초기화 | Termux / bash | **실장 완료** |
| `scripts/source-pool-clone.sh` | F-Droid 참조 소스 일괄 clone | git 필요 | **실장 완료** |
| `scripts/build_store_index.py` | 스토어 메타데이터 동기화 | Python 3 | **기존** |
| `scripts/constitution_guard.py` | 헌법 위반 감지 | Python 3 | **기존** |

### 5.2 도구 체인 상세

| 도구 | 용도 | Tier | Termux 설치 |
|------|------|------|-------------|
| F-Droid 앱 | 오픈소스 앱 발견 + 설치 | 1 | 앱 설치 |
| git | 소스코드 clone | 1 | `pkg install git` |
| Samsung Developer Portal | 공식 SDK/문서 | 2 | 웹 |
| ADB (android-tools) | APK 추출 | 3 | `pkg install android-tools` |
| **apktool** | APK → smali/리소스 디컴파일 | 3 | **`pkg install apktool`** |

> **jadx는 사용하지 않는다.** jadx는 JVM 기반이며 Termux에서 메모리/호환성 문제가 있다.
> apktool은 Termux에 네이티브 패키지로 설치되며 AndroidManifest.xml, 리소스, smali 코드를
> 안정적으로 디컴파일한다. Parksy의 목적(구조 참조)에는 apktool이면 충분하다.

### 5.3 APK 추출 파이프라인 (Tier 3 한정)

실제 동작하는 스크립트: `scripts/extract-apk.sh`

```bash
# 사용법

# 1. ADB 연결
./scripts/extract-apk.sh --connect 192.168.x.x:PORT

# 2. 패키지 검색
./scripts/extract-apk.sh --list samsung.call

# 3. APK 추출 + 디컴파일 (원커맨드)
./scripts/extract-apk.sh com.samsung.android.callrecording
# → ~/references/decompiled/callrecording/ 에 결과 생성
# → .extraction-audit.json 감사 증빙 자동 생성

# 4. 매니페스트만 빠르게 확인
./scripts/extract-apk.sh --manifest com.example.app
```

출력 구조:
```
~/references/
├── apks/callrecording/
│   └── base.apk               # 추출된 APK 원본
└── decompiled/callrecording/
    ├── AndroidManifest.xml     # 디코딩된 매니페스트
    ├── res/                    # 리소스 (레이아웃, 문자열 등)
    ├── smali/                  # Dalvik 바이트코드 (참조용)
    └── .extraction-audit.json  # ★ 감사 증빙
```

---

## 6. 라이선스 컴플라이언스 — 자동 감사

### 6.1 자동 감사 시스템

수동 체크리스트는 누락이 발생한다. Parksy는 자동화로 이를 방지한다.

```bash
# 전체 앱 라이선스 감사
python3 scripts/license-audit.py

# 특정 앱만
python3 scripts/license-audit.py --app chrono-call

# CI에서 GPL 오염 시 빌드 실패
python3 scripts/license-audit.py --strict

# JSON 리포트 내보내기
python3 scripts/license-audit.py --json
```

### 6.2 감사 결과 해석

```
[O]  PERMISSIVE      — 자유롭게 사용 가능 (MIT, BSD, Apache)
[~]  WEAK_COPYLEFT   — 동적 링크 시 OK (LGPL)
[X]  STRONG_COPYLEFT — GPL 오염! 즉시 제거 필요
[?]  UNKNOWN         — DB에 없음, pub.dev에서 수동 확인 후 DB 등록
```

### 6.3 현재 감사 현황 (2026-03-01)

```
9개 앱, 68개 의존성 검사 완료
- GPL 오염: 0건
- LGPL (FFmpeg): 2건 (동적 링크, 의무 없음)
- UNKNOWN: 0건 (전수 등록 완료)
```

### 6.4 배포 전 체크리스트 (자동 + 수동 병행)

자동 (`license-audit.py`가 처리):
```
[자동] pubspec.yaml 의존성 전수 스캔
[자동] 라이선스 DB 대조 + 카테고리 분류
[자동] GPL 오염 감지 → exit 1
[자동] LGPL 경고 → 동적 링크 확인 안내
[자동] UNKNOWN 패키지 → 수동 확인 안내
```

수동 (사람이 확인):
```
□ 앱 내 "오픈소스 라이선스" 화면 구현 여부
□ CREDITS.md 또는 THIRD_PARTY_LICENSES.md 작성 여부
□ Tier 3 코드: 복사하지 않았는지 확인 (개념 참조만 했는지)
```

---

## 7. 위험 관리 매트릭스

| 리스크 | 확률 | 영향 | 대응 | 자동화 |
|--------|------|------|------|--------|
| GPL 코드 실수로 포함 | ~~중~~ **낮음** | 높음 | 소스 공개 또는 해당 코드 제거 | `license-audit.py --strict` |
| 상용 앱 코드 복사 발각 | 낮음 | 높음 | Tier 3은 개념 참조만, 코드 복사 금지 원칙 | `.extraction-audit.json` 증빙 |
| 라이선스 고지 누락 | ~~중~~ **낮음** | 중 | 배포 전 자동 감사 | `license-audit.py` |
| YouTube에서 저작권 클레임 | 낮음 | 중 | 오픈소스 코드만 화면 노출, 상용 앱은 개념만 설명 | — |
| 특허 침해 | 낮음 | 높음 | 개인 비상업 배포로 리스크 최소화 | — |
| 헌법 위반 (상용화 요소 유입) | ~~중~~ **낮음** | 중 | constitution_guard.py 자동 차단 | `constitution_guard.py` |
| 소스풀 라이선스 변경 | 낮음 | 중 | clone 시 LICENSE 파일 자동 검증 | `source-pool-clone.sh` |

---

## 8. 전체 자동화 파이프라인 요약

```
┌──────────────────────────────────────────────────────────────┐
│              PARKSY APK LAB — 제조 공정도                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ① 소스풀 구축                                                │
│     setup-source-pool.sh → 디렉토리 생성                      │
│     source-pool-clone.sh → F-Droid 참조 clone + 라이선스 검증  │
│                                                              │
│  ② AI 코딩                                                    │
│     사용자 지시 → Claude Code → 참조 기반 코드 생성              │
│     (복사 아닌 Independent Implementation)                     │
│                                                              │
│  ③ 자동 감사                                                  │
│     license-audit.py → GPL 오염 체크                          │
│     constitution_guard.py → 헌법 위반 체크                     │
│                                                              │
│  ④ 빌드                                                       │
│     flutter build apk → 실기기 테스트                          │
│                                                              │
│  ⑤ 동기화                                                     │
│     build_store_index.py → pubspec → apps.json → Vercel 배포  │
│                                                              │
│  ⑥ 커밋 (서사 보존)                                            │
│     "레포지토리는 소설이다" — 과정 전체를 기록                    │
│                                                              │
│  (선택) Tier 3 분석                                            │
│     extract-apk.sh → APK 추출 → apktool 디컴파일 → 구조 참조   │
│     감사 증빙 자동 생성                                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 9. 결론: 3줄 요약

1. **소스풀 = F-Droid (Primary) + 삼성 공식 (Secondary) + 구조 참조 (Tertiary)** — `source-pool-clone.sh`로 자동 구축
2. **프로세스 = 자동 clone → 자동 라이선스 감사 → AI 코딩 → 자동 빌드 → 자동 스토어 동기화** — 사람은 "뭘 만들지"만 결정
3. **법적 방어 = Independent Implementation + 자동 라이선스 감사 + 감사 증빙 자동 생성** — 정직하고 자동화된 컴플라이언스

> **"바퀴를 재발명하지 마라. 좋은 바퀴를 가져와서, 내 차에 맞게 깎아라."**
> **그리고 그 깎는 것도 자동화해라.**
> **그것이 포크이고, 그것이 편집이고, 그것이 공장이다.**

---

## 부록 A: 관련 문서

| 문서 | 위치 | 내용 |
|------|------|------|
| 개발 철학서 | `docs/PARKSY_APK_PHILOSOPHY.md` | "상용화의 족쇄를 벗어던진" Parksy 5원칙 |
| 이 백서 | `docs/SOURCE_POOL_SCM_WHITEPAPER.md` | 소스풀 + SCM + 법적 방어 + 자동화 |
| CLAUDE.md | 프로젝트 루트 | 레포 헌법 + 앱별 개발 가이드 |

## 부록 B: F-Droid 앱 카테고리별 레퍼런스

### 오디오 편집 (→ Wavesy)
| 앱 | 라이선스 | Stars | 핵심 참조 |
|----|----------|-------|----------|
| Ringdroid | Apache 2.0 | 3.3k | 파형 편집, 벨소리 자르기 |
| Audio Recorder (Dimowner) | GPL 3.0 | — | Material 3 녹음 UI (참조만, 코드 비사용) |

### 음성 인식 / STT (→ ChronoCall)
| 앱 | 라이선스 | Stars | 핵심 참조 |
|----|----------|-------|----------|
| whisperIME | Apache 2.0 | 200+ | 온디바이스 Whisper, 키보드 통합 |
| Transcribro | Apache 2.0 | 100+ | whisper.cpp 기반 전사 |
| Kõnele | Apache 2.0 | 300+ | 에스토니아어 STT, 다국어 아키텍처 |
| sherpa-onnx | Apache 2.0 | 10.4k | STT + TTS + 화자분리 + VAD 통합 |

### TTS (→ TTS Factory)
| 앱 | 라이선스 | Stars | 핵심 참조 |
|----|----------|-------|----------|
| RHVoice | LGPL 2.1 | 1.1k | 다국어 TTS 엔진 (참조만) |
| eSpeak NG | GPL 3.0 | 2.6k | 경량 TTS (참조만, 코드 비사용) |
| sherpa-onnx | Apache 2.0 | 10.4k | VITS/MeloTTS 모델 |

### 화면 오버레이 (→ Pen)
| 앱 | 라이선스 | Stars | 핵심 참조 |
|----|----------|-------|----------|
| DrawAnywhere | — | — | 오버레이 캔버스, SYSTEM_ALERT_WINDOW |

### 클립보드 관리 (→ Capture)
| 앱 | 라이선스 | Stars | 핵심 참조 |
|----|----------|-------|----------|
| Clipboard Cleaner | MIT | — | 클립보드 감시, 자동 정리 |

## 부록 C: 자동화 스크립트 사용법 요약

```bash
# === 소스풀 초기 구축 (최초 1회) ===
./scripts/setup-source-pool.sh           # 디렉토리 구조 생성
./scripts/source-pool-clone.sh           # F-Droid 참조 소스 clone
./scripts/source-pool-clone.sh --shallow # 용량 절약 shallow clone

# === 라이선스 감사 (배포 전 필수) ===
python3 scripts/license-audit.py              # 전체 감사
python3 scripts/license-audit.py --app wavesy # 특정 앱만
python3 scripts/license-audit.py --strict     # GPL 포함 시 빌드 실패
python3 scripts/license-audit.py --json       # JSON 리포트 내보내기

# === APK 분석 (Tier 3, 필요 시만) ===
./scripts/extract-apk.sh --connect 192.168.x.x:PORT  # ADB 연결
./scripts/extract-apk.sh --list samsung               # 패키지 검색
./scripts/extract-apk.sh com.samsung.app.name         # 추출 + 디컴파일

# === 소스풀 현황 확인 ===
./scripts/setup-source-pool.sh --status    # 현황
./scripts/source-pool-clone.sh ringdroid   # 특정 레포만 업데이트

# === 스토어 동기화 ===
python3 scripts/build_store_index.py       # pubspec → apps.json

# === 헌법 위반 감지 ===
python3 scripts/constitution_guard.py      # 변경 파일 스캔
```

---

*이 문서는 Parksy APK Lab의 소스 확보, 관리, 법적 방어, 자동화 프로세스를 정의하는 공식 백서 v2다.*
*모든 자동화 스크립트는 `scripts/` 디렉토리에 실장되어 있으며 실행 가능하다.*
*최종 갱신: 2026-03-01*
