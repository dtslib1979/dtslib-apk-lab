# DTS APK Lab - Claude Code Instructions

---

## 헌법 제1조: 레포지토리는 소설이다

> **모든 레포지토리는 한 권의 소설책이다.**
> **커밋이 문장이고, 브랜치가 챕터이고, git log --reverse가 줄거리다.**

- 삽질, 실패, 방향 전환 전부 남긴다. squash로 뭉개지 않는다.
- 기능 구현 과정 = 플롯 (문제→시도→실패→전환→해결)
- 레포 서사 → 블로그/웹툰/방송 콘텐츠로 파생 (액자 구성)

### 서사 추출 명령

```bash
narrative-extract.py --repo .                    # 이 레포 줄거리
narrative-extract.py --repo . --format synopsis  # 시놉시스
narrative-extract.py --repo . --format blog      # 블로그 원고
narrative-extract.py --repo . --climax           # 전환점만
narrative-extract.py --all ~                     # 28개 레포 연작 인덱스
```

### 서사 분류

| 커밋 유형 | 서사 | 의미 |
|-----------|------|------|
| `feat:` / 기능 추가 | 시도 | 주인공이 무언가를 만든다 |
| `fix:` / 버그 수정 | 삽질 | 예상대로 안 됐다 |
| `migration` / 전환 | 전환 | 버리고 다른 길을 간다 |
| `rewrite` / v2 | 각성 | 처음부터 제대로 다시 한다 |
| `refactor:` | 성장 | 같은 일을 더 잘하게 됐다 |
| `docs:` | 정리 | 지나온 길을 돌아본다 |

---

## ⚙️ 헌법 제2조: 매트릭스 아키텍처

> **모든 레포지토리는 공장이다.**
> **가로축은 재무 원장(ERP)이고, 세로축은 제조 공정(FAB)이다.**

### 가로축: 재무 원장 (ERP 로직)

커밋은 전표다. 한번 기표하면 수정이 아니라 반대 분개로 정정한다.

| 회계 개념 | Git 대응 | 예시 |
|-----------|----------|------|
| 전표 (Journal Entry) | 커밋 | `feat: 새 기능 구현` |
| 원장 (General Ledger) | `git log --reverse` | 레포 전체 거래 이력 |
| 계정과목 (Account) | 디렉토리 | `tools/`, `scripts/`, `assets/` |
| 회계 인터페이스 | 크로스레포 동기화 | 명시적 스크립트/매니페스트 |
| 감사 추적 (Audit Trail) | Co-Authored-By | AI/Human 협업 기록 |

### 세로축: 제조 공정 (FAB 로직)

레포는 반도체 팹이다. 원자재(아이디어)가 들어와서 완제품(콘텐츠)이 나간다.

| 제조 개념 | 레포 대응 | 예시 |
|-----------|----------|------|
| BOM (자재 명세) | 의존성 + 에셋 목록 | `pubspec.yaml`, `package.json`, `assets/` |
| 라우팅 (공정 순서) | 파이프라인 스크립트 | 빌드→테스트→배포 순차 실행 |
| WIP (재공품) | 브랜치 + Queue | `claude/*` 브랜치, `_queue/` |
| 수율 (Yield) | 빌드 성공률 | CI 통과율, 테스트 커버리지 |
| MES (제조실행) | 자동화 스크립트 | 동기화, 추출, 배포 도구 |
| 검수 (QC) | 테스트 + 리뷰 | `tests/`, 체크리스트 |

### 4대 원칙

1. **삭제는 없다, 반대 분개만 있다** — `git revert`로 정정. `reset --hard` 금지.
2. **증빙 없는 거래는 없다** — 커밋 메시지에 이유와 맥락. 크로스레포 이동은 명시적 스크립트로.
3. **BOM 확인 후 착공한다** — 의존성/에셋 명세 먼저, 공정 순서 명시 후 실행.
4. **재공품을 방치하지 않는다** — WIP 브랜치와 큐는 정기적으로 소화한다.

### 교차점: JSON 매니페스트

가로축과 세로축이 만나는 곳에 JSON이 있다. 매니페스트는 공정 기록이자 거래 증빙이다.

```
app-meta.json      = 제품 사양서
state.json         = 공정 현황판
*.youtube.json     = 출하 전표
*-SOURCES.md       = 원자재 입고 대장
```

### Claude 자동 체크

| 트리거 | 체크 | 위반 시 |
|--------|------|---------|
| `git commit` 전 | 커밋 메시지에 이유/맥락 있는가 | "증빙 누락" 경고 |
| `reset --hard` 요청 | 반대 분개(revert) 가능한가 | 차단, revert 제안 |
| 새 파일/도구 추가 | BOM(package.json 등) 업데이트했는가 | "BOM 미갱신" 경고 |
| 세션 시작 | `git branch --no-merged main` WIP 확인 | 3개 이상이면 정리 권고 |
| 크로스레포 작업 | 동기화 스크립트/매니페스트 경유하는가 | "인터페이스 우회" 경고 |

> **코드를 짜는 게 아니라 공장을 돌리고 있다.**
> **다만 그 공장의 원장이 git이고, 라인이 파이프라인일 뿐이다.**

---


## Project Overview
개인용 Android 앱 모음 프로젝트. Vercel에 스토어 페이지가 배포되어 있음.
- Store URL: https://dtslib-apk-lab.vercel.app/

## Brand Guidelines
모든 앱은 **Parksy** 브랜드를 사용:
- Parksy Capture (capture-pipeline)
- Parksy Pen (laser-pen-overlay)
- Parksy AIVA (aiva-trimmer)
- Parksy TTS (tts-factory)
- **Parksy ChronoCall (chrono-call)** ← NEW

## Project Structure
```
apps/
├── capture-pipeline/    # 공유 텍스트 캡처 앱
├── laser-pen-overlay/   # S Pen 오버레이 앱
├── aiva-trimmer/        # 오디오 트리밍 앱
├── tts-factory/         # TTS 변환 앱
└── chrono-call/         # 통화 녹음 STT 변환 앱 ← NEW

dashboard/
├── apps.json            # 스토어 표시용 앱 목록
└── index.html           # 스토어 페이지
```

## Version Management
버전은 항상 `pubspec.yaml`이 source of truth:
- `pubspec.yaml` → 실제 앱 버전 (예: 2.0.0+1)
- `app-meta.json` → 메타데이터 (예: v2.0.0)
- `dashboard/apps.json` → 스토어 표시 (예: v2.0.0)

## Key Files to Sync
앱 정보 변경 시 동기화 필요한 파일들:

| 파일 | 역할 |
|------|------|
| `apps/{app}/pubspec.yaml` | Flutter 앱 버전 (source of truth) |
| `apps/{app}/app-meta.json` | 앱 메타데이터 (이름, 버전, 설명) |
| `dashboard/apps.json` | 스토어 페이지 표시 정보 |
| `apps/{app}/android/.../AndroidManifest.xml` | Android 앱 라벨 (아이콘 이름) |
| `apps/{app}/android/.../strings.xml` | Android 문자열 리소스 |

## Available Commands
- `/sync-store` - pubspec.yaml 기준으로 스토어 메타데이터 동기화

---

# Parksy ChronoCall - 개발 핸드오프 매뉴얼

> **이 섹션은 터묵스 Claude가 ChronoCall 개발을 이어받기 위한 완전한 가이드다.**
> 코드는 100% 완성되어 있다. 아래는 빌드/테스트/배포/이후 Phase 로드맵이다.

## 1. 현재 상태 요약

| 항목 | 값 |
|------|-----|
| 앱 이름 | Parksy ChronoCall |
| 패키지명 | com.parksy.chronocall |
| 버전 | 1.0.0+1 |
| 브랜치 | claude/voice-content-pipeline-epaN1 |
| 다트 파일 | 9개, 2,161줄 |
| Kotlin 파일 | 1개, 145줄 |
| 빌드 상태 | **코드 완성, flutter create + pub get 필요** |

## 2. 전체 파일 구조 & 역할

```
apps/chrono-call/
├── pubspec.yaml                          # Flutter 의존성 (9개 runtime)
├── app-meta.json                         # 스토어 메타데이터
├── analysis_options.yaml                 # 린터 설정
│
├── lib/
│   ├── main.dart                         # (259줄) 앱 진입점
│   │   ├── ChronoCallApp                 #   MaterialApp (다크 테마)
│   │   ├── PermissionGate                #   권한 게이트 (audio/storage/manage)
│   │   └── IntentChannel                 #   Platform Channel 헬퍼
│   │
│   ├── core/
│   │   └── constants.dart                # (29줄) 상수
│   │       └── AppConstants              #   11개 static 필드
│   │
│   ├── models/
│   │   └── transcript.dart               # (143줄) 데이터 모델
│   │       ├── TranscriptSegment         #   start, end, text, speaker?
│   │       └── Transcript                #   8필드, toMarkdown(), toShareText()
│   │
│   ├── services/
│   │   ├── audio_preprocessor.dart       # (104줄) FFmpeg 전처리
│   │   │   ├── AudioPreprocessor         #   preprocess(), getDuration(), cleanup()
│   │   │   └── PreprocessResult          #   success, paths, sizes, compressionRatio
│   │   │
│   │   ├── whisper_service.dart          # (141줄) OpenAI Whisper API
│   │   │   ├── WhisperService            #   transcribe(filePath, language, onProgress)
│   │   │   └── WhisperResult             #   text, segments[], language, duration
│   │   │
│   │   └── storage_service.dart          # (84줄) SharedPreferences + 파일 내보내기
│   │       └── StorageService            #   getApiKey, getHistory, exportMarkdown
│   │
│   └── screens/
│       ├── home_screen.dart              # (748줄) 메인 화면 ★ 가장 큰 파일
│       │   └── HomeScreen                #   삼성 녹음폴더 탐지, 파일 선택, STT 파이프라인
│       │
│       ├── transcript_screen.dart        # (437줄) 결과 화면
│       │   └── TranscriptScreen          #   just_audio 재생, 세그먼트 seek, 마크다운 내보내기
│       │
│       └── settings_screen.dart          # (216줄) 설정 화면
│           └── SettingsScreen            #   API 키 관리, auto-share 토글
│
└── android/
    ├── build.gradle                      # Gradle 설정 (AGP 7.3.0)
    ├── settings.gradle                   # Flutter Gradle Plugin
    ├── gradle.properties                 # AndroidX + Jetifier
    │
    └── app/
        ├── build.gradle                  # compileSdk 34, minSdk 26, targetSdk 34
        └── src/main/
            ├── AndroidManifest.xml       # 권한 6개, intent-filter (audio/* 공유 수신)
            └── kotlin/.../MainActivity.kt # (145줄) content:// URI 복사, Platform Channel
```

## 3. 의존성 목록

```yaml
# pubspec.yaml 의존성
file_picker: ^8.0.0              # 파일 선택 UI
just_audio: ^0.9.36              # 오디오 재생 (TranscriptScreen)
ffmpeg_kit_flutter_audio: ^6.0.3 # 오디오 전처리 (mono 16kHz 64kbps)
path_provider: ^2.1.1            # 앱 디렉토리 접근
share_plus: ^10.0.0              # 공유 인텐트 (→ Parksy Capture)
dio: ^5.4.0                      # HTTP 클라이언트 (Whisper API)
shared_preferences: ^2.2.2       # 로컬 저장소
intl: ^0.19.0                    # 날짜 포맷
permission_handler: ^11.3.0      # 런타임 권한
```

## 4. Android 설정 상세

```
compileSdk: 34
minSdk: 26 (Android 8.0 Oreo)
targetSdk: 34 (Android 14)
NDK: 25.1.8937393
Java: 1.8
```

### 매니페스트 권한
```xml
INTERNET                              # Whisper API 호출
READ_EXTERNAL_STORAGE (max SDK 32)    # Android 12 이하
WRITE_EXTERNAL_STORAGE (max SDK 28)   # Android 9 이하
MANAGE_EXTERNAL_STORAGE               # 전체 저장소 접근 (최후 수단)
READ_MEDIA_AUDIO                      # Android 13+
POST_NOTIFICATIONS                    # 알림 (향후)
```

### Intent Filter
```xml
<!-- 다른 앱에서 오디오 공유받기 -->
<action android:name="android.intent.action.SEND" />
<data android:mimeType="audio/*" />
```

## 5. 핵심 워크플로우 상세

### 5.1 STT 파이프라인 (home_screen.dart → _transcribeFile)
```
Step 1: 파일 존재 확인
Step 2: FFmpeg getDuration() → Duration 표시
Step 3: FFmpeg preprocess() → mono 16kHz 64kbps m4a
         - 입력: 삼성 기본 녹음 (stereo, 44.1kHz, ~5MB/분)
         - 출력: Whisper 최적화 (mono, 16kHz, 64kbps, ~0.5MB/분)
Step 4: 파일 사이즈 체크 (≤25MB = Whisper 제한)
Step 5: Whisper API 호출 (verbose_json + segment timestamps)
         - onProgress 콜백으로 업로드 진행률 표시
Step 6: Transcript 객체 생성 + SharedPreferences 저장
Step 7: auto-share 켜져있으면 → Share.share() → Parksy Capture
Step 8: TranscriptScreen 으로 네비게이션
```

### 5.2 삼성 녹음 폴더 탐지 (home_screen.dart → _detectSamsungPath)
```
시도 순서:
1. /storage/emulated/0/Recordings/Call          ← One UI 4+
2. /storage/emulated/0/DCIM/.Recordings/Call    ← One UI 3
3. /storage/emulated/0/Call                     ← 일부 구형
4. /storage/emulated/0/Record/Call              ← 일부 통신사 커스텀

발견되면 → 상단 Samsung Call Recordings 바 표시
탭하면 → DraggableScrollableSheet (파일 목록, 최신순 정렬)
```

### 5.3 Share Intent 수신 (MainActivity.kt + main.dart)
```
다른 앱 → "공유" → ChronoCall 선택

Kotlin 측:
  processIncomingIntent() → content:// URI 수신
  → copyContentUriToLocal() → /cache/chrono_imports/filename 으로 복사
  → pendingAudioPath/pendingAudioName 에 저장

Dart 측:
  IntentChannel.getSharedAudio() → {"path": "/local/path", "name": "file.m4a"}
  → 확인 다이얼로그 → _transcribeFile()
```

### 5.4 Transcript 뷰어 (transcript_screen.dart)
```
상단: 메타 바 (duration, language, segment 수, 글자 수)
중단: just_audio 재생기 (play/pause, seek bar, mm:ss 표시)
하단: 세그먼트 목록 (타임스탬프 + 텍스트)
       - 탭하면 해당 위치로 seek
       - 현재 재생 중인 세그먼트 하이라이트 (AnimatedContainer)

액션:
  - Copy: 전문 클립보드 복사
  - Share: toShareText() → Parksy Capture
  - Export Markdown: /storage/emulated/0/Download/ChronoCall/date_filename.md
  - Copy with timestamps: [MM:SS] 텍스트 형식
```

## 6. 터묵스 빌드 가이드

### Phase 0: 초기 설정 (최초 1회)

```bash
# 1. 브랜치 체크아웃
cd ~/dtslib-apk-lab
git fetch origin claude/voice-content-pipeline-epaN1
git checkout claude/voice-content-pipeline-epaN1

# 2. Flutter 보일러플레이트 생성
cd apps/chrono-call
flutter create . --org com.parksy
# → android/app/src/main/res/mipmap-*/ic_launcher.png 등 자동 생성
# → test/widget_test.dart 자동 생성
# ⚠️ 기존 파일 (main.dart, build.gradle 등) 은 이미 있으므로 덮어쓰지 않음

# 3. 의존성 설치
flutter pub get

# 4. 빌드 확인
flutter build apk --debug
ls -lh build/app/outputs/flutter-apk/app-debug.apk
```

### 빌드 실패 시 체크리스트

| 에러 | 원인 | 해결 |
|------|------|------|
| `NDK not found` | NDK 미설치 | `sdkmanager "ndk;25.1.8937393"` |
| `Gradle build failed` | AGP 버전 불일치 | android/build.gradle 의 AGP 버전 확인 |
| `Namespace not specified` | Android Gradle 8+ | app/build.gradle에 `namespace` 이미 있음, AGP 7.3 쓰면 OK |
| `ffmpeg_kit not found` | pub get 안됨 | `flutter pub get` 재실행 |
| `minSdk 26 conflict` | 의존성 minSdk 충돌 | `flutter pub upgrade` |

### APK 설치 & 테스트

```bash
# 설치
termux-open build/app/outputs/flutter-apk/app-debug.apk

# 테스트 체크리스트:
# □ 앱 실행 → 권한 요청 화면
# □ 권한 허용 → 메인 화면 (Samsung 바 표시 여부)
# □ Settings → API 키 입력 → Save
# □ 파일 선택 → STT 파이프라인 동작
# □ 결과 화면 → 오디오 재생 + seek
# □ 세그먼트 탭 → 해당 위치로 이동
# □ Copy / Share / Export 동작
# □ 다른 앱에서 음성 파일 공유 → ChronoCall에서 수신
```

## 7. Phase 로드맵

### Phase 1 (v1.0.0) - ✅ 완료
```
[✅] 기본 STT 파이프라인 (FFmpeg 전처리 + Whisper API)
[✅] 삼성 녹음 폴더 자동 탐지 + 바로가기
[✅] 파일 선택기 (시스템 FilePicker)
[✅] 결과 뷰어 (타임스탬프 세그먼트 + 오디오 재생)
[✅] Share Intent 수신 (content:// → local file copy)
[✅] 히스토리 (SharedPreferences, 최근 100건)
[✅] Parksy Capture 연동 (auto-share 토글)
[✅] 마크다운 내보내기
```

### Phase 2 (v1.1.0) - 다음 목표
```
[ ] 배치 처리: 여러 파일 한꺼번에 선택 → 순차 STT
[ ] 검색: 히스토리 내 텍스트 검색
[ ] 날짜 필터: 기간별 히스토리 필터링
[ ] 파일 이름 파싱: 삼성 녹음파일명에서 전화번호/날짜 추출
     예: "Call recording 010-1234-5678 2026-02-17.m4a"
     → 전화번호를 transcript에 메타데이터로 저장
[ ] 언어 선택: Settings에서 STT 언어 변경 (ko/en/ja/zh)
[ ] 히스토리 정렬: 날짜순/이름순/길이순
```

### Phase 3 (v2.0.0) - 장기
```
[ ] Speaker Diarization: 화자 구분 (pyannote 또는 서버사이드)
     → TranscriptSegment.speaker 필드는 이미 준비됨
[ ] Whisper Large v3 로컬 추론 (on-device, Termux 내 whisper.cpp)
[ ] 요약 생성: OpenAI GPT로 통화 내용 요약
[ ] 연락처 연동: 전화번호 → 연락처 이름 매칭
[ ] GitHub 아카이브: Parksy Capture처럼 자동 GitHub push
```

## 8. 코드 수정 시 주의사항

### 임포트 그래프 (의존 방향)
```
main.dart
  └→ screens/home_screen.dart
       ├→ core/constants.dart
       ├→ models/transcript.dart
       ├→ services/audio_preprocessor.dart
       ├→ services/whisper_service.dart
       ├→ services/storage_service.dart
       ├→ screens/settings_screen.dart
       └→ screens/transcript_screen.dart
            └→ services/storage_service.dart

main.dart (IntentChannel) ←── home_screen.dart (import ../main.dart)
```

### 색상 팔레트 (다크 테마)
```dart
const kBackground   = Color(0xFF1A1A2E);  // 메인 배경
const kSurface      = Color(0xFF16213E);  // 카드, AppBar
const kAccent       = Color(0xFFE8D5B7);  // 골드 액센트 (텍스트, 아이콘, 버튼)
// 텍스트: Colors.white, Colors.white.withOpacity(0.5~0.85)
// 에러: Colors.red[700], Colors.redAccent
```

### Platform Channel 규약
```
Channel: "com.parksy.chronocall/intent"

Dart → Kotlin:
  getSharedAudio()     → Map{"path", "name"} | null
  copyUriToLocal(uri)  → Map{"path", "name"} | null
  getAudioMetadata(path) → Map{"exists", "sizeBytes", "sizeMB", "lastModified", "name"}
```

### 버전 올릴 때 동기화 파일
```
1. apps/chrono-call/pubspec.yaml          → version: X.Y.Z+N
2. apps/chrono-call/lib/core/constants.dart → version = 'X.Y.Z', versionCode = N
3. apps/chrono-call/app-meta.json         → "version": "vX.Y.Z"
4. dashboard/apps.json                     → chrono-call 항목의 version, lastUpdated
```

## 9. 알려진 제약사항

| 제약 | 상세 | 우회 방법 |
|------|------|-----------|
| Whisper 25MB 제한 | API 파일 크기 한도 | FFmpeg 전처리로 ~0.5MB/분 압축 → 50분 통화까지 OK |
| content:// URI | FFmpeg가 직접 못 읽음 | MainActivity에서 cache로 복사 후 전달 |
| SharedPreferences 한도 | 큰 JSON 저장 시 느림 | 100건 제한 적용됨, Phase 2에서 SQLite 고려 |
| Samsung 경로 하드코딩 | 기기별 다를 수 있음 | 4개 알려진 경로 시도 + fallback FilePicker |
| API 키 평문 저장 | SharedPreferences에 그냥 저장 | 개인용이라 OK, 필요시 flutter_secure_storage |