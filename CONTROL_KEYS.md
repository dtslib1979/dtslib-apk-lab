# CONTROL_KEYS — DTS APK Lab

> Claude가 매 세션 읽는 운전 설명서. 헤매지 마라.

---

## 0. 자동화 엔드포인트 선언

> 이 레포의 자동화 범위: **코드 → 빌드 → 릴리즈 → 설치 → QA 결과 생성**까지.
> 플랫폼 GUI 자동화(Tasker/Shizuku/Termux API)는 스코프 밖. 수동 + 체크리스트만.

이 선 밖으로 논의가 가면 **"스코프 밖"** 한 마디로 끊는다.

---

## 0-1. 작업 프로토콜: 3-Check → 2-Spot → 1-Commit

매 작업 이 순서로만 진행한다. 예외 없음.

### 3-Check (코드 손대기 전)

1. **패키지 공식 API 확인** — 해당 기능이 이미 있는지 문서/README/예제 체크
2. **DEVLOG 검색** — `grep "증상키워드" DEVLOG.md` → 같은 문제 전례 있는지
3. **수정 후보 2개 찍기** — 파일 + 함수/위젯/핸들러 특정 후 시작

이 3단계 없이 코드 건드리면 삽질 확정.

### 2-Spot (수정은 두 군데만)

- **"원인" 1곳** — 로직/데이터 버그가 있는 파일
- **"표시/UX" 1곳** — UI 반영이 필요한 파일
- 오버레이는 여기저기 건드리면 무조건 터진다. 2파일/2함수 넘기면 멈추고 재판단.

### 1-Commit (한 증상 = 한 커밋)

- 한 버그 수정 = 한 커밋. 섞지 마라.
- 커밋 후 DEVLOG 한 줄 업데이트.

### 추가 고정 룰

- 모듈 추출은 **3번째 앱부터**. Axis 1개로 "공통 모듈 5종" 선언 금지.
- GUI 자동화(Tasker/Shizuku 등)는 **계정 밴 리스크로 100% 금지**. GUI 보조만 허용.

---

## 0-2. DEVLOG 1포맷 원칙

DEVLOG.md는 **4칸 테이블 하나만** 사용:

```
| Date | Event | Symptom | Cause | Fix |
```

- 세션 요약, 토론, Goal/Change/Result 같은 별도 포맷 금지
- 맥락이 필요하면 커밋 로그 참조
- "오늘 한 줄" 요약은 테이블 위에 1줄만 허용
- 200줄 넘기 전까지 파일 분리 금지

---

## 1. 앱 목록 + 패키지 ID

| 앱 | 디렉토리 | applicationId | 오버레이 | 릴리즈 태그 |
|----|----------|---------------|----------|------------|
| Parksy Axis | `apps/parksy-axis/` | `kr.parksy.axis` | Yes | `parksy-axis-latest` |
| Parksy Pen | `apps/laser-pen-overlay/` | `com.dtslib.laser_pen_overlay` | Yes | `parksy-pen-latest` |
| Parksy Capture | `apps/capture-pipeline/` | `com.parksy.capture` | No | `parksy-capture-latest` |
| Parksy AIVA | `apps/aiva-trimmer/` | `com.dtslib.aiva_trimmer` | No | — |
| Parksy TTS | `apps/tts-factory/` | `com.parksy.ttsfactory` | No | `v1.0.2` |
| Parksy Glot | `apps/parksy-glot/` | `com.dtslib.parksy_glot` | Yes | — |
| Parksy Audio Tools | `apps/parksy-audio-tools/` | `kr.parksy.audio_tools` | Yes | — |
| MIDI Converter | `apps/midi-converter/` | — | No | — |

---

## 2. 버전 범프 — 6파일 고정

앱 버전 올릴 때 반드시 이 6개 전부 수정:

```
apps/{app}/lib/core/constants.dart    → version + versionCode
apps/{app}/pubspec.yaml               → version: X.Y.Z+N
apps/{app}/app-meta.json              → "version": "vX.Y.Z"
apps/{app}/README.md                  → 제목 버전
apps/{app}/lib/screens/home.dart      → 파일 상단 주석 (있으면)
dashboard/apps.json                   → version + lastUpdated
```

**빠뜨리면 불일치. 6개 한 번에 수정, 한 커밋.**

---

## 3. 오버레이 엔트리포인트

오버레이 앱은 별도 Flutter 엔진에서 실행된다.

```dart
// main.dart
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}
```

### 절대 규칙
- 오버레이 → 메인 앱 설정 동기화 = **`shareData()` IPC만 신뢰**
- File I/O, SharedPreferences = 별도 엔진에서 불안정. 보조용만.
- `overlayListener` 수신부는 **반드시 try-catch로 감싸라** (스트림 죽으면 끝)
- shareData 전송 = **최소 3회, 500ms 간격** (엔진 초기화 대기)

### 오버레이 권한
`AndroidManifest.xml`에 필요:
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

### 하드코딩 경로
오버레이 프로세스에서 `path_provider` 안 됨. 직접 경로 사용:
```
/data/data/{applicationId}/files/{config_file}.json
```

---

## 4. 빌드 + 릴리즈 + 설치

### 빌드 트리거
```
git push → GitHub Actions 자동 실행
워크플로우: .github/workflows/build-{app-name}.yml
```

### 빌드 상태 확인
```bash
gh run list --workflow=build-parksy-axis.yml --limit=1 --json status,conclusion
```

### APK 다운로드
```bash
gh release download parksy-axis-latest --pattern "app-debug.apk" --output ~/storage/downloads/{name}.apk --clobber
```

### 다운로드 검증
```bash
ls -lh ~/storage/downloads/{name}.apk
# 85MB 전후여야 정상. 11MB 등이면 불완전 → rm 후 재다운
```

### 설치
```bash
termux-open ~/storage/downloads/{name}.apk
```

---

## 5. 스토어 배포

### Vercel 스토어
- URL: https://dtslib-apk-lab.vercel.app/
- 데이터: `dashboard/apps.json` (push 시 자동 배포)
- 다운로드 링크: GitHub Release 직접 URL

### apps.json 구조
```json
{
  "id": "parksy-axis",
  "name": "Parksy Axis",
  "version": "v11.0.0",
  "downloadUrl": "https://github.com/dtslib1979/dtslib-apk-lab/releases/download/parksy-axis-latest/app-debug.apk",
  "lastUpdated": "2026-02-10"
}
```

---

## 6. 금지 리스트

| 하지 마라 | 이유 |
|-----------|------|
| `path_provider` 오버레이에서 사용 | platform channel 안 됨 |
| SharedPreferences만으로 오버레이 동기화 | 별도 엔진이라 불안정 |
| `overlayListener` try-catch 밖에 코드 | RangeError 하나로 스트림 사망 |
| 버전 범프 파일 1~2개만 수정 | 6개 전부 아니면 하지 마라 |
| APK 사이즈 확인 안 하고 설치 | 불완전 다운로드 = 설치 실패 |
| FIXES/ 폴더 분리 (200줄 미만) | DEVLOG.md에 통합 |
| 스크린샷 강제 첨부 | 텍스트 1줄이면 재현 가능 |

---

## 7. Termux 환경 제약

| 제약 | 우회 |
|------|------|
| `/tmp/` EACCES | `gh` CLI 직접 사용, sleep+check 패턴 |
| 에뮬레이터 없음 | 디바이스 직접 테스트 + DEVLOG 기록 |
| PC 없음 | Termux + Claude Code 전부 처리 |
| 긴 명령 타임아웃 | 10초 sleep + 상태 체크 반복 |

---

## 8. 커밋 메시지 규칙

```
fix:   버그 수정
feat:  새 기능
bump:  버전 범프
chore: 설정/문서/인프라
docs:  문서 추가/수정
```

---

## 9. 이 레포의 목적

- Google Play 배포 ❌
- 에뮬레이터 테스트 ❌
- **내가 쓰는 디바이스 오버레이 생산 도구** ✅
- 방송 키트 확장 가능 ✅
- 6개+ 앱을 같은 패턴으로 반복 생산 ✅

### Overlay Direction Declaration

> All APKs are personal **Overlay Productivity Tools**.
> No Play Store distribution.
> Modules are not fixed in advance.
> Reusable patterns are extracted only after **2~3 overlay apps confirm common structure**.

헌법은 지금 쓴다. 법 조항은 판례가 쌓이면 쓴다.
