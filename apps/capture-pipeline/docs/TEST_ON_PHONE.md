# Parksy Capture - 폰 테스트 체크리스트

## 사전 준비

1. APK 설치
   - GitHub Actions → Artifacts에서 `ParksyCapture-debug.apk` 다운로드
   - 또는 `ParksyCapture-release.apk` (서명된 릴리스)
   - "알 수 없는 앱 설치" 허용 후 설치

2. 디버깅 준비 (선택)
   ```bash
   adb logcat -s ParksyCapture:*
   ```

---

## 테스트 케이스

### 1. 런처 실행 테스트

| 단계 | 예상 결과 |
|------|----------|
| 앱 서랍에서 "Parksy Capture" 탭 | 도움말 화면 표시 |
| "How to use" 안내 확인 | 4단계 사용법 표시 |
| "Open Downloads" 버튼 탭 | 파일 관리자 열림 |
| "Test Share" 버튼 탭 | Share Sheet 표시 |

---

### 2. Chrome/Edge 브라우저 테스트

| 단계 | 예상 결과 |
|------|----------|
| 웹페이지에서 텍스트 드래그 선택 | 선택 핸들 표시 |
| "공유" 또는 ⋮ → "공유" 탭 | Share Sheet 표시 |
| "Parksy Capture" 선택 | 처리 시작 |
| Toast 메시지 확인 | "Saved Local Only ✅" 또는 "Saved Local & Cloud 🚀" |
| Downloads/parksy-logs 확인 | `ParksyLog_YYYYMMDD_HHmmss.md` 파일 생성 |

**⚠️ 주의**:
- "페이지 공유" 또는 "링크 공유"가 아닌 **텍스트 선택 후 공유**를 해야 함
- URL만 공유하면 "No text received" 발생

---

### 3. Samsung Notes 테스트

| 단계 | 예상 결과 |
|------|----------|
| 노트에서 텍스트 드래그 선택 | 선택 영역 표시 |
| "공유" 버튼 탭 | Share Sheet 표시 |
| "Parksy Capture" 선택 | 처리 시작 |
| Toast 메시지 확인 | "Saved Local Only ✅" |

---

### 4. Whale/네이버 앱 테스트

| 단계 | 예상 결과 |
|------|----------|
| 텍스트 선택 후 공유 | Share Sheet 표시 |
| "Parksy Capture" 선택 | 정상 저장 |

---

## 실패 시 확인 사항

### "No text received" 메시지가 뜰 때

1. **공유 방식 확인**
   - ❌ 페이지 링크 공유 (URL만 전송됨)
   - ❌ 이미지 공유
   - ✅ 텍스트 선택 후 공유

2. **Logcat 확인**
   ```bash
   adb logcat -s ParksyCapture:*
   ```
   출력 예시:
   ```
   D/ParksyCapture: action: android.intent.action.SEND
   D/ParksyCapture: type: text/plain
   D/ParksyCapture: EXTRA_TEXT: null  ← 문제!
   ```

3. **앱별 공유 동작 차이**
   - 일부 앱은 텍스트를 `EXTRA_TEXT`가 아닌 `clipData`로 전송
   - 일부 앱은 HTML로 전송 (`text/html`)

---

### 파일이 저장되지 않을 때

1. **저장 권한 확인**
   - Android 10+: 권한 불필요 (MediaStore API 사용)
   - Android 9 이하: 저장소 권한 필요

2. **Logcat 확인**
   ```
   E/ParksyCapture: Local save exception
   ```

---

### Share Sheet에 "Parksy Capture"가 안 보일 때

1. **앱 재설치**
   - 기존 앱 삭제 후 재설치

2. **기본 앱 설정 초기화**
   - 설정 → 앱 → 기본 앱 → 초기화

3. **Share Sheet 캐시 문제**
   - 기기 재부팅

---

## 예상 결과 요약

| 테스트 | 성공 기준 |
|--------|----------|
| 런처 실행 | 도움말 화면 표시 |
| Chrome 텍스트 공유 | Toast + 파일 저장 |
| Samsung Notes 공유 | Toast + 파일 저장 |
| 긴 텍스트 (10KB+) | 잘림 없이 전체 저장 |

---

## 저장 파일 확인

```
📂 Downloads/
└── 📂 parksy-logs/
    └── 📄 ParksyLog_20250117_143052.md
```

파일 내용 예시:
```markdown
---
date: 2025-01-17 14:30:52
source: android-share
chars: 1523
---

[캡처된 텍스트 내용]
```

---

## 버전 정보

- **App Version**: 2.0.0
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
