# dtslib-apk-lab

> **Personal use only. No distribution.**

Parksy의 개인용 Android APK 모노레포.

---

## 📱 App Catalog

| App | 설명 | 상태 |
|-----|------|------|
| [aiva-trimmer](./apps/aiva-trimmer/) | AIVA 음악 2분 트리밍 | 🟡 개발중 |
| [laser-pen-overlay](./apps/laser-pen-overlay/) | S Pen 웹 오버레이 판서 | 🟢 신규 |

---

## 🏗️ 구조

```
dtslib-apk-lab/
├── CONSTITUTION.md          # 개발 헌법 (필독)
├── README.md                 # 이 파일
├── .github/workflows/        # CI/CD
└── apps/
    ├── aiva-trimmer/         # 오디오 트리머
    └── laser-pen-overlay/    # S Pen 판서
```

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

*© 2025 Parksy (dtslib.com)*
