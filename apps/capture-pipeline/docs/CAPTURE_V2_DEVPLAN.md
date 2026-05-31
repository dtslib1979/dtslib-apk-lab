# Parksy Capture v11.0.0 — 개발 완료 보고서

> **작성:** 2026-05-25 / Claude Code (DeepSeek) + phone_aider (DeepSeek)
> **버전:** v10.0.8 → **v11.0.0** ✅ 완료
> **원래 계획:** 온디바이스 NPU + llama.cpp
> **실제 구현:** MiniLM (Termux) + DeepSeek API (클라우드)
> **방향 결정:** 박씨 — "온디바이스 LLM은 필요 없다. DeepSeek 에이전트로 충분"

---

## 배경

### v10 아키텍처 (변경 전)

```
폰 APK (수집기)          PC/클라우드 (가공기)
─────────────────        ─────────────────────
Share Intent 수신    →   parksy-logs 레포 폴링
마크다운 로컬 저장        파이썬 배치 처리
GitHub 자동 푸시          MCP 툴 생성
로컬 검색 + RAG           LoRA 전처리
```

**문제:** PC가 켜져 있어야 가공 가능. 클라우드(Supabase) 설정 복잡. 수집과 가공이 분리.

### v11 아키텍처 (변경 후)

```
Parksy Capture v11 APK
  ├── [수집] Share Intent 수신 → Downloads/parksy-logs/*.md
  ├── [검색] MethodChannel → Embed Server (:8018)
  │     ├── MiniLM 임베딩 (로컬, 0원)
  │     └── DeepSeek API (클라우드, ~$0.27/1M tokens)
  ├── [도구] JSONL 변환 / 워딩 프로파일 / MCP 생성 / 언어 변환
  └── [백업] GitHub 푸시 (선택)
```

**핵심 변경:** PC 의존성 제거. 클라우드 API는 DeepSeek만 (저렴). Supabase/OpenAI/Claude API 전부 제거.

---

## v10 → v11 변경사항

### 구현 완료 (✅)

| 항목 | v10 | v11 | 비고 |
|------|-----|-----|------|
| AI 검색 엔진 | OpenAI 임베딩 + Supabase pgvector + Claude API | MiniLM 임베딩 + DeepSeek API | 과금 $1.10/월 → $0.10/월 |
| Embed Server | 없음 | parksy_embed_server.py (:8018) | Termux aiohttp |
| 검색 fallback | 없음 | localTextSearch() (Kotlin) | 서버 불가 시 자동 전환 |
| 설정 화면 | API 키 6개 (OpenAI, Claude, Supabase 등) | 온디바이스 토글 1개 | 단순화 |
| JSONL 변환 | 없음 | Kotlin native ✅ | Tools 탭 |
| 워딩 프로파일러 | 없음 | Kotlin 텍스트 분석 ✅ | Tools 탭 |
| README | v3.0.0 내용 | v11.0.0 전체 재작성 | 문서 업데이트 |
| SETUP.md | Cloudflare Worker, CI 위주 | Termux + Embed Server 위주 | 문서 업데이트 |
| ONDEVICE_UPGRADE_PLAN.md | NPU/llama.cpp 계획 | 실제 구현 명세 | 문서 업데이트 |
| path_provider | 데드 의존성 | 제거 ✅ | pubspec.yaml |
| 버전 통일 | 불일치 (APK_CARD 10.0.8 / About 10.0.5) | 11.0.0+34 단일 통일 ✅ | pubspec.yaml 권위 |

### 구현 안 함 (❌ 이유 있음)

| 항목 | 계획 | 실제 | 이유 |
|------|------|------|------|
| on-device LLM (llama.cpp) | Q4_0 모델 설치 | 설치했다가 전부 제거 | 박씨: "필요 없다. DeepSeek으로 충분" |
| NPU / QNN HTP | SD 이미지 연동 | 미구현 | 텍스트에 NPU 과잉, Local Dream 별도 존재 |
| SQLite 벡터 DB | 코사인 유사도 검색 | 미구현 | 키워드 검색 + DeepSeek context window로 충분 |
| BackendService | Android Service | 미구현 | Termux Python으로 대체 |
| Cloudflare Worker | API 중계 | 미사용 | APK 직접 GitHub API 호출 |

### 플레이스홀더 (⚠️ 다음 버전)

| 항목 | 상태 | 계획 |
|------|------|------|
| MCP 생성기 | UI만 있음 | DeepSeek API 경유로 완성 |
| 언어 변환 | UI만 있음 | ML Kit on-device 번역 연동 |
| 벡터 캐시 | 미구현 | SQLite 저장으로 재임베딩 방지 |

---

## Embed Server (Termux)

### 설치 구성

| 항목 | 값 |
|------|-----|
| 스크립트 | `~/parksy_embed_server.py` |
| 포트 | 8018 |
| 프레임워크 | aiohttp |
| 임베딩 모델 | MiniLM-L6-v2 (PyTorch, 86.6MB) |
| LLM 백엔드 | DeepSeek API (deepseek-chat) |
| 실행 방식 | termux-boot 자동 시작 |
| Watchdog | mcp_watchdog.sh (30초 주기) |

### 의존성

```bash
pkg install python ninja cmake build-essential rust
pip install aiohttp transformers torch sentencepiece sacremoses
```

---

## Tools Tab

3개 도구 구현 완료, 2개 플레이스홀더:

```
Tools 탭 (Flutter UI)
  ├── 📥 JSONL Converter ✅
  │     .md 파일 선택 → user/assistant 페어 파싱 → .jsonl 저장
  │     구현: MainActivity.kt → parseConversationTurns()
  │
  ├── 📊 Wording Profiler ✅
  │     단어 빈도, 문장 패턴, 도메인 가중치 분석
  │     구현: MainActivity.kt → generateWordingProfile()
  │
  ├── 🛠 MCP Generator ⚠️
  │     프로파일 JSON → MCP 툴 스펙 자동 생성
  │     상태: 플레이스홀더 (DeepSeek API 연동 필요)
  │
  └── 🌐 Language Converter ⚠️
      한국어 → 영어 변환
      상태: 플레이스홀더 (ML Kit 연동 필요)
```

---

## AI 검색 흐름

```
Flutter: TextField (질문 입력)
  → _performAISearch(query)
    → platform.invokeMethod('onDeviceSearch', {query, mode})
      → MainActivity.onDeviceSearch()
        → callMcpSearch(query, mode)
          → POST http://localhost:8018/api/tool
            Body: {
              "tool": "llm_generate" | "embed_search",
              "params": { "query": "...", "max_tokens": 1024 }
            }
          → Response: { "answer": "...", "references": [] }
        → 실패 시 → localTextSearch(query)
          → Kotlin 키워드 매칭 (frequency scoring)
    → Dart: 결과 표시
```

---

## 문서 정리 완료

| 문서 | 상태 | 변경 내용 |
|------|------|----------|
| `README.md` | ✅ 업데이트 | v3→v11, 아키텍처 다이어그램, AI 검색 흐름, Tools 탭 |
| `SETUP.md` | ✅ 재작성 | Termux 설치, Embed Server, DeepSeek API 키, 폰 테스트 |
| `ONDEVICE_UPGRADE_PLAN.md` | ✅ 재작성 | 원래 계획 vs 실제 구현, Embed Server 상세 |
| `CAPTURE_V2_DEVPLAN.md` | ✅ 재작성 | v10→v11 변경 완료 보고 |
| `CTO_HARDENING_REPORT.md` | — | 변경 불필요 (보안 보고서) |

---

## 완료 조건 체크

- [x] Supabase/OpenAI/Claude API 필드 완전 제거
- [x] Share Intent 수신 → 로컬 저장 + Tools 가공
- [x] AI 검색: MiniLM 임베딩 + DeepSeek API
- [x] 로컬 텍스트 검색 fallback (서버 불가 시)
- [x] JSONL 변환 (파인튜닝 데이터 추출)
- [x] 워딩 프로파일러 (빈도/패턴 분석)
- [x] 설정 화면 단순화 (API 키 불필요)
- [x] 문서 전면 업데이트 (README + docs/ 전체)
- [x] path_provider 제거, 버전 통일
- [x] 과금 ~91% 절감 ($1.10/월 → ~$0.10/월)

---

## 폰 설치 확인

| 항목 | 상태 |
|------|------|
| APK v11.0.0 설치 | ✅ Installed |
| Embed Server (:8018) | ✅ Running |
| MiniLM 모델 캐시 | ✅ HuggingFace offline cache |
| DeepSeep API 키 | ✅ ~/.config/deepseek.env |
| Boot 자동 시작 | ✅ ~/.termux/boot/start_all_mcp.sh |
| Watchdog | ✅ mcp_watchdog.sh |
| termux-wake-lock | ✅ Active |

---

*작성: 2026-05-25 / Claude Code (DeepSeek) + phone_aider (DeepSeek)*
*박씨 최종 확인: "온디바이스 LLM은 필요 없다. 문서 저장한 거 다 확인해"*
