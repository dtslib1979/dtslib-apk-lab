# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 App Catalog

| App | 설명 | 버전 | 상태 | 다운로드 |
|-----|------|------|------|----------|
| [laser-pen-overlay](./apps/laser-pen-overlay/) | S Pen 웹 오버레이 판서 | v2.0 | ✅ | [APK](https://github.com/dtslib1979/dtslib-apk-lab/actions/workflows/build-laser-pen.yml) |
| [capture-pipeline](./apps/capture-pipeline/) | Share Intent → Local + GitHub | v1.0 | ✅ | [APK](https://github.com/dtslib1979/dtslib-apk-lab/actions/workflows/build-capture-pipeline.yml) |
| [aiva-trimmer](./apps/aiva-trimmer/) | AIVA 음악 2분 트리밍 | v1.0 | ✅ | [APK](https://github.com/dtslib1979/dtslib-apk-lab/actions/workflows/build-aiva-trimmer.yml) |

### 🆕 최신 업데이트 (2025-12-14)

**Laser Pen v2.0**
- ✅ Quick Settings 타일 추가
- ✅ 알림 액션 버튼 (Toggle/Clear/Stop)
- ✅ 시스템 오버레이 (다른 앱 위 판서)
- ✅ S Pen/손가락 입력 분리 (`MotionEvent.TOOL_TYPE_STYLUS`)
- ✅ 3초 Fade-out 효과

**Capture Pipeline v1.0** (NEW)
- ✅ Android Share Intent 수신
- ✅ Local 저장 (MediaStore.Downloads)
- ✅ Cloud 저장 (Cloudflare Worker → GitHub)
- ✅ Dual-Write (Local 필수 + Cloud 선택)

---

## 📥 APK 다운로드

1. Actions 링크 클릭
2. 최신 빌드 선택
3. Artifacts에서 `*-debug` ZIP 다운로드
4. 압축 해제 → `app-debug.apk` 설치

---

## 🏗️ 구조

```
dtslib-apk-lab/
├── CONSTITUTION.md              # 개발 헌법 (필독)
├── README.md
├── .github/workflows/
│   ├── build-laser-pen.yml
│   ├── build-capture-pipeline.yml
│   └── build-aiva-trimmer.yml
└── apps/
    ├── laser-pen-overlay/       # S Pen 판서 오버레이
    │   ├── WHITEPAPER.md        # 기술백서
    │   └── ROADMAP.md
    ├── capture-pipeline/        # 텍스트 캡처 → GitHub
    │   └── worker/              # Cloudflare Worker
    └── aiva-trimmer/            # 오디오 트리머
```

---

## ⚖️ 헌법

모든 개발은 [CONSTITUTION.md](./CONSTITUTION.md)를 준수합니다.

- Debug APK only
- GitHub Actions 빌드
- 개인 Galaxy 기기만 테스트
- 로그인/클라우드/분석 없음

**Amendment (2025-12-14):**
- §1.1 수정: GitHub Archive 예외 허용 (개인 데이터 자산화 용도)

---

## 📚 문서

| 문서 | 설명 |
|------|------|
| [S Pen Whitepaper](./apps/laser-pen-overlay/WHITEPAPER.md) | 기술백서 v2.0 |
| [Capture Pipeline README](./apps/capture-pipeline/README.md) | 배포 가이드 |

---

## 🔗 관련 저장소

| Repo | 용도 |
|------|------|
| [parksy-logs](https://github.com/dtslib1979/parksy-logs) | Capture Pipeline 아카이브 (Private) |

---

*© 2025 Parksy (dtslib.com)*
