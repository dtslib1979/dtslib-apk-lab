# MiniMidi v2.2.0 설치 & 임상 테스트 가이드

> CONSTITUTION.md 준수: Personal use only, Debug APK only

## 0. 목표

Stage 2C(MIDI Audit Player)까지 포함된 v2.2.0 debug APK를:
1. GitHub Actions로 빌드
2. 폰에 설치
3. "임상 4종 테스트" 수행
4. 결과 로그 기록

---

## 1. APK 빌드

### 1.1 워크플로우 실행 방법

**방법 A: workflow_dispatch (수동 실행)**
1. [Actions 탭](../../../actions) 이동
2. `Build MiniMidi` 워크플로우 선택
3. "Run workflow" 버튼 클릭
4. Branch: `main` (또는 현재 feature 브랜치)
5. "Run workflow" 실행

**방법 B: main 브랜치 푸시 (자동 실행)**
```bash
git checkout main
git merge claude/review-aiva-trimmer-mi0If
git push origin main
```

### 1.2 빌드 완료 확인

- Actions 탭에서 녹색 체크 확인
- Artifacts: `minimidi-debug` 다운로드

---

## 2. APK 설치

### 2.1 다운로드 & 설치

```bash
# 1. Artifact zip 해제
unzip minimidi-debug.zip

# 2. 폰으로 전송 (USB 연결 시)
adb push app-debug.apk /sdcard/Download/

# 3. 기존 앱 제거 (서명 충돌 방지)
adb uninstall com.dtslib.minimidi

# 4. 설치
adb install app-debug.apk
```

### 2.2 대안: 파일 관리자로 설치

1. `app-debug.apk`를 폰으로 전송
2. 파일 관리자 앱에서 APK 탭
3. "설치" 버튼 (알 수 없는 소스 허용 필요)

---

## 3. 임상 4종 테스트

### 3.1 공통 루틴

모든 테스트에서 동일하게 수행:

1. **오디오 선택** - Pick Audio 버튼
2. **IN/OUT 마킹** - 2분 구간 설정 (프리셋 120s)
3. **Export MIDI** - 2A/2B 둘 다 생성됨
4. **Audit Player 확인**:
   - [2A] 버튼 → 10초 재생
   - [2B] 버튼 → 10초 재생
   - Loop ON → 반복 재생 확인
   - Progress bar 동작 확인

### 3.2 테스트 세트

| ID | 유형 | 설명 |
|----|------|------|
| A | 클래식 솔로 | 피아노 또는 바이올린 독주 |
| B | 성악/합창 | 피치 흔들림이 있는 보컬 |
| C | 오케스트라 | 멜로디가 묻히는 앙상블 |
| D | 유튜브 압축 | 리버브 심한 저품질 음원 |

---

## 4. 결과 기록

### 4.1 기록 포맷 (각 테스트마다)

```
[Test A: 클래식 솔로]
Melody: OK / NO
Noise notes: High / Medium / Low
Octave: High / Normal / Low
Better: 2A / 2B / Same
```

### 4.2 기록 위치

`apps/minimidi/DEV_LOG.md`에 append:

```markdown
## v2.2.0 임상 테스트 결과 (YYYY-MM-DD)

### Test A: 클래식 솔로
- Melody: OK
- Noise notes: Low
- Octave: Normal
- Better: 2B

### Test B: 성악/합창
- Melody: OK
- Noise notes: Medium
- Octave: Normal
- Better: 2B

...
```

---

## 5. 실패 시 대응

### 5.1 크래시 발생 시

```bash
# 로그 수집
adb logcat -d | grep -i minimidi > crash_log.txt
```

### 5.2 GitHub Issue 생성

Title: `[MiniMidi v2.2.0] <증상 요약>`

Body:
```
## 재현 절차
1. ...
2. ...

## 환경
- 기기: Galaxy S23
- Android: 14
- 파일 포맷: mp3

## 에러 메시지
<스택트레이스>
```

---

## 6. 다음 단계 제안

임상 완료 후 다음 중 하나 선택:

### Option A: Stage 2D - 프리셋 3종

| 프리셋 | 설명 |
|--------|------|
| CLEAN | 노이즈 억제 강 |
| BALANCED | 기본 (현재) |
| AGGRESSIVE | 멜로디 우선, 노이즈 허용 |

### Option B: Piano 사운드 개선

현재 sine wave → soundfont 기반으로 업그레이드
(검사용은 OK지만 듣기 거슬리면)

---

## Quick Links

- [Build MiniMidi Workflow](../../../actions/workflows/build-minimidi.yml)
- [nightly.link 다운로드](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-minimidi/main/minimidi-debug.zip)
