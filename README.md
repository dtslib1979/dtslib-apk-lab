# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 APK 다운로드

### 👉 [APK Store](https://dtslib-apk-lab.vercel.app) 👈

지인 배포용 스토어. 버전은 pubspec.yaml에서 자동 동기화됨.

---

## 🏗️ 구조

```
dtslib-apk-lab/
├── CONSTITUTION.md              # 개발 헌법 (필독)
├── README.md
├── scripts/
│   └── build_store_index.py     # pubspec → apps.json 자동 생성
├── .github/workflows/
│   ├── build-laser-pen.yml
│   ├── build-capture-pipeline.yml
│   ├── build-aiva-trimmer.yml
│   └── publish-store-index.yml  # 스토어 자동 동기화
├── apps/
│   ├── laser-pen-overlay/       # S Pen 판서 오버레이
│   ├── capture-pipeline/        # 텍스트 캡처 → GitHub
│   └── aiva-trimmer/            # 오디오 트리머
└── dashboard/                   # Vercel 배포 스토어
    └── apps.json                # 자동 생성 (수동 편집 금지)
```

---

## 🔄 버전 관리 (SSOT)

**Single Source of Truth = `apps/*/pubspec.yaml`**

버전 올리고 커밋하면:
1. GitHub Actions가 APK 빌드
2. `publish-store-index.yml`이 `dashboard/apps.json` 자동 갱신
3. Vercel이 자동 배포
4. 스토어에 최신 버전 반영

### 커밋 메시지 규칙
```
release(앱이름): x.y.z+build
```

예: `release(capture-pipeline): 5.1.0+12`

---

## ⚖️ 헌법

모든 개발은 [CONSTITUTION.md](./CONSTITUTION.md)를 준수합니다.

- Debug APK only
- GitHub Actions 빌드
- 개인 Galaxy 기기만 테스트
- 로그인/클라우드/분석 없음

---

## 🔗 관련 저장소

| Repo | 용도 |
|------|------|
| [parksy-logs](https://github.com/dtslib1979/parksy-logs) | Capture Pipeline 아카이브 (Private) |

---

*© 2025 Parksy (dtslib.com)*
