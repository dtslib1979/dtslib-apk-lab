# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 APK 다운로드

### 👉 [APK Store](https://dtslib-apk-lab.vercel.app) 👈

지인 배포용 스토어. 버전은 pubspec.yaml에서 자동 동기화됨.

---

## 📖 운영 매뉴얼

### 🔄 버전 배포 (1분 컷)

```bash
# 1. pubspec.yaml 버전 수정
apps/capture-pipeline/pubspec.yaml
version: 5.1.0+12  # ← 여기만 수정

# 2. 커밋 & 푸시
git commit -m "release(capture-pipeline): 5.1.0+12"
git push

# 3. 자동 실행됨:
#    - APK 빌드 (build-*.yml)
#    - 스토어 동기화 (publish-store-index.yml)
#    - Vercel 배포
```

**끝. 스토어에 자동 반영됨.**

---

### 🛡️ 헌법 집행 모드 (Hybrid)

| Zone | 경로 | 위반 시 |
|------|------|--------|
| 🔴 HARD | `.github/`, `scripts/`, `dashboard/apps.json` | CI 실패, 머지 차단 |
| 🟡 SOFT | `apps/`, `dashboard/*` | 경고 + 인간 확인 |

**원칙:** *"개발은 자유롭게, 배포는 군사 통제."*

---

### 🚫 절대 금지 (§1.1)

```
❌ Login / Auth
❌ Firebase / Analytics
❌ Payments / Ads
❌ Multi-user
❌ Play Store 준비
```

---

### 📁 레포 구조

```
dtslib-apk-lab/
├── CONSTITUTION.md              # 개발 헌법 v1.3 (필독)
├── README.md                    # 이 문서
├── scripts/
│   ├── build_store_index.py     # pubspec → apps.json
│   └── constitution_guard.py    # 헌법 집행 스크립트
├── .github/
│   ├── workflows/
│   │   ├── build-*.yml          # APK 빌드
│   │   ├── publish-store-index.yml  # 스토어 동기화
│   │   └── constitution-guard.yml   # 헌법 검사
│   └── PULL_REQUEST_TEMPLATE.md
├── apps/
│   ├── laser-pen-overlay/       # S Pen 판서 오버레이
│   ├── capture-pipeline/        # 텍스트 캡처 → GitHub
│   └── aiva-trimmer/            # 오디오 트리머
└── dashboard/                   # Vercel 배포 스토어
    └── apps.json                # ⚠️ 자동 생성 (수동 편집 금지)
```

---

### 🔗 버전 관리 (SSOT)

**Single Source of Truth = `apps/*/pubspec.yaml`**

| 파일 | 역할 | 편집 |
|------|------|------|
| `pubspec.yaml` | 버전 원본 | ✅ 수동 |
| `apps.json` | 스토어 표시 | 🤖 자동 |
| `sw.js` | 캐시 버전 | 🤖 자동 |

---

### 🤖 AI 에이전트 규칙

**Claude Desktop (PC):**
- 수정 허용: `.github/`, `scripts/`, `dashboard/`, `docs/`
- 앱 코드는 원칙적으로 손대지 않음

**Claude Code (Termux/폰):**
- 수정 허용: `apps/**`
- 수정 금지: `.github/`, `scripts/`

---

### ⚖️ 헌법

모든 개발은 [CONSTITUTION.md](./CONSTITUTION.md) v1.3을 준수합니다.

---

### 🔗 관련 저장소

| Repo | 용도 |
|------|------|
| [parksy-logs](https://github.com/dtslib1979/parksy-logs) | Capture Pipeline 아카이브 (Private) |

---

*© 2025 Parksy (dtslib.com)*
