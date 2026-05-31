# Parksy Capture v11.0.0 — 온디바이스 구현 명세 (실제)

> **버전:** v11.0.0 (v10.0.8 → v11)
> **날짜:** 2026-05-25
> **실제 구현:** MiniLM 임베딩 (Termux) + DeepSeek API (클라우드 LLM)
> **제외:** NPU, on-device LLM, SQLite 벡터 저장소, BackendService
> **판단 근거:** 박씨 확정 — "온디바이스 LLM은 필요 없다. 에이전트용 DeepSeek만 있으면 충분"

---

## 실제 아키텍처 (v11.0.0)

```
┌─────────────────────────────────────────────────────┐
│                 Parksy Capture APK                    │
├─────────────────────────────────────────────────────┤
│  Flutter UI (Dart)                                    │
│  ├── Capture Tab (Share Intent 수신)                  │
│  ├── Browse Tab (목록/검색/상세)                      │
│  ├── Tools Tab (JSONL/프로파일/MCP/변환)              │
│  └── Settings (온디바이스 AI 토글, API 키 불필요)      │
│         │                                              │
│         ▼ MethodChannel                               │
│  MainActivity.kt (Kotlin)                             │
│  ├── onDeviceSearch(query, mode)                      │
│  │   ├── callMcpSearch() → POST localhost:8018/api/tool│
│  │   └── localTextSearch() (fallback, Kotlin)         │
│  ├── JSONL Converter (.md → .jsonl)                   │
│  └── Wording Profiler (빈도/패턴 분석)                │
└──────────┬──────────────────────────────────────────┘
           │ localhost:8018
┌──────────▼──────────────────────────────────────────┐
│  Termux: Embed Server (:8018)                       │
│  ┌──────────────────────────────────────────────┐   │
│  │ parksy_embed_server.py (aiohttp)              │   │
│  │                                               │   │
│  │ GET  /health     → 상태 확인                   │   │
│  │ POST /embed      → MiniML L6-v2 임베딩 (384d) │   │
│  │ POST /api/tool   → llm_generate / embed_search│   │
│  │                                               │   │
│  │ [로컬] MiniLM-L6-v2 (CPU, 86.6MB, 0원)       │   │
│  │ [클라우드] DeepSeek API (deepseek-chat, ~$0.27)│   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 변경 이력: 원래 계획 vs 실제 구현

| 항목 | 원래 계획 | 실제 구현 | 이유 |
|------|----------|----------|------|
| LLM | llama.cpp 온디바이스 (Q4_0) | DeepSeek API (클라우드) | 박씨: "온디바이스 LLM 필요 없음. 에이전트 용도면 DeepSeek으로 충분" |
| 임베딩 | onnxruntime APK 번들 | Termux Python transformers | onnxruntime Android 빌드 불필요, Python이 유지보수 쉬움 |
| NPU | QNN HTP (SD 이미지 연동) | **미구현** | 텍스트 처리에 NPU 과잉, Local Dream이 별도로 존재 |
| 벡터 DB | SQLite + 코사인 유사도 | **미구현** | 키워드 검색으로도 충분, DeepSeek이 context window로 처리 |
| BackendService | Android Service (ProcessBuilder) | **미구현** | Termux Python으로 대체, APK 복잡도 불필요 |
| RAG UI | API 키 필드 제거 | ✅ 완료 | 설정 화면 단순화, API 키 입력 불필요 |
| JSONL 변환 | C++ 바이너리 | ✅ Kotlin native | Kotlin으로도 충분히 빠름 |
| 워딩 프로파일러 | 온디바이스 LLM 필요 | ✅ Kotlin regex/native | LLM 없이 규칙 기반으로 구현 가능 |
| MCP 생성기 | 온디바이스 LLM이 코드 생성 | ⚠️ 플레이스홀더 | DeepSeek API 경유로 전환 가능 |
| 언어 변환 | ML Kit | ⚠️ 플레이스홀더 | ML Kit 연동은 다음 Phase |
| GitHub Worker | Cloudflare Worker | ❌ 제거 | Worker 불필요, APK가 직접 GitHub API 호출 |

---

## Embed Server 상세

### parksy_embed_server.py

Termux에서 실행되는 aiohttp REST 서버. HuggingFace offline 모드로 MiniLM 로딩.

**환경변수:**
```bash
export HF_HUB_OFFLINE=1          # HuggingFace Hub offline (rustls panic 우회)
export TRANSFORMERS_OFFLINE=1    # Transformers offline
export DEEPSEEK_API_KEY=sk-...   # DeepSeek API 키 (~/.config/deepseek.env)
```

**엔드포인트:**

| 엔드포인트 | 메서드 | 기능 |
|-----------|--------|------|
| `/health` | GET | 서버 상태 + 모델 목록 |
| `/embed` | POST | 텍스트 → float[384] 벡터 |
| `/api/tool` | POST | `llm_generate` / `embed_search` |

**`/api/tool` 상세:**

```json
// Request
{
  "tool": "llm_generate",
  "params": {
    "query": "질문 내용",
    "max_tokens": 1024,
    "system_prompt": "당신은 도움이 되는 AI 비서입니다."
  }
}
// Response
{
  "answer": "DeepSeek 응답 텍스트",
  "references": []
}
```

```json
// embed_search
{
  "tool": "embed_search",
  "params": { "query": "검색어" }
}
// Response
{
  "answer": "임베딩 완료: 검색어",
  "query_embedding": [0.012, -0.034, ...],
  "references": []
}
```

### 모델: MiniLM-L6-v2

| 속성 | 값 |
|------|-----|
| 모델 | `sentence-transformers/all-MiniLM-L6-v2` |
| 차원 | 384 |
| 크기 | 86.6MB (PyTorch) |
| 위치 | Termux HuggingFace 캐시 (offline) |
| 추론 시간 | ~50ms (CPU) |
| 비용 | $0 |

### DeepSeek API

| 속성 | 값 |
|------|-----|
| 모델 | `deepseek-chat` (DeepSeek V3) |
| API | `https://api.deepseek.com/v1/chat/completions` |
| 비용 | ~$0.27/1M tokens (input) / ~$1.10/1M tokens (output) |
| 키 위치 | `~/.config/deepseek.env` |

---

## APK → Embed Server 통신 흐름

```
User 질문 입력 (Flutter UI)
  → Dart: platform.invokeMethod('onDeviceSearch', {query, mode})
  → Kotlin: onDeviceSearch()
    → callMcpSearch(query, mode)
      → HTTP POST http://localhost:8018/api/tool
        → Embed Server 파싱
        → mode == "generate"
          → DeepSeek API 호출 (클라우드)
          → 응답 반환
        → mode == "embed"
          → MiniLM 임베딩 (로컬)
          → 응답 반환
    → 실패 시 → localTextSearch() (Kotlin 키워드 검색 fallback)
  → Dart: 결과 표시
```

---

## Tools Tab 구현 상태

| 도구 | 구현 | 방식 | 비고 |
|------|------|------|------|
| **JSONL 변환** | ✅ 완료 | Kotlin native 파싱 | `.md` 파일 → user/assistant 페어 → `.jsonl` |
| **워딩 프로파일** | ✅ 완료 | Kotlin 텍스트 분석 | 단어 빈도, 문장 패턴, 도메인 가중치 |
| **MCP 생성기** | ⚠️ 플레이스홀더 | DeepSeek API 경유 (준비) | 프로파일 JSON → MCP 스펙 자동 생성 |
| **언어 변환** | ⚠️ 플레이스홀더 | ML Kit (준비) | 한국어 → 영어 변환 |

---

## Boot 자동 시작

`~/.termux/boot/start_all_mcp.sh`:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Embed Server (:8018)
HF_HUB_OFFLINE=1 python3 ~/parksy_embed_server.py 8018 > /dev/null 2>&1 &
# Voice (:8015)
# Audio (:8016)
# Publish (:8020)
# Webpage (:8789)
```

Watchdog (`mcp_watchdog.sh`)가 30초마다 헬스체크, 죽으면 재시작.

---

## 과금 계산 (실제)

| 서비스 | v10.0.8 | v11.0.0 (실제) | 절감 |
|--------|---------|---------------|------|
| OpenAI 임베딩 | ~$0.10/월 | $0 (MiniLM 로컬) | $0.10 |
| Supabase | $0 (free) | $0 (제거) | 0 |
| Claude API | ~$1/월 | $0 (DeepSeek으로 대체) | $1 |
| DeepSeek API | $0 | ~$0.27/1M tokens (매우 저렴) | — |
| GitHub | $0 | $0 | 0 |
| **합계** | **~$1.10/월** | **~$0.10/월** | **~91% 절감** |

---

## 남은 작업 (다음 버전)

- [ ] **MCP 생성기** — DeepSeek API로 프로파일 → MCP 스펙 자동 생성
- [ ] **언어 변환** — ML Kit on-device 번역 연동
- [ ] **벡터 캐시** — 로그 임베딩을 SQLite에 저장 (매번 재임베딩 방지)
- [ ] **GitHub Workers 완전 제거** — worker/ 디렉토리 정리
- [ ] **NPU 연동** — Local Dream 스타일 QNN (필요 시)
- [ ] **onDeviceSearch 프론트** — AI 검색 결과 UI 개선 (소스 표시, 연관도)

---

## 리스크 (실제)

| 리스크 | 확률 | 대응 |
|--------|------|------|
| Embed Server 꺼짐 | 낮 | Watchdog 자동 재시작 + Kotlin fallback 검색 |
| DeepSeek API 장애 | 낮 | localTextSearch() fallback (키워드) |
| HuggingFace 캐시 손상 | 낮 | curl 재다운로드 스크립트 준비 |
| rustls panic 재발 | 낮 | HF_HUB_OFFLINE=1 + local_files_only=True |
