# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 App Catalog

| App | 설명 | 버전 | 다운로드 |
|-----|------|------|----------|
| [laser-pen-overlay](./apps/laser-pen-overlay/) | S Pen 웹 오버레이 판서 | **v2.1.0** | [![Download](https://img.shields.io/badge/APK-Download-green)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip) |
| [aiva-trimmer](./apps/aiva-trimmer/) | AIVA 음악 2분 트리밍 | v1.0.1 | [![Download](https://img.shields.io/badge/APK-Download-blue)](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-aiva-trimmer/main/aiva-trimmer-debug.zip) |

### 🆕 최신 업데이트

**Laser Pen v2.1.0** (2025-12-13)
- ✅ Quick Settings 타일 추가
- ✅ 알림 액션 버튼 (Toggle/Clear/Stop)
- ✅ 시스템 오버레이 (다른 앱 위 판서)
- ✅ S Pen/손가락 입력 분리

---

## 📥 빠른 설치

**Laser Pen (로그인 불필요):**
```
https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip
```

1. 링크 클릭 → ZIP 다운로드
2. 압축 해제 → `app-debug.apk`
3. Galaxy 기기에서 설치

---

## 🏗️ 구조

```
dtslib-apk-lab/
├── CONSTITUTION.md          # 개발 헌법 (필독)
├── README.md                 # 이 파일
├── docs/                     # 기술 문서
│   └── SPen_Overlay_Whitepaper.md
├── .github/workflows/        # CI/CD
│   ├── build-aiva-trimmer.yml
│   └── build-laser-pen.yml
└── apps/
    ├── aiva-trimmer/         # 오디오 트리머
    └── laser-pen-overlay/    # S Pen 판서 (v2.1: 오버레이+타일)
```

---

## ⚖️ 헌법

모든 개발은 [CONSTITUTION.md](./CONSTITUTION.md)를 준수합니다.

- Debug APK only
- GitHub Actions 빌드
- 개인 Galaxy 기기만 테스트
- 로그인/클라우드/분석 없음

---

## 📚 문서

- [S Pen Overlay 기술백서](./docs/SPen_Overlay_Whitepaper.md)

---

*© 2025 Parksy (dtslib.com)*
