# 타겟팅 프로그램 — PC전용 × Android 공백 26개

> **방송 기획 핵심 데이터**
> "PC/SaaS에만 있고 Android에는 없는 소프트웨어 장르"
> 작성: 2026-03-27 | 박씨 × Claude Code 대화에서 도출

---

## 배경 — 왜 이 리스트가 중요한가

박씨 셋업: **폰(Termux) → mosh + Tailscale → WSL2 Claude Code**
입력: STT(음성) → Claude Code → 코드 생성 → 배포

이 구조로 "폰이 PC 생산성을 그대로 가져간다"는 게 증명됨.
그러면 Android에 없는 PC 장르들이 전부 **콘텐츠 타겟**이 된다.

매 에피소드 공식:
```
PC에만 있는 [장르] → 폰/태블릿 + 음성 + Claude Code로 구현 → 방송
```

---

## TIER 1 — 완전 공백 (Android에 실용 수준 앱 없음)

| # | 장르 | PC 대표 | Android에 없는 이유 |
|---|------|---------|-------------------|
| 1 | **DAW (디지털 오디오 워크스테이션)** | Ableton Live, FL Studio, REAPER | ASIO 드라이버 + VSTi 플러그인 생태계가 Android 오디오 API와 근본 비호환 |
| 2 | **전문 영상편집 (멀티트랙·타임라인)** | DaVinci Resolve, Premiere Pro | GPU 가속 렌더링 + 멀티트랙 비선형편집 API 부재 |
| 3 | **2D CAD (도면·설계)** | AutoCAD, DraftSight | 수만 개 벡터 오브젝트 + DWG/DXF 파일 생태계 / 터치로 정밀 도면 불가 |
| 4 | **3D CAD·파라메트릭 모델링** | SolidWorks, Fusion 360 | 파라메트릭 연산 + 물리 시뮬레이션이 모바일 GPU로 불가 |
| 5 | **3D 애니메이션·렌더링** | Blender, Maya, 3ds Max | 렌더 연산 / 수천 폴리곤 리깅·스키닝 워크플로 자체가 없음 |
| 6 | **소프트웨어 개발 IDE** | Visual Studio, IntelliJ, Eclipse | 컴파일러·디버거·빌드 시스템 전체가 데스크톱 OS 전제 |
| 7 | **음악 악보 편집 (Notation)** | Sibelius, Finale, MuseScore Desktop | MIDI 실시간 입력 + 대형 악보 레이아웃 엔진 / 모바일은 뷰어 수준 |
| 8 | **3D 스컬프팅** | ZBrush, Mudbox | 수억 폴리곤 다이나믹 메시 → 모바일 GPU 메모리 구조로 처리 불가 |
| 9 | **영화·TV급 VFX 합성** | Nuke, After Effects 풀기능 | 멀티레이어 EXR + GPU 가속 합성 엔진이 데스크톱 전용 |
| 10 | **게임 엔진 (개발 IDE)** | Unity Editor, Unreal Engine | 에셋 빌드·셰이더 컴파일·씬 편집기가 Win/Mac 전용 (Android는 빌드 타겟일 뿐) |

---

## TIER 2 — 심각하게 부족 (있으나 기능 절반 이하)

| # | 장르 | PC 대표 | Android에 없는 이유 |
|---|------|---------|-------------------|
| 11 | **전문 사진 RAW 워크플로우** | Lightroom Classic, Capture One | Lightroom Classic Android 버전 없음 / RAW 파이프라인이 파일시스템 의존도 극히 높음 |
| 12 | **DTP (데스크톱 출판·조판)** | Adobe InDesign, QuarkXPress | CMYK + 인쇄소 연동 PDF/X 처리 불가 |
| 13 | **벡터 일러스트 (전문급)** | Adobe Illustrator, CorelDRAW | 수천 패스 + CMY/Pantone 정밀 색상 / Android 앱은 기본 도형 수준 |
| 14 | **데이터 분석·BI (대용량)** | Excel 풀기능, Power BI Desktop, Tableau | 100만 행 피벗·매크로·VBA / Power BI Desktop Android 버전 없음 |
| 15 | **오디오 마스터링·스펙트럼 편집** | iZotope RX, Ozone, Audacity 풀기능 | 고해상도 FFT 처리 / 리얼타임 플러그인 체인이 Android 레이턴시와 충돌 |
| 16 | **전자악보 제작 출판용** | Sibelius Ultimate, Dorico Pro | MIDI→악보 + 인쇄용 PDF 렌더링 / 모바일은 뷰어 이상 불가 |
| 17 | **PCB 설계·전자 회로 시뮬레이션** | KiCad, Altium Designer, LTspice | 회로 시뮬레이션 + Gerber 파일 생성 / Android에 등가 앱 전무 |
| 18 | **건축·인테리어 BIM** | Revit, ArchiCAD | 수GB BIM 프로젝트 + IFC 포맷 / 모바일은 뷰어만 존재 |
| 19 | **영상 컬러 그레이딩 (풀)** | DaVinci Resolve Color, Baselight | LUT 관리 + 하드웨어 컬러 패널 연동 / Android 버전은 기능 30% 수준 |
| 20 | **시스템·네트워크 모니터링·관리** | Wireshark, SolarWinds, PRTG | 패킷 캡처 → 루트+커널 드라이버 접근 / Android 샌드박스로 불가 |

---

## TIER 3 — 장르 자체가 Android에서 성립 안 됨

| # | 장르 | PC 대표 | Android에 없는 이유 |
|---|------|---------|-------------------|
| 21 | **가상화·VM** | VMware, VirtualBox, Hyper-V | 하이퍼바이저가 Intel VT-x/AMD-V 접근 필요 / Android 커널 샌드박스 차단 |
| 22 | **악성코드 분석·포렌식** | Ghidra, IDA Pro, Autopsy | 리버스엔지니어링 + 파일시스템 직접 접근 / 법적·기술적 불가 |
| 23 | **오케스트라 VSTi + 샘플러** | Kontakt + 샘플 라이브러리 | 수십 GB 샘플 스트리밍 / VSTi 포맷이 Android 오디오 HAL과 미호환 |
| 24 | **OBS급 방송 믹서** | OBS Studio 풀기능, vMix | 다중 소스 믹싱 + RTMP + 씬 전환 / Android는 단일 화면 캡처 수준 |
| 25 | **게임 모딩·레벨 에디터** | Skyrim Creation Kit, Hammer Editor | 게임 내부 에셋 직접 수정 / Android 게임 구조가 모딩 접근 차단 |
| 26 | **산업용 HMI·SCADA·PLC 프로그래밍** | Siemens TIA Portal, Wonderware | 산업 제어 프로토콜(Modbus, Profibus) + 인증 규격 / Android 산업 인증 스택 없음 |

---

## 방송 우선순위 (임팩트 순)

| 순위 | 장르 | 이유 |
|------|------|------|
| 🥇 1 | DAW (#1) | 음악 제작자 좌절 최고, 박씨가 REAPER 이미 세팅 완료 |
| 🥈 2 | OBS급 방송 믹서 (#24) | Parksy Studio v2.0 파이프라인과 직결 |
| 🥉 3 | 전문 영상편집 (#2) | 유튜버/크리에이터 타깃, 수요 최대 |
| 4 | IDE (#6) | Claude Code 자체가 시연 소재 |
| 5 | 게임 엔진 (#10) | 게임 개발 지망생 타깃 |
| 6 | DTP/인디자인 (#12) | 1인 출판사 박씨와 직결 |
| 7 | 네트워크 모니터링 (#20) | 개발자/보안 타깃 |
| 8 | Power BI (#14) | 비즈니스 데이터 분석 타깃 |

---

## 콘텐츠 공식

```
"[PC 전용 장르]는 Android에 없다"
    ↓
폰 + 음성 + mosh + Tailscale + Claude Code
    ↓
구현하거나, 한계를 보여주거나, 대안을 만들거나
    ↓
방송 1편
```

---

*출처: 2026-03-27 박씨 × Claude Code 전략 세션*
*커뮤니티 리서치 (HN, Medium, Dev.to, Reddit) + 직접 지식 조합*
