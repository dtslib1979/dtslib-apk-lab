# Parksy APK Lab — System Architecture Whitepaper

> **Version:** v2.3 — Execution Document + Twin Store 연결
> **Date:** 2026-03-03
> **Author:** Parksy (Voice) + Claude Code (Implementation)
> **선행 문서:** SOURCE_POOL_SCM_WHITEPAPER.md (프로세스), CONTENT_MARKETING_PLAN.md (마케팅)
> **형제 문서:** dtslib-cloud-appstore/docs/SYSTEM_ARCHITECTURE_WHITEPAPER.md v1.1
> **한 줄 요약:** F-Droid 오픈소스 → 내 앱으로 커스터마이징 → 빌드/배포까지 — 공정 자동화 설계도

---

## 0. Fact Sheet

| 항목 | 수치 | 출처 |
|------|------|------|
| 앱 수 | **10** (8 스토어 등록 + 2 개발 중) | `apps/` + `dashboard/apps.json` |
| 총 코드 | **23,913줄** (Dart 18,964 + Kotlin 4,949) | `find apps -name "*.dart"` wc -l |
| 자동화 스크립트 | **9개**, ~2,000줄 | `scripts/` + `change-specs/` |
| CI/CD 워크플로우 | **21개**, 1,188줄 YAML | `.github/workflows/` |
| 런타임 의존성 | **68 패키지**, GPL 위반 **0건** | `license-audit.py` |
| 헌법 금지 패턴 | **10종** | `constitution_guard.py` |
| 버전 동기화 파일 | **6개/앱** | `CONTROL_KEYS.md §2` |
| 개발 기간 | 30일 (2026-01-31 ~ 2026-03-01) | `git log --reverse` |
| 커밋 수 | 62개 | `git log --oneline --all` |
| 직접 타이핑한 코드 | **0줄** | VDD 프로토콜 |
| 월 비용 | **~$5** (Whisper API only) | — |
| 스토어 | dtslib-apk-lab.vercel.app | Vercel 배포 |
| 형제 스토어 | dtslib1979.github.io/dtslib-cloud-appstore | GitHub Pages, 웹도구 9개 |

---

## 1. System Overview — 3-Layer × 5-Stage

```
┌─────────────────────────────────────────────────────────────┐
│                  Layer 3: DISTRIBUTION                      │
│  Vercel Store ← apps.json ← build_store_index.py           │
│  GitHub Releases ← CI/CD ← APK artifacts                   │
│  nightly.link ← workflow artifacts                          │
├─────────────────────────────────────────────────────────────┤
│                  Layer 2: AUTOMATION                        │
│                                                             │
│  ┌─────────┐ ┌────────┐ ┌──────────┐ ┌───────┐ ┌────────┐ │
│  │ Stage 1 │→│Stage 2 │→│ Stage 3  │→│Stage 4│→│Stage 5 │ │
│  │INGESTION│ │ANALYSIS│ │TRANSFORM │ │ BUILD │ │DISTRIB │ │
│  │ clone   │ │ parse  │ │ AI edit  │ │ CI/CD │ │ deploy │ │
│  └─────────┘ └────────┘ └──────────┘ └───────┘ └────────┘ │
│        │          │           │           │          │      │
│        └──────────┴───────────┴───────────┴──────────┘      │
│                    GOVERNANCE LAYER                          │
│         Constitution Guard + License Audit + Signing        │
├─────────────────────────────────────────────────────────────┤
│                  Layer 1: APP MANUFACTURING                 │
│  10 Flutter+Kotlin hybrid apps                              │
│  Shared architecture: Platform Channel IPC                  │
│  F-Droid Source Pool references                             │
└─────────────────────────────────────────────────────────────┘

      ↑ 모든 레이어를 관통하는 입력:
      🎤 Voice → Claude Code → Git Commit
```

### 자동화 현황

| Stage | 현재 | 자동화율 | 목표 |
|-------|------|----------|------|
| 1 Ingestion | `source-pool-clone.sh` 실장 | 60% | 90% |
| 2 Analysis | `source-pool-analyze.sh` 실장 | **70%** | 70% |
| 3 Transform | Claude Code 반자동 + `propagate.sh` | **60%** | 60% (반자동 유지) |
| 4 Build | GitHub Actions 21개 | **90%** | 95% |
| 5 Distribution | `build_store_index.py` 레지스트리 구동 | **80%** | 80% |
| **총합** | | **~72%** | **~79%** |

### 3-Level Hierarchy

```
레벨 0: 앱을 만든다              (수작업 — 완료)
레벨 1: 앱을 찍어내는 파이프라인    (생산 자동화 — 구축 중)
레벨 2: 기존 앱을 일괄 업데이트     (메타 자동화 — 설계 단계)
```

| 레벨 | 입력 | 출력 | 상태 |
|------|------|------|------|
| **Level 1: Production** | F-Droid URL | 새 앱 1개 | 5-Stage Pipeline (§3) |
| **Level 2: Propagation** | 변경 지시 1개 | 기존 앱 N개 일괄 업데이트 | Update Pipeline (§3A) |

**왜 Level 2가 가능한가:**

```
10개 앱이 전부:
  - 같은 헌법      (CONSTITUTION.md)
  - 같은 테마 구조  (AppTheme 클래스 중앙화 — GitHub Dark 4앱 + Parksy Gold 2앱)
  - 같은 패턴      (Flutter + Kotlin, Platform Channel IPC)
  - 같은 브랜드    (Parksy)
  - 같은 빌드 스택  (AGP 8.x, compileSdk 35, Java 17, GitHub Actions)
```

규격이 통일돼 있으니까 **하나의 변경이 전체에 전파 가능**하다.
반도체 팹의 공정 레시피와 같다 — 레시피 하나 바꾸면 라인에서 나오는 칩 전부가 바뀐다.

```
메타 프로그래밍 계층:

  코드          = 앱을 만드는 것
  파이프라인      = 코드를 만드는 것          ← Level 1
  프리셋/헌법    = 파이프라인을 만드는 것      ← Level 2
```

Level 2에서 프리셋을 바꾸면 → 파이프라인이 바뀌고 → 앱 전체가 바뀐다.
**유저 인풋 1개 → 전체 변경.** 이것이 메타 자동화다.

---

## 2. Layer 1: App Manufacturing Line

### 2.1 공통 아키텍처

```
┌──────────────────────────────────────────┐
│            Flutter (Dart)                 │
│  UI Layer → Services → State (Prefs)     │
│         │                                │
│  MethodChannel / EventChannel            │
├──────────────────────────────────────────┤
│            Android (Kotlin)              │
│  MainActivity (Channel Handler)          │
│  OverlayService / AudioCapture / FileIO  │
│  AndroidManifest.xml (permissions)       │
└──────────────────────────────────────────┘
```

### 2.2 앱 포트폴리오

| 앱 | Dart | Kotlin | 합계 | 핵심 기술 | 오버레이 |
|----|------|--------|------|----------|---------|
| Parksy Glot | 3,774 | 1,478 | 5,252 | 실시간 STT + 오버레이 | Yes |
| Parksy Audio Tools | 3,359 | 699 | 4,058 | MediaProjection + MIDI | Yes |
| Parksy Capture | 2,452 | 654 | 3,106 | Share Intent + GitHub API | No |
| Parksy Axis | 2,618 | 5 | 2,623 | FSM 상태 전이, 8테마 | Yes |
| Parksy Pen | 995 | 1,583 | 2,578 | S Pen 터치 분리 + 접근성 | Yes |
| ChronoCall | 2,110 | 145 | 2,255 | FFmpeg + Whisper STT | No |
| Parksy Wavesy | 1,940 | 5 | 1,945 | MP3 트림 + MIDI 편집 | No |
| Parksy TTS | 783 | 5 | 788 | Cloud TTS 배치 | No |
| Parksy Liner | 615 | 370 | 985 | XDoG 선화 추출 | No |
| MIDI Converter | 318 | 5 | 323 | Basic Pitch 변환 | No |
| **합계** | **18,964** | **4,949** | **23,913** | | |

### 2.3 Inter-App Communication

```
ChronoCall ──(Share Intent: text)──→ Capture ──→ GitHub 레포
외부 앱 ──(Share Intent: audio/*)──→ ChronoCall ──→ STT 변환
Audio Tools ──(파일시스템: WAV)──→ Wavesy ──→ 편집/트림
Android OS ──(Quick Settings Tile)──→ Pen ──→ 오버레이 시작
```

---

## 3. 5-Stage Pipeline — Execution Spec

### Stage 1: Ingestion (소스 확보)

| 항목 | 값 |
|------|-----|
| **입력** | F-Droid URL 또는 패키지명 |
| **출력** | `~/references/fdroid/{name}/` + 라이선스 검증 |
| **스크립트** | `scripts/source-pool-clone.sh` (163줄, 실장 완료) |
| **자동화율** | 60% (clone 자동, 탐색 수동) |

```bash
# 실행
./scripts/source-pool-clone.sh              # 전체 clone/update
./scripts/source-pool-clone.sh --shallow     # shallow clone
./scripts/source-pool-clone.sh ringdroid     # 특정 레포만
```

**등록된 소스풀 (5개):**

| 참조 앱 | 라이선스 | → Parksy 앱 |
|---------|----------|-------------|
| Ringdroid | Apache 2.0 | Wavesy |
| sherpa-onnx | Apache 2.0 | ChronoCall, TTS |
| Transcribro | Apache 2.0 | ChronoCall |
| whisper-keyboard | Apache 2.0 | ChronoCall |
| Clipboard Cleaner | MIT | Capture |

### Stage 2: Analysis (파싱/분석)

| 항목 | 값 |
|------|-----|
| **입력** | clone된 소스 디렉토리 |
| **출력** | `analysis-report.json` |
| **스크립트** | `scripts/source-pool-analyze.sh` (실장 완료) |
| **자동화율** | 70% |

**분석 항목 (구현 시):**

| 분석 | 명령 | 출력 |
|------|------|------|
| 디렉토리 구조 | `tree -L 3` | 구조 맵 |
| 빌드 시스템 | `build.gradle` 파싱 | compileSdk, minSdk, AGP |
| 의존성 | dependencies 블록 | 패키지 + 버전 |
| 라이선스 | LICENSE + SPDX 헤더 | GPL/Apache/MIT 판정 |
| 코드 규모 | `wc -l *.kt *.java` | 줄 수 |
| 헌법 호환 | `constitution_guard.py` | HARD/SOFT/PASS |

### Stage 3: Transformation (AI 편집)

| 항목 | 값 |
|------|-----|
| **입력** | 분석 리포트 + `transform-spec.json` |
| **출력** | 수정된 소스 + app-meta.json |
| **실행자** | Claude Code (Termux) |
| **자동화율** | 40% (AI가 편집, 사람이 지시 + 승인) |

이 Stage는 **반자동이 정답이다.** 완전 자동은 위험하다. "AI가 diff 생성 → 사람이 승인" 구조.

#### transform-spec.json — Field Definition

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `schema_version` | string | Y | — | `"transform-spec-v1"` |
| `source_package` | string | Y | — | 원본 패키지명 (예: `com.example.app`) |
| `target_package` | string | Y | — | 대상 패키지명 (예: `kr.parksy.newapp`) |
| `app_name` | string | Y | — | 대상 앱 이름 (예: `"Parksy NewApp"`) |
| `preset` | object | Y | — | 프리셋 3단계 (아래 §4 참조) |
| `keep_features` | string[] | N | `["*"]` | 유지할 기능 목록 |
| `remove_features` | string[] | N | `[]` | 제거할 기능 (예: `["login","analytics"]`) |
| `remove_permissions` | string[] | N | `[]` | 제거할 Android 권한 |
| `ui_screens_max` | int | N | `3` | 최대 화면 수 (헌법 §4) |
| `theme` | string | N | `"parksy-dark"` | 테마 프리셋 |
| `icon_source` | string | N | `null` | 커스텀 아이콘 경로 |
| `constitution_check` | bool | N | `true` | 변환 후 헌법 검사 실행 |
| `license_gate` | bool | N | `true` | 변환 전 라이선스 감사 실행 |
| `source_origin` | string | Y | — | `"forked:{url}"` 또는 `"hybrid:{url}"` |

**예시 (실행 가능):**

```json
{
  "schema_version": "transform-spec-v1",
  "source_package": "org.nicenoise.ringdroid",
  "target_package": "kr.parksy.wavesy",
  "app_name": "Parksy Wavesy",
  "preset": {
    "base": {
      "jdk": "17",
      "gradle": "8.4",
      "agp": "8.2.0",
      "min_sdk": 26,
      "target_sdk": 34,
      "compile_sdk": 34,
      "ndk": null
    },
    "build": {
      "flavor": null,
      "build_type": "debug",
      "signing": "debug-key",
      "proguard": false
    },
    "patch": {
      "package_rename": true,
      "app_name_rename": true,
      "icon_replace": false,
      "remove_activities": ["LoginActivity", "SettingsActivity"],
      "remove_services": [],
      "remove_receivers": [],
      "add_permissions": [],
      "remove_permissions": ["INTERNET"]
    }
  },
  "keep_features": ["audio_trim", "waveform_view"],
  "remove_features": ["login", "analytics", "ads", "in_app_purchase"],
  "ui_screens_max": 3,
  "theme": "parksy-dark",
  "constitution_check": true,
  "license_gate": true,
  "source_origin": "forked:https://github.com/nicenoise/ringdroid"
}
```

### Stage 4: Build (빌드/검증)

| 항목 | 값 |
|------|-----|
| **입력** | 수정된 소스 (git push) |
| **출력** | debug APK + GitHub Release |
| **스크립트** | GitHub Actions (21개 워크플로우) |
| **자동화율** | 90% |

```
git push → build-{app}.yml 트리거 (path-scoped)
  → Flutter setup → pub get → build apk --debug
  → constitution-guard.yml (정책 검사)
  → upload-artifact → GitHub Release (tag: {app}-latest)
```

**워크플로우 구성:**

| 카테고리 | 수량 | 트리거 |
|----------|------|--------|
| 앱 빌드 | 11 | push to main (앱 경로 변경 시) |
| 서비스 배포 | 5 | push/manual |
| 정책/테스트 | 3 | push/PR |
| 메타데이터 동기화 | 1 | pubspec 변경 시 |
| 기타 | 1 | — |

### Stage 5: Distribution (배포)

| 항목 | 값 |
|------|-----|
| **입력** | 빌드된 APK |
| **출력** | 스토어 갱신 + 기기 설치 |
| **스크립트** | `build_store_index.py` + `deploy-vercel.yml` |
| **자동화율** | 60% |

```
GitHub Release (자동)
  → nightly.link URL 생성 (자동)
  → build_store_index.py → apps.json 갱신 (반자동)
  → deploy-vercel.yml → Vercel 스토어 배포 (수동 트리거)
  → gh release download + termux-open (수동)
```

---

## 3A. Update Pipeline (Level 2: Propagation)

> Level 1이 "새 앱 생산"이라면, Level 2는 "기존 앱 일괄 개선"이다.
> Level 1만 있으면 조립 라인이다. Level 2가 있어야 공장이다.

### 3A.1 파이프라인 구조

```
입력: change-spec.json (변경 지시 1개)
  │
  ├─ 1. Scope Resolution
  │     app-registry.json에서 대상 앱 필터링
  │     scope: "all" | ["parksy-axis", "parksy-wavesy"]
  │
  ├─ 2. Pattern Matching
  │     각 앱에서 변경 대상 파일/패턴 탐색
  │     glob + grep으로 매칭
  │
  ├─ 3. Transformation
  │     type별 처리:
  │       theme    → sed/replace (constants.dart 색상값)
  │       dependency → pubspec.yaml 버전 갱신
  │       config   → build.gradle 설정 변경
  │       feature  → Claude Code 반자동 (템플릿 + 사람 승인)
  │       constitution → constitution_guard.py 규칙 추가
  │
  ├─ 4. Validation
  │     constitution_guard.py + license-audit.py 통과 확인
  │
  ├─ 5. Version Bump
  │     version-sync.sh × N앱 (patch 자동 증가)
  │
  └─ 6. Build & Deploy
        git push → CI 전체 빌드 → 스토어 갱신

출력: N개 앱 업데이트된 새 버전
```

### 3A.2 change-spec.json — Field Definition

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `schema_version` | string | Y | — | `"change-spec-v1"` |
| `type` | enum | Y | — | `theme` \| `dependency` \| `config` \| `feature` \| `constitution` |
| `scope` | string \| string[] | Y | `"all"` | `"all"` 또는 앱 ID 배열 |
| `description` | string | Y | — | 변경 설명 (커밋 메시지 겸용) |
| `targets` | object[] | Y | — | 변경 대상 목록 (아래 참조) |
| `version_bump` | enum | N | `"patch"` | `"major"` \| `"minor"` \| `"patch"` \| `"none"` |
| `constitution_check` | bool | N | `true` | 변경 후 헌법 검사 |
| `dry_run` | bool | N | `false` | 미리보기만 (실제 변경 안 함) |

**targets 배열 항목:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `files` | glob | Y | 대상 파일 패턴 (예: `lib/**/*.dart`) |
| `pattern` | string | Y | 찾을 패턴 (정규식 또는 리터럴) |
| `replacement` | string | Y | 대체할 값 |
| `mode` | enum | N | `"literal"` \| `"regex"` (기본: `"literal"`) |

### 3A.3 변경 유형별 자동화 가능성

| type | 자동화 | 방법 | 예시 |
|------|--------|------|------|
| `theme` | **100%** | sed/grep — `color_file` 기반 색상값 일괄 교체 (app_theme.dart / constants.dart / theme.dart) | 배경색 `0xFF1A1A2E` → `0xFF0D1117` |
| `dependency` | **100%** | pubspec.yaml 버전 교체 + pub get | `just_audio: ^0.9.36` → `^0.9.40` |
| `config` | **90%** | build.gradle 값 교체 | `compileSdk 34` → `35` |
| `constitution` | **100%** | constitution_guard.py 패턴 추가 | 금지 패턴 11번째 추가 |
| `feature` | **30%** | Claude Code 반자동 — 템플릿 생성 + 사람 승인 | "About 화면 추가" |
| `brand` | **90%** | AndroidManifest + app-meta.json + strings.xml | 앱 이름 프리픽스 변경 |

`theme`/`dependency`/`config`는 grep+sed로 완전 자동. 사람이 개입할 필요 없다.
`feature`만 반자동 — 이건 Level 1의 Stage 3과 같은 이유다 (코드 이해 필요).

### 3A.4 실행 예시

**예시 1: 테마 색상 일괄 변경 (100% 자동)**

```json
{
  "schema_version": "change-spec-v1",
  "type": "theme",
  "scope": "all",
  "description": "다크모드 배경색 변경: 네이비 → 퓨어블랙",
  "targets": [
    {
      "files": "lib/core/constants.dart",
      "pattern": "Color(0xFF1A1A2E)",
      "replacement": "Color(0xFF0D1117)"
    },
    {
      "files": "lib/core/constants.dart",
      "pattern": "Color(0xFF16213E)",
      "replacement": "Color(0xFF161B22)"
    }
  ],
  "version_bump": "patch"
}
```

결과: color_file이 있는 앱만 대상 (theme_strategy별 파일 위치를 app-registry.json이 제공).

**예시 2: 의존성 일괄 업데이트 (100% 자동)**

```json
{
  "schema_version": "change-spec-v1",
  "type": "dependency",
  "scope": "all",
  "description": "shared_preferences 3.0.0 마이그레이션",
  "targets": [
    {
      "files": "pubspec.yaml",
      "pattern": "shared_preferences: ^2.2.2",
      "replacement": "shared_preferences: ^3.0.0"
    }
  ],
  "version_bump": "minor"
}
```

**예시 3: 특정 앱만 SDK 업그레이드 (90% 자동)**

```json
{
  "schema_version": "change-spec-v1",
  "type": "config",
  "scope": ["parksy-axis", "parksy-wavesy", "chrono-call"],
  "description": "compileSdk 35 업그레이드 (Android 16 대응)",
  "targets": [
    {
      "files": "android/app/build.gradle",
      "pattern": "compileSdk 34",
      "replacement": "compileSdk 35"
    },
    {
      "files": "android/app/build.gradle",
      "pattern": "targetSdkVersion 34",
      "replacement": "targetSdkVersion 35"
    }
  ],
  "version_bump": "minor",
  "dry_run": true
}
```

### 3A.5 구현 스크립트: propagate.sh (실장 완료)

```bash
# 사용법
./scripts/propagate.sh change-specs/theme-pure-black.json          # 실행
./scripts/propagate.sh change-specs/theme-pure-black.json --dry-run # 미리보기

# 동작
# 1. change-spec.json 파싱
# 2. app-registry.json에서 scope 필터링
# 3. 각 앱 디렉토리에서 targets 패턴 매칭
# 4. dry_run이면 diff만 출력, 아니면 실제 변경
# 5. constitution_guard.py 실행
# 6. version-sync.sh × N앱
# 7. 변경 요약 출력

# 출력 예:
# [propagate] change-spec: theme-pure-black.json
# [propagate] scope: all (10 apps)
# [propagate] parksy-axis: 2 files changed
# [propagate] parksy-wavesy: 2 files changed
# [propagate] ... (×10)
# [propagate] constitution: PASS
# [propagate] version bump: patch (10 apps)
# [propagate] DONE: 10 apps updated, 20 files changed
```

---

## 4. Preset System — 3-Tier

앱마다 빌드 스택이 다르다. "URL 하나 넣으면 끝"은 80%만 된다.
나머지 20%는 **프리셋(레시피)**으로 해결한다.

### 4.1 구조

```
preset/
├── base     ← JDK/Gradle/AGP/SDK 버전 (빌드 환경)
├── build    ← flavor/buildType/signing (빌드 설정)
└── patch    ← 패키지명/앱명/아이콘/기능 제거 (커스터마이징)
```

### 4.2 Base Preset — Field Definition

| 필드 | 타입 | 필수 | 기본값 | 유효값 |
|------|------|------|--------|--------|
| `jdk` | string | Y | `"17"` | `"11"`, `"17"`, `"21"` |
| `gradle` | string | Y | `"8.4"` | semver |
| `agp` | string | Y | `"8.2.0"` | semver (Android Gradle Plugin) |
| `min_sdk` | int | Y | `26` | 21-35 |
| `target_sdk` | int | Y | `34` | 26-35 |
| `compile_sdk` | int | Y | `34` | 26-35 |
| `ndk` | string | N | `null` | `"25.1.8937393"` 등 (FFmpeg 사용 시) |
| `kotlin_version` | string | N | `"1.9.0"` | semver |

**프리셋 템플릿 (미리 정의):**

| 프리셋 ID | JDK | AGP | minSdk | 용도 |
|-----------|-----|-----|--------|------|
| `flutter-standard` | 17 | 8.2.0 | 26 | 대부분 앱 |
| `flutter-legacy` | 11 | 7.3.0 | 21 | 구형 플러그인 필요 시 |
| `flutter-ndk` | 17 | 8.2.0 | 26 | FFmpeg/네이티브 빌드 필요 시 |

### 4.3 Build Preset — Field Definition

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `flavor` | string | N | `null` | Gradle flavor (없으면 default) |
| `build_type` | string | Y | `"debug"` | `"debug"` only (헌법 §2) |
| `signing` | string | Y | `"debug-key"` | 서명 키 (아래 §7.4 참조) |
| `proguard` | bool | N | `false` | 코드 난독화 (debug에서 불필요) |
| `split_abi` | bool | N | `false` | ABI별 APK 분리 |

### 4.4 Patch Preset — Field Definition

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `package_rename` | bool | Y | `true` | 패키지명 변경 실행 여부 |
| `app_name_rename` | bool | Y | `true` | 앱 이름 변경 실행 여부 |
| `icon_replace` | bool | N | `false` | 아이콘 교체 여부 |
| `remove_activities` | string[] | N | `[]` | 제거할 Activity 클래스명 |
| `remove_services` | string[] | N | `[]` | 제거할 Service 클래스명 |
| `remove_receivers` | string[] | N | `[]` | 제거할 BroadcastReceiver |
| `add_permissions` | string[] | N | `[]` | 추가할 권한 |
| `remove_permissions` | string[] | N | `[]` | 제거할 권한 |

### 4.5 프리셋 선택 로직

```
입력: F-Droid URL

1. clone 후 build.gradle 파싱
2. AGP 버전 확인
   → ≥ 8.0: flutter-standard
   → < 8.0: flutter-legacy
3. 네이티브 의존성 확인
   → FFmpeg/OpenCV 등 존재: flutter-ndk
4. 실패 시 폴백
   → flutter-standard → flutter-legacy → 수동 설정
```

---

## 5. Data Model — Execution Spec

### 5.1 app-registry.json (신규 — 중앙 레지스트리)

**목적:** 10개 앱 전체를 하나의 SSOT로 관리. `CONTROL_KEYS.md`와 `dashboard/apps.json`의 불일치 해소.

**현재 문제:**
- apps.json: 8앱, CONTROL_KEYS.md: 9앱, apps/ 디렉토리: 10앱
- `build_store_index.py`: 6앱만 하드코딩 (ChronoCall, Liner 누락)
- Pen 버전: app-meta.json `v25.12.0` vs apps.json `v1.0.31`

**Field Definition:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | string | Y | 앱 슬러그 (예: `parksy-axis`) |
| `name` | string | Y | 표시 이름 (예: `"Parksy Axis"`) |
| `package` | string | Y | Android 패키지명 (예: `kr.parksy.axis`) |
| `directory` | string | Y | 소스 경로 (예: `apps/parksy-axis`) |
| `version` | string | Y | 현재 버전 (예: `"v11.1.0"`) — pubspec.yaml SSOT |
| `status` | enum | Y | `store-registered` \| `in-development` \| `archived` |
| `category` | string | Y | 기능 분류 (예: `broadcast`, `audio`, `utility`) |
| `overlay` | bool | Y | 오버레이 앱 여부 |
| `description` | string | Y | 한 줄 설명 |
| `icon_emoji` | string | N | 스토어 이모지 아이콘 |
| `release_tag` | string | N | GitHub Release 태그 (예: `parksy-axis-latest`) |
| `workflow` | string | Y | 빌드 워크플로우 파일명 |
| `dependencies` | string[] | Y | 주요 Flutter 의존성 |
| `source_origin` | string | Y | `"original"` \| `"forked:{url}"` \| `"hybrid:{url}"` |
| `theme_strategy` | enum | Y | `"hardcoded"` \| `"material3_seeded"` \| `"constants_class"` \| `"theme_model"` \| `"stub"` |
| `color_file` | string | N | 색상 정의 파일 경로 (없으면 null, propagate.sh theme type이 참조) |
| `constants_path` | string | N | constants.dart 경로 (없으면 null → version-sync.sh 스킵) |
| `home_screen_path` | string | N | home 화면 파일 경로 (없으면 null → version-sync.sh 스킵) |
| `compile_sdk` | int | Y | Android compileSdk (현재 전체 35 통일) |
| `min_sdk` | int | Y | Android minSdk |
| `target_sdk` | int | Y | Android targetSdk |
| `java_version` | string | Y | Java 버전 (현재 전체 "17" 통일) |
| `dart_lines` | int | N | Dart 코드 줄 수 |
| `kotlin_lines` | int | N | Kotlin 코드 줄 수 |

### 5.2 build-status.json (신규 — 빌드 대시보드)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | string | Y | 앱 슬러그 |
| `workflow` | string | Y | 워크플로우 파일명 |
| `last_build` | ISO8601 | Y | 마지막 빌드 시각 |
| `status` | enum | Y | `passing` \| `failing` \| `no_ci` |
| `apk_size_mb` | float | N | APK 크기 (MB) |
| `build_duration_sec` | int | N | 빌드 소요 시간 (초) |

### 5.3 source-map.json (소스풀 참조 추적)

`~/references/source-map.json` — `setup-source-pool.sh`가 자동 생성.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `parksy_id` | string | Y | Parksy 앱 슬러그 |
| `source_url` | string | Y | 원본 레포 URL |
| `fdroid_id` | string | N | F-Droid 패키지명 |
| `clone_date` | ISO8601 | Y | 최초 clone 일시 |
| `original_version` | string | Y | clone 시 원본 버전 |
| `original_license` | string | Y | 원본 라이선스 |
| `transformation_log` | string[] | N | 변환 작업 이력 |

---

## 6. Automation Scripts — 현황

9개 스크립트 `scripts/`에 실장 완료 + `change-specs/` 디렉토리.

```
scripts/
├── build_store_index.py    (~100줄)  app-registry.json → apps.json 동기화
├── constitution_guard.py   (124줄)  헌법 위반 검출 (금지 패턴 10종)
├── license-audit.py        (293줄)  의존성 라이선스 자동 감사
├── extract-apk.sh          (249줄)  APK 추출 + apktool 디컴파일 + 감사증빙
├── setup-source-pool.sh    (218줄)  소스풀 디렉토리 초기화
├── source-pool-clone.sh    (163줄)  F-Droid 참조 clone + 라이선스 검증
├── source-pool-analyze.sh  (~150줄)  소스 분석 → analysis-report.json [NEW]
├── version-sync.sh         (~120줄)  6-file 버전 동기화 엔진 [NEW]
└── propagate.sh            (~200줄)  Level 2 멀티앱 변경 전파 [NEW]
                           ───────
                           ~2,000줄

change-specs/
├── sdk35-upgrade.json       compileSdk 34→35 (config type)
├── intl-version-bump.json   intl ^0.18→^0.19 (dependency type)
└── accent-color-tweak.json  Gold accent 미세 조정 (theme type)
```

### 파이프라인 위치

```
Stage 1 ← source-pool-clone.sh, setup-source-pool.sh
Stage 2 ← source-pool-analyze.sh (실장 완료)
Stage 3 ← transform-spec.json + Claude Code 반자동
Level 2 ← propagate.sh + change-specs/*.json + version-sync.sh (실장 완료)
Stage 4 ← GitHub Actions (constitution_guard.py 포함)
Stage 5 ← build_store_index.py (레지스트리 구동), deploy-vercel.yml

크로스:  license-audit.py (Stage 1~4 어디서든 게이트)
크로스:  extract-apk.sh (Tier 3 참조 시만 사용)
SSOT:   app-registry.json (10앱 중앙 레지스트리, 모든 스크립트가 참조)
```

---

## 7. Governance Layer — Execution Spec

### 7.1 Constitution Guard

```
HARD BLOCK (CI 실패):  .github/**  scripts/**  dashboard/apps.json
SOFT WARNING (경고만):  apps/**  dashboard/**
NONE (스킵):           docs/**  *.md
```

**금지 패턴 10종:** firebase, analytics, crashlytics, admob, play_store, app_store, login/signup, subscription/payment, telemetry/tracking, multi_user/multi_device

**실행:** `constitution-guard.yml` — 모든 PR + main push에 자동 실행.

### 7.2 License Audit Pipeline

```bash
# 전체 감사
python3 scripts/license-audit.py

# 특정 앱
python3 scripts/license-audit.py --app chrono-call

# CI 게이트 (GPL 시 exit 1)
python3 scripts/license-audit.py --strict

# JSON 리포트
python3 scripts/license-audit.py --json
```

**판정 매트릭스:**

| 카테고리 | 판정 | 예시 |
|----------|------|------|
| PERMISSIVE | `[O]` PASS | MIT, BSD, Apache-2.0 |
| WEAK_COPYLEFT | `[~]` WARN | LGPL-3.0 (동적 링크 시 OK) |
| STRONG_COPYLEFT | `[X]` FAIL | GPL-2.0, GPL-3.0 → **빌드 차단** |
| UNKNOWN | `[?]` WARN | DB 미등록 → 수동 확인 후 등록 |

**현재 감사 현황:** 9개 앱, 68개 의존성, GPL 위반 0건, LGPL 2건 (FFmpeg, 동적 링크).

### 7.3 6-File Version Sync

버전 올릴 때 6개 파일 수동 수정 → 하나라도 빠지면 불일치.

| # | 파일 | 필드 | 형식 |
|---|------|------|------|
| 1 | `pubspec.yaml` | `version:` | `X.Y.Z+N` **(SSOT)** |
| 2 | `lib/core/constants.dart` | `version =`, `versionCode =` | `'X.Y.Z'`, `N` |
| 3 | `app-meta.json` | `"version"` | `"vX.Y.Z"` |
| 4 | `README.md` | 버전 표기 | 다양 |
| 5 | `lib/screens/home.dart` | 주석 내 버전 | `// vX.Y.Z` |
| 6 | `dashboard/apps.json` | 해당 앱 `version`, `lastUpdated` | `"vX.Y.Z"` |

**version-sync.sh 설계 (Phase 1 구현 대상):**

```bash
# 사용법
./scripts/version-sync.sh parksy-axis 11.2.0

# 동작
# 1. pubspec.yaml → version: 11.2.0+{auto-increment}
# 2. constants.dart → version = '11.2.0', versionCode = N
# 3. app-meta.json → "version": "v11.2.0"
# 4. README.md → 버전 표기 갱신
# 5. home.dart 주석 갱신
# 6. dashboard/apps.json → 해당 앱 version + lastUpdated
# 7. 변경 파일 목록 출력

# 출력: "6 files synced to v11.2.0"
```

### 7.4 Signing Rules

현재: debug APK only (헌법 §2). 향후 phoneparis F-Droid 레포 전환 시 필요.

| 규칙 | 값 | 비고 |
|------|-----|------|
| **debug vs release 분리** | debug: Android 기본 키, release: 전용 keystore | debug만 사용 중 |
| **keystore 보관** | 로컬: `~/.android/parksy-release.jks`, CI: GitHub Secrets `SIGNING_KEY` | 미생성 |
| **key rotation/분실** | keystore 백업: Google Drive (암호화 ZIP), 분실 시 신규 키 생성 + 앱 재설치 | 개인용이라 재설치 OK |
| **서명 실패 시** | **빌드 중단** (게이트). 서명 없이 배포 금지. | CI에서 강제 |

**Phase별 적용:**

| Phase | 서명 방식 | keystore |
|-------|----------|----------|
| 현재 (debug) | Android debug key (자동) | `~/.android/debug.keystore` |
| Phase 2 (release) | 전용 keystore | `parksy-release.jks` (GitHub Secrets) |
| Phase 3 (F-Droid) | F-Droid 서명 정책 준수 | F-Droid 서버가 재서명 |

---

## 8. Automation Decision Matrix

| 프로세스 | 현재 | 목표 | 우선순위 | 필요 도구 | 상태 |
|----------|------|------|----------|-----------|------|
| 스토어 인덱스 | **100%** | 100% | P1 | build_store_index.py (레지스트리 구동) | **완료** |
| 버전 동기화 | **90%** | 90% | P1 | version-sync.sh | **완료** |
| app-registry.json | **생성됨** | 유지 | P1 | 10앱 SSOT | **완료** |
| 빌드 표준화 | **100%** | 100% | P1 | compileSdk 35 + Java 17 통일 | **완료** |
| 색상 중앙화 | **100%** | 100% | P1 | AppTheme 클래스 (4앱 하드코딩 제거) | **완료** |
| 코드 구조 분석 | **70%** | 70% | P2 | source-pool-analyze.sh | **완료** |
| 라이선스 감사 | 90% | 유지 | — | license-audit.py | 완료 |
| 헌법 준수 검사 | 90% | 유지 | — | constitution_guard.py | 완료 |
| 빌드 | 90% | 유지 | — | GitHub Actions | 완료 |
| **Level 2: 일괄 전파** | **80%** | 80% | P2 | propagate.sh + change-specs/ | **완료** |
| change-spec 예시 | **3개** | 확장 | P2 | sdk35, intl, accent | **완료** |
| 테마 일괄 변경 | **100%** | 100% | P2 | propagate.sh theme type (color_file 기반) | **완료** |
| 의존성 일괄 업데이트 | **100%** | 100% | P2 | propagate.sh dependency type | **완료** |
| 앱 온보딩 템플릿 | 0% | 70% | P3 | transform-spec.json 기반 | 미구현 |
| F-Droid API 연동 | 0% | 50% | P3 | curl + jq | 미구현 |
| 기기 설치 자동화 | 0% | 50% | P3 | gh + termux-open | 미구현 |

---

## 9. FMEA (Failure Mode & Effects Analysis)

| # | 장애 모드 | 심각도 | 빈도 | 탐지 | RPN | 대응 |
|---|----------|--------|------|------|-----|------|
| F1 | 빌드 실패 | 중 | 높음 | 자동 | 6 | CI 에러 로그 → 의존성 업데이트 → 재빌드 |
| F2 | 라이선스 위반 | **상** | 낮음 | 자동 | 6 | license-audit.py --strict 게이트 |
| F3 | 버전 불일치 (6-file) | 중 | 낮음 | 자동 | **2** | version-sync.sh **실장 완료** |
| F4 | APK 크기 초과 | 하 | 낮음 | 없음 | 3 | 빌드 후 사이즈 체크 추가 |
| F5 | 헌법 위반 | 상 | 중 | 자동 | 4 | HARD → CI 차단 |
| F6 | 크로스레포 동기화 깨짐 | 중 | 중 | 없음 | 6 | 매니페스트 경유 강제 |
| F7 | build_store_index.py 불완전 | 하 | 해결 | 자동 | **1** | 레지스트리 구동 전환 **완료** |
| F8 | 프리셋 불일치 (AGP 버전) | 중 | 중 | 없음 | 6 | 프리셋 자동 탐지 로직 |
| F9 | Level 2 전파 실패 (일부 앱만 변경) | 중 | 낮음 | 자동 | **3** | propagate.sh --dry-run **실장 완료** (color_file 기반 타겟팅) |
| F10 | change-spec 패턴 미매칭 (앱마다 다른 형식) | 중 | 낮음 | 자동 | **3** | app-registry.json SSOT + theme_strategy/color_file 필드 **해결** |

**RPN** = 심각도(1-3) × 빈도(1-3) × 탐지난이도(1-3). **6 이상 즉시 대응.**

---

## 10. Implementation Roadmap (3-Phase)

### Phase 1: Foundation (즉시)

| 태스크 | 산출물 | 완료 기준 |
|--------|--------|-----------|
| `build_store_index.py` 10앱 확장 | 전체 커버 | `python3 scripts/build_store_index.py` → 10앱 출력 |
| `version-sync.sh` 작성 | 6-file 원커맨드 | `./scripts/version-sync.sh parksy-axis 11.2.0` → 6파일 갱신 |
| `app-registry.json` 초기 생성 | 10앱 중앙 레지스트리 | 모든 앱 필드 완성 |
| transform-spec.json 예시 2개 | 실행 가능 스펙 | Wavesy + ChronoCall 예시 |

### Phase 2: Pipeline + Level 2 (다음)

| 태스크 | 산출물 | 의존성 |
|--------|--------|--------|
| `source-pool-analyze.sh` 작성 | 코드 분석 자동 리포트 | Phase 1 |
| 프리셋 자동 탐지 로직 | build.gradle → 프리셋 매칭 | Phase 1 |
| 앱 온보딩 템플릿 | 신규 앱 뼈대 자동 생성 | app-registry.json |
| `build-status.json` 자동 생성 | CI 상태 대시보드 | GitHub API |
| **`propagate.sh` 작성** | **Level 2 일괄 전파 엔진** | **app-registry.json + version-sync.sh** |
| **change-spec.json 첫 실행** | **테마 or 의존성 일괄 변경 1건** | **propagate.sh** |

### Phase 3: Intelligence (나중)

| 태스크 | 산출물 | 의존성 |
|--------|--------|--------|
| 의존성 그래프 시각화 | 앱 간 공유 패키지 맵 | app-registry.json |
| Release signing 도입 | parksy-release.jks + CI 연동 | Phase 2 |
| F-Droid API 연동 | URL 입력 → 메타데이터 자동 추출 | Phase 2 |
| 회귀 탐지 | 의존성 업데이트 → 영향 범위 계산 | 의존성 그래프 |

---

## 11. Matrix Architecture — ERP × FAB

```
               ERP (가로축: 원장)
               │
               │  커밋=전표  git log=원장  크로스레포=인터페이스
               │
     ──────────┼──────────────────────────
               │
   FAB         │       ┌──────────────────┐
   (세로축:    │       │  JSON 매니페스트  │
    공정)      │       │  (교차점)         │
               │       └──────────────────┘
   BOM         │
   =pubspec    │   app-meta.json      = 제품 사양서 × 거래 증빙
   라우팅      │   apps.json          = 출하 목록 × 재고 현황
   =CI         │   source-map.json    = 원자재 입고 × 매입 전표
   WIP         │   build-status.json  = 수율 보고 × 손익 계산
   =브랜치     │   app-registry.json  = 제품 마스터 × 계정 과목
   수율        │   transform-spec.json= 작업 지시서 × 변경 전표  (Level 1)
   =빌드성공률 │   change-spec.json   = 공정 레시피 × 일괄 전표  (Level 2)
               │
```

**4대 원칙 × 파이프라인:**

| 원칙 | 파이프라인 적용 |
|------|----------------|
| 삭제 없다, 반대 분개 | source-map.json에 원본 기록. 삭제 아닌 변환 이력 |
| 증빙 없는 거래 없다 | transform-spec.json이 모든 변환의 증빙 |
| BOM 확인 후 착공 | Stage 2 Analysis + license-audit.py 통과 전 Stage 3 진입 금지 |
| 재공품 방치 금지 | WIP 브랜치 3개 이상 → 정리 강제 |

---

## 12. Failure Catalog

실패는 삭제하지 않는다. 서사의 갈등이다.

### F-1: FLAG_SECURE (Pen v20)
**시도:** 컨트롤 바에만 FLAG_SECURE 적용 → **실패:** 앱 전체 녹화 차단됨.
**원인:** FLAG_SECURE는 Window 단위. View 단위 불가. **교훈:** Android 보안 모델에 절충 없음.

### F-2: willContinue 실시간 스트리밍 (Pen v21)
**시도:** dispatchGesture() 실시간 터치 → **실패:** 완전 정지.
**원인:** 완성된 경로를 한 번에 전달하는 API. 실시간은 root 필요. **교훈:** API 파라미터가 존재해도 의도대로 동작하지 않을 수 있다.

### F-3: jadx 메모리 실패 (Source Pool v1)
**시도:** Termux jadx → **실패:** OutOfMemoryError.
**해결:** apktool로 교체 (Termux 네이티브 패키지, 안정적).

### F-4: FFmpeg Kit 충돌 (Wavesy)
**시도:** ffmpeg_kit + flutter_midi_pro 동시 사용 → `libc++_shared.so` 충돌.
**해결:** `pickFirst` 전략.

### F-5: Clean Room → Independent Implementation (백서 v1)
**시도:** "Clean Room" 주장 → **실패:** 실제로 소스를 읽고 학습했으므로 Clean Room 아님.
**해결:** "Independent Implementation"으로 정직하게 재정의. "읽되 복사하지 않는다."

---

## 13. Infrastructure Map

```
┌───────────────────────────────────────────────────────┐
│                      CLOUD                             │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐   │
│  │  GitHub   │  │  Vercel  │  │  GCP Cloud Run     │   │
│  │ Repo+CI   │  │ Store    │  │ TTS (asia-ne3)     │   │
│  │ Releases  │  │ Audio Web│  │ MIDI (us-central1) │   │
│  └─────┬─────┘  └────┬─────┘  └──────┬─────────────┘   │
└────────┼──────────────┼───────────────┼────────────────┘
         │    HTTPS     │    HTTPS      │   HTTPS
┌────────┼──────────────┼───────────────┼────────────────┐
│        ↓              ↓               ↓                │
│  ┌──────────────────────────────────────────────┐      │
│  │            Galaxy Tab S9                      │      │
│  │  ┌────┐ ┌────┐ ┌──────┐ ┌──────┐ ┌────┐     │      │
│  │  │Axis│ │Pen │ │Captur│ │Wavesy│ │TTS │     │      │
│  │  └────┘ └────┘ └──────┘ └──────┘ └────┘     │      │
│  │  ┌──────┐ ┌─────┐ ┌────┐ ┌─────┐ ┌────┐    │      │
│  │  │Chrono│ │Liner│ │Glot│ │Audio│ │MIDI│    │      │
│  │  └──────┘ └─────┘ └────┘ └─────┘ └────┘    │      │
│  │  Termux + Claude Code (VDD Interface)        │      │
│  └──────────────────────────────────────────────┘      │
│                      DEVICE                             │
└─────────────────────────────────────────────────────────┘
```

**비용:** GitHub $0, Vercel $0, GCP ~$0, Whisper ~$5/월. **합계 ~$5/월.**

---

## 14. Twin Store — Cloud Appstore 연결

> **APK Lab의 쌍둥이. 설치 없는 앱스토어.**
> 네이티브가 필요 없는 모든 것은 URL로 배포한다.

### 14.1 Twin Store Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Parksy Franchise OS                           │
│                                                               │
│   ┌─────────────────────┐     ┌─────────────────────────┐   │
│   │   APK Lab (이 레포)  │     │   Cloud Appstore (형제)  │   │
│   │   Native Track       │     │   Web Track              │   │
│   │                      │     │                          │   │
│   │ Flutter + Kotlin     │     │ HTML + JS + Canvas       │   │
│   │ .apk 배포            │     │ URL 배포                 │   │
│   │ Vercel + GH Releases │     │ GitHub Pages             │   │
│   │ 10개 앱, 24K줄       │     │ 9개 도구, ~17K줄         │   │
│   │                      │     │                          │   │
│   │ F-Droid 소스풀 O     │     │ F-Droid 소스풀 X         │   │
│   │ CI 빌드 필수         │     │ 빌드 없음 (파일=제품)    │   │
│   │ 자동화율 ~72%        │     │ 자동화율 ~95%            │   │
│   └─────────────────────┘     └─────────────────────────┘   │
│                                                               │
│   공통: 헌법 / 매트릭스 아키텍처 / 인터랙티브 5-Stage Pipeline  │
│   공통: Guard 거버넌스 / apps.json SSOT / 대시보드 패턴       │
└─────────────────────────────────────────────────────────────┘
```

### 14.2 비교표

| 차원 | APK Lab | Cloud Appstore |
|------|---------|----------------|
| **제품** | Flutter+Kotlin APK | 순수 HTML/JS/CSS 웹도구 |
| **빌드** | GitHub Actions 21개 | 없음 (브라우저가 런타임) |
| **배포** | Vercel + GitHub Releases | GitHub Pages |
| **의존성** | 68 Flutter 패키지 | 0 (CDN 3개뿐) |
| **파이프라인** | 5-Stage (F-Droid→APK) | 5-Stage (Spec→Deploy) |
| **F-Droid 소스풀** | **필수** (clone→transform→build) | **불필요** (직접 개발이 빠름) |
| **Level 2** | propagate.sh (구현 완료) | 미구현 (설계만) |
| **카테고리** | broadcast, audio, utility 등 | 영상, 오디오, 이미지, 유틸, **게임** |
| **월 비용** | ~$5 (Whisper) | $0 |

### 14.3 판단 기준

```
새 아이디어 →  네이티브 API 필요? (카메라/마이크/오버레이/파일시스템)
                    │
               ┌────┴────┐
               Yes       No
               │         │
               ▼         ▼
            APK Lab   Cloud Appstore
```

### 14.4 공유 패턴

두 레포가 독립적으로 개발됐지만 동일한 패턴을 공유한다:

| 패턴 | APK Lab | Cloud Appstore |
|------|---------|----------------|
| 대시보드 IIFE | `dashboard/index.html` | `index.html` |
| 인터랙티브 파이프라인 | F-Droid URL→5-Stage 실행 | Tool Spec→5-Stage 실행 |
| GitHub API 연동 | PAT + Contents/Actions API | PAT + Contents API |
| 앱 레지스트리 | `app-registry.json` | `apps.json` |
| Guard 스크립트 | `constitution_guard.py` | `cloudappstore_guard.py` |
| 상태 dot 애니메이션 | idle→active→done→fail | 동일 패턴 |

### 14.5 F-Droid 소스풀이 Cloud에 불필요한 이유

APK Lab: `F-Droid Kotlin 소스 → clone → transform → 같은 스택으로 APK 빌드`
Cloud:   `Kotlin 소스 → ??? → HTML/Canvas/JS` ← **기술 스택 불일치, 코드 재사용률 0%**

바둑판 Canvas 200줄, 체스판 Canvas 200줄. F-Droid 앱 2만줄 읽는 것보다 Claude Code로 직접 짜는 게 10배 빠르다. 가져올 가치가 있는 건 **데이터뿐** (SGF, Lichess CSV, OpenTDB JSON) — 이건 `curl` 한 번이면 된다.

상세 조사 결과: `dtslib-cloud-appstore/docs/SYSTEM_ARCHITECTURE_WHITEPAPER.md §8`

### 14.6 크로스레포 동기화

```
dtslib-apk-lab (이 레포)
    │
    ├──→ dtslib-cloud-appstore (형제)
    │     공유: 대시보드 패턴, Guard 구조, Pipeline 5-Stage 패턴
    │     방향: 패턴 참조만 (코드 복사 아님)
    │
    ├──→ parksy-image (에셋)
    │     visual-novel 에피소드 → cloud-appstore/visual-novel/
    │
    └──→ parksy-audio (에셋)
          Lyria 3 BGM → cloud-appstore 사운드트랙
```

크로스레포 이동은 명시적 스크립트로 (매트릭스 제2조).

---

## 15. Quantitative Profile

### 코드 언어 분포

| 언어 | 줄 수 | 비율 | 용도 |
|------|-------|------|------|
| Dart | 18,964 | 58.7% | Flutter UI + 비즈니스 로직 |
| Kotlin | 4,949 | 15.3% | Android 네이티브 |
| Python | 2,116 | 6.5% | 자동화 스크립트 + 서버 |
| Shell | 630 | 1.9% | 소스풀 자동화 |
| HTML/JS/CSS | 686 | 2.1% | 스토어 대시보드 |
| YAML | 1,188 | 3.7% | CI/CD 워크플로우 |
| **코드 합계** | **~28,500** | | |

### 생산성 지표

| 지표 | 값 |
|------|-----|
| 총 개발 기간 | 30일 |
| 커밋/일 | 2.07 |
| 코드/커밋 | ~435줄 |
| 앱/주 | 2.5개 |

---

## 16. YouTube Content Mapping

| 섹션 | 무기 | 콘텐츠 형태 |
|------|------|------------|
| §0 Fact Sheet | 무기 2 "Zero Lines" | 인포그래픽 |
| §1 3-Layer × 5-Stage | 무기 3 "Source Pool" | 아키텍처 데모 |
| §3 5-Stage Pipeline | 무기 3 | 단계별 워크스루 |
| §7 Governance | 무기 4 "My Own Store" | 헌법 시연 |
| §12 Failure Catalog | 무기 1 "31 Builds" | 실패 서사 |
| §11 Matrix Architecture | 무기 5 "Repo is Novel" | 메타 콘텐츠 |

---

## Appendix A: CLI Quick Reference

```bash
# === Stage 1: Ingestion ===
./scripts/setup-source-pool.sh              # 소스풀 초기화 (최초 1회)
./scripts/source-pool-clone.sh              # F-Droid 참조 전체 clone
./scripts/source-pool-clone.sh --shallow    # shallow clone
./scripts/source-pool-clone.sh ringdroid    # 특정 레포만

# === Stage 2: Analysis ===
./scripts/source-pool-analyze.sh ~/references/fdroid/ringdroid   # 소스 분석
python3 scripts/license-audit.py            # 전체 라이선스 감사
python3 scripts/license-audit.py --strict   # GPL 시 exit 1
python3 scripts/license-audit.py --json     # JSON 리포트

# === Stage 3: Transform (Tier 3 참조 시) ===
./scripts/extract-apk.sh --connect IP:PORT  # ADB 연결
./scripts/extract-apk.sh --list samsung     # 패키지 검색
./scripts/extract-apk.sh com.example.app    # 추출 + 디컴파일

# === Stage 4: Build ===
git push origin main                        # CI 자동 트리거
python3 scripts/constitution_guard.py       # 로컬 헌법 검사

# === Stage 5: Distribution ===
python3 scripts/build_store_index.py        # registry → apps.json
gh release download {tag} -p app-debug.apk  # APK 다운로드
termux-open app-debug.apk                   # 기기 설치

# === Level 2: Propagation ===
./scripts/propagate.sh change-specs/sdk35-upgrade.json --dry-run  # 미리보기
./scripts/propagate.sh change-specs/accent-color-tweak.json       # 실행

# === Version Management ===
./scripts/version-sync.sh parksy-axis 11.2.0   # 6-file 버전 동기화
```

## Appendix B: 문서 계보

| 문서 | 상태 | 역할 |
|------|------|------|
| **이 문서** | **v2.3 실행 문서** | 시스템 설계도 + 실행 스펙 |
| cloud-appstore 백서 | v1.1 | 형제 레포 시스템 설계도 (§14 참조) |
| SOURCE_POOL_SCM_WHITEPAPER.md | v2 확정 | 프로세스 정의 + 법적 방어 |
| CONTENT_MARKETING_PLAN.md | v2.0 확정 | 마케팅 전략 + 콘텐츠 무기 |
| PARKSY_APK_PHILOSOPHY.md | 확정 | 개발 철학 5원칙 |
| CONSTITUTION.md | v1.3 확정 | 거버넌스 13조 |
| CONTROL_KEYS.md | 운영 중 | 운영 프로토콜 |
| VDD-Report.md | 확정 | 방법론 논문 |
| MARKETING_STRATEGY_DRAFT.md | **DEPRECATED** | CONTENT_MARKETING_PLAN.md로 통합 |

---

> **"코드를 짜는 게 아니라 공장을 돌리고 있다.**
> **다만 그 공장의 원장이 git이고, 라인이 파이프라인일 뿐이다."**

---

*v2.3 — §14 Twin Store 연결. Cloud Appstore 형제 레포 비교표, F-Droid 소스풀 불필요 판정, 공유 패턴 정리, 크로스레포 동기화 맵.*
*v2.2 — Phase 1+2 구현 완료. app-registry.json SSOT 실장, version-sync.sh/propagate.sh/source-pool-analyze.sh 실장, 4앱 색상 중앙화, build.gradle 표준화 (compileSdk 35 + Java 17), change-specs/ 예시 3개.*
*v2.1 — Level 2 메타 자동화 추가. change-spec.json 스키마, propagate.sh 설계, Update Pipeline (§3A) 신설.*
*v2.0 — 실행 문서. v1 (as-is 현황) + to-be 설계를 통합. 스키마 필드 정의, 프리셋 시스템, 서명 규칙 추가.*
*최종 갱신: 2026-03-03*
