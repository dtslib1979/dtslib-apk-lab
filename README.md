# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 App Catalog

| App | 설명 | 버전 | APK |
|-----|------|------|-----|
| [aiva-trimmer](./apps/aiva-trimmer/) | AIVA 음악 2분 트리밍 | v1.0.1 | `aiva-trimmer-debug` |
| [laser-pen-overlay](./apps/laser-pen-overlay/) | S Pen 웹 오버레이 판서 | **v2.0.0** | `laser-pen-overlay-debug` |

### 🆕 최신 업데이트

**Laser Pen v2.0.0** (2025-12-13)
- 시스템 오버레이 기능 추가
- 다른 앱 위에서 S Pen 판서 가능
- 손가락은 하위 앱으로 pass-through

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
    └── laser-pen-overlay/    # S Pen 판서 (v2: 오버레이 지원)
```

> ⚠️ root의 `lib/`, `android/`, `pubspec.yaml`은 레거시 (무시)

---

## 📥 APK 설치 방법

1. [GitHub Actions](https://github.com/dtslib1979/dtslib-apk-lab/actions) 접속
2. 원하는 앱의 최신 성공 빌드 클릭 (✓ 녹색)
3. 하단 **Artifacts** → `[app-name]-debug` 다운로드
4. ZIP 해제 → `app-debug.apk`
5. Galaxy 기기로 전송
6. 설정 → 보안 → 출처를 알 수 없는 앱 허용
7. APK 설치

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
- [Laser Pen 로드맵](./apps/laser-pen-overlay/ROADMAP.md)

---

*© 2025 Parksy (dtslib.com)*
