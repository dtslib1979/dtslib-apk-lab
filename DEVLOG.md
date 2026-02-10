# DEVLOG — DTS APK Lab

> 삽질 → DB 레코드. 같은 실수 두 번 안 한다.

## 형식

```
YYYY-MM-DD | Event | Symptom | Cause | Fix
```

---

## 2026-02-10 — 세션 2 (11커밋: Action 7 + PHL 4)

Parksy Axis v11.0.0 최종 릴리즈 + DEVLOG/CONTROL_KEYS 인프라 구축

| Date | Event | Symptom | Cause | Fix |
|------|-------|---------|-------|-----|
| 02-10 | bugfix | 오버레이 항상 디폴트 설정으로 뜸 | 오버레이 = 별도 Flutter 엔진, File I/O + SharedPreferences 못 읽음 | `FlutterOverlayWindow.shareData()` IPC로 설정 직접 전송 |
| 02-10 | bugfix | shareData 보냈는데 오버레이에서 수신 안 됨 | `_listenForData()`에서 `substring(0,80)` try-catch 밖 → RangeError → 스트림 리스너 사망 | 전부 try-catch 안으로, substring 제거 |
| 02-10 | bugfix | shareData 1회 전송 시 누락 | 오버레이 엔진 초기화 전에 데이터 도착하면 무시됨 | 500ms 간격 3회 재시도 |
| 02-10 | bugfix | DropdownButton assertion crash | `_selectedId`가 템플릿 목록에 없는 ID 참조 | `_validateSelectedId()` + widget `safeId` 폴백 |
| 02-10 | deploy | 버전 범프 시 누락 파일 | 6개 파일 동기화 필요한 걸 까먹음 | constants.dart, pubspec.yaml, app-meta.json, README.md, apps.json, home.dart 6파일 고정 |
| 02-10 | deploy | v11.0.0 최종 릴리즈 + Vercel 스토어 반영 | — | 6파일 범프 + apps.json lastUpdated + gh release 확인 |
| 02-10 | infra | wget/curl TMPDIR EACCES | Termux `/tmp/claude-XXXXX/` 접근 불가 | `gh release download` 사용, 완료 후 `ls -lh`로 85MB 검증 |
| 02-10 | infra | APK 다운로드 불완전 (11MB/85MB) | gh release download 중간 끊김 | rm 후 재다운 + 파일 사이즈 체크 |
| 02-10 | docs | 삽질 로그 체계 없음 | 커밋 로그만으론 증상/원인/레버 분리 안 됨 | DEVLOG.md 생성 (4칸 테이블 고정) |
| 02-10 | docs | Claude 매 세션 코드 탐색부터 시작 | 키 파일/규칙/커맨드 참조 문서 없음 | CONTROL_KEYS.md 생성 (9섹션) |
| 02-10 | docs | 사전조사 부족 + 토론 비대화 반복 | Before Touch Code 루틴 없음, DEVLOG 포맷 미통일 | 3-Check 루틴 + 1포맷 원칙 + 자동화 엔드포인트 선언 |
| 02-10 | docs | APK 방향성 미선언 | 오버레이 전용 전략이 문서화 안 됨 | Overlay Direction Declaration 추가 |

## 2026-02-09 (소급)

| Date | Event | Symptom | Cause | Fix |
|------|-------|---------|-------|-----|
| 02-09 | bugfix | 설정 저장 후 오버레이 반영 안 됨 | SharedPreferences 별도 프로세스 동기화 불가 | JSON 파일 직접 쓰기 (`/data/data/kr.parksy.axis/files/`) |
| 02-09 | build | GitHub Actions 404 (APK 다운 불가) | OverlayPosition 이름 충돌로 빌드 실패 | `hide OverlayPosition` import 처리 |

---

## Claude 구조적 결함 (리버스 엔지니어링 결과, 2026-02-10)

| 결함 | 구조적 원인 | 보정 장치 |
|------|-----------|----------|
| 기억 없음 | 매 세션 완전 리셋, 이전 삽질 기억 못 함 | DEVLOG + CONTROL_KEYS (외장 메모리) |
| 훈련 편향 | 빈도 높은 패턴(File I/O, SharedPrefs) 먼저 시도, 패키지 고유 API 후순위 | 3-Check #1: 패키지 공식 API 먼저 확인 |
| 실행 불가 | 런타임 없음, 코드를 돌려볼 수 없음, 런타임 에러 예측 못 함 | 사용자 디바이스 테스트 → 피드백 루프 |
| 덧붙이기 편향 | 근본 원인 분석 < 레이어 추가 (File→Prefs→IPC 3단계 돌아감) | 3-Check #3: 수정 후보 2개 = 원인 먼저 특정 |
| 압박 → 급함 | 사용자 화나면 사전조사 건너뛰고 바로 패치 → 또 틀림 루프 | Before Touch Code 브레이크 |

> 5개 전부 알고리즘 수준의 구조적 한계. 고칠 수 없다. 보정만 가능하다.
> DEVLOG/CONTROL_KEYS는 "있으면 좋은 것"이 아니라 **없으면 반드시 터지는 것**이다.

---

## 패턴 (반복되는 원인)

| 패턴 | 발생 횟수 | 레버 |
|------|----------|------|
| **오버레이 별도 엔진** | 3회 | shareData IPC가 유일한 정답. File/Prefs 믿지 마라 |
| **버전 범프 동기화** | 2회 | 6파일 고정 리스트. 하나라도 빠지면 불일치 |
| **Termux TMPDIR** | 매 세션 | gh CLI 직접 사용, /tmp 우회 |
| **APK 다운로드 검증** | 2회 | 85MB 안 되면 재다운. ls -lh 필수 |

---

## 오버레이 앱 보일러플레이트 체크리스트

새 오버레이 앱 만들 때 이거 확인:

- [ ] `@pragma('vm:entry-point')` 엔트리포인트 분리
- [ ] 설정 동기화 = `shareData()` IPC (File/Prefs 보조용만)
- [ ] `overlayListener` try-catch 필수 (스트림 죽으면 끝)
- [ ] shareData 재시도 (최소 3회, 500ms 간격)
- [ ] DropdownButton value 검증 (목록에 없는 ID → crash)
- [ ] 버전 범프 6파일 동기화
- [ ] build.gradle `applicationId` = 하드코딩 경로와 일치 확인
