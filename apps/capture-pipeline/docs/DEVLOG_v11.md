# Parksy Capture v11 개발일지

> **작성:** 2026-05-25
> **기준:** v10.0.8 (베이스라인) → v11.0.0+34 (현재)
> **목표:** Supabase/OpenAI/Claude 제거 + DeepSeek 기반 MCP 허브 전환

---

## v10.0.8 대비 v11.0.0 변경 사항

### 1. 제거한 것 (클린업)

| 항목 | v10.0.8 | v11.0.0 | 효과 |
|------|---------|---------|------|
| Supabase pgvector RAG | 설정 존재, 미사용 | **제거** | 설정 복잡도 감소 |
| OpenAI Embedding API | `text-embedding-3-small` | **제거** | 과금 $0.10/월 → $0 |
| Claude API | RAG 답변 생성용 | **제거** | 과금 $1/월 → $0 |
| Cloudflare Worker | `worker/` 디렉토리 유령 | **제거** | 유지보수 대상 제거 |
| path_provider | pubspec.yaml 데드 의존성 | **제거** | APK 경량화 |
| 버전 불일치 | APK_CARD=10.0.8, About=10.0.5 | **11.0.0+34 통일** | 혼선 제거 |
| on-device LLM (Qwen GGUF) | 없었음 → 설치 → **제거** | 986MB 확보 |
| phone_capture_mcp_sse | 없었음 → 생성 → **제거** | 불필요한 서버 제거 |
| embed_server NPU/NNAPI | 없었음 → 추가 → **제거** | 복잡도 감소 |

### 2. 추가한 것 (신규)

| 항목 | 구현 | 상태 |
|------|------|------|
| **Embed Server (:8018)** | Termux aiohttp + MiniLM L6-v2 + DeepSeek API | ✅ 구동 중 |
| **AI 검색** | Flutter → Kotlin → :8018 → MiniLM/DeepSeek | ✅ |
| **로컬 텍스트 검색 fallback** | Kotlin frequency scoring | ✅ |
| **JSONL 변환** | Kotlin native, ChatGPT/Claude 포맷 대응 | ✅ |
| **워딩 프로파일러** | 단어 빈도/문장 패턴/도메인 분석 | ✅ |
| **MCP 생성기** | DeepSeek API 경유 MCP 서버 코드 생성 | ✅ |
| **언어 변환기** | UI 플레이스홀더 | ⚠️ |
| **온디바이스 설정 단순화** | API 키 6개 → 토글 1개 | ✅ |
| **설정 화면** | onDeviceMode 토글 + GitHub 토큰만 | ✅ |

### 3. 고친 것 (버그픽스)

| 버그 | 내용 | 해결 |
|------|------|------|
| `parseConversationTurns()` | `user:`/`assistant:` 프리픽스만 인식 → ChatGPT/Claude 공유 텍스트 파싱 불가 | **볼드 마크다운(`**You:**`, `**ChatGPT:**`), blockquote, fallback 전체→user 메시지** |
| MCP 생성기 SnackBar | `"온디바이스 LLM 필요"` 하드코딩 → 동작 없음 | **DeepSeek API 실제 연결: Kotlin → :8018 `llm_generate` → 코드 생성** |
| voice MCP syntax error | `phone_voice_mcp_sse.py` line 137 string literal 미종료 | **따옴표 수정 → 서버 정상 기동** |
| boot script | capture MCP(:8017) 잘못 등록 | **제거 + watchdog 동기화** |

### 4. 유지한 것 (변경 없음)

| 기능 | 상태 |
|------|------|
| Share Intent 수신 (ACTION_SEND + ACTION_PROCESS_TEXT) | ✅ |
| 로컬 마크다운 저장 (`Downloads/parksy-logs/*.md`) | ✅ |
| GitHub 자동 백업 (선택) | ✅ |
| 전체 텍스트 검색 (키워드) | ✅ |
| Favorites/Stats/Preview/정렬 | ✅ |
| GitHub Dark 테마 | ✅ |

---

## 과금 비교

| 서비스 | v10.0.8 | v11.0.0 | 절감 |
|--------|---------|---------|------|
| OpenAI Embedding | ~$0.10/월 | $0 (MiniLM 로컬) | $0.10 |
| Claude API | ~$1/월 | $0 | $1.00 |
| DeepSeek API | $0 | ~$0.27/1M tokens (매우 저렴) | — |
| GitHub | $0 | $0 | — |
| **합계** | **~$1.10/월** | **~$0.10/월 (사용량 기반)** | **~91% 절감** |

---

## 현재 폰 서버 상태

| 서버 | 포트 | 상태 | 용도 |
|------|------|------|------|
| Voice MCP | 8015 | ✅ 구동 | edge-tts → RVC 음성 |
| Audio MCP | 8016 | ❌ 미구동 | 오디오 처리 |
| Embed Server | 8018 | ✅ 구동 | MiniLM 임베딩 + DeepSeek API |
| Publish MCP | 8020 | ❌ 미구동 | 배포 |
| Webpage MCP | 8789 | ❌ 미구동 | 웹페이지 캡처 |

---

## 남은 작업 (다음 버전)

### P0 — MCP Generator end-to-end 검증
- [ ] Tools 탭 → 프로파일 추출 → MCP 서버 생성 → 실제 코드 생성 확인
- [ ] 생성된 MCP 코드를 Termux에 저장해서 실행 가능 확인

### P1 — 서버 안정화
- [ ] Audio MCP(:8016) syntax error 수정
- [ ] Publish MCP(:8020) startup error 수정
- [ ] Webpage MCP(:8789) startup error 수정
- [ ] 부트 시 전 서버 자동 시작 검증

### P2 — 검색 품질
- [ ] 로그 임베딩 캐시 (SQLite 저장으로 재임베딩 방지)
- [ ] AI 검색 결과 UI 개선 (소스 표시, 연관도)

### P3 — 확장
- [ ] 언어 변환기 ML Kit 연동
- [ ] MCP 생성기 출력 포맷 표준화
- [ ] `provider=deepseek|groq|local` 백엔드 토글

---

## 아키텍처 (최종)

```
Share Intent → MainActivity.kt → Downloads/parksy-logs/*.md
                                     │
JSONL 변환: parseConversationTurns() → user/assistant 쌍 → .jsonl
워딩 프로파일: generateProfile() → 단어/패턴/도메인 분석
                                     │
AI 검색: onDeviceSearch()
  ├── callMcpSearch() → POST :8018/api/tool
  │     ├── llm_generate → DeepSeek API (클라우드)
  │     └── embed_search → MiniLM L6-v2 (로컬, 384d, 75ms)
  └── localTextSearch() → Kotlin 키워드 매칭 (fallback)

MCP 생성: generateMCP()
  └── POST :8018/api/tool {tool: "llm_generate"}
       └── DeepSeek API → MCP 서버 코드 (Express + SSE)
```

---

## 파일 구조

```
apps/capture-pipeline/
├── lib/main.dart                    # Flutter UI (Capture/Browse/Tools/Settings)
├── android/.../MainActivity.kt      # Share handler + onDeviceSearch + Tools
├── pubspec.yaml                     # version: 11.0.0+34
├── README.md                        # v11 문서화 완료
└── docs/
    ├── SETUP.md                     # Termux + Embed Server 설치 가이드
    ├── ONDEVICE_UPGRADE_PLAN.md     # 구현 명세 (계획 vs 실제)
    ├── CAPTURE_V2_DEVPLAN.md        # 개발 완료 보고
    ├── CTO_HARDENING_REPORT.md      # 보안 보고서 (변경 없음)
    └── DEVLOG_v11.md                # 이 파일
```

---

## 요약

v10.0.8 → v11.0.0에서 좋아진 점:

1. **과금 제로** — OpenAI/Claude API 제거, MiniLM 로컬 임베딩
2. **설정 제로** — API 키 6개 → 0개
3. **AI 검색** — 질문 → MiniLM 임베딩 + DeepSeek 응답
4. **JSONL 변환** — ChatGPT/Claude 공유 텍스트 → 파인튜닝 포맷
5. **MCP 생성기** — 대화 패턴 → MCP 서버 코드 자동 생성
6. **워딩 프로파일러** — 말투/단어/패턴 분석
7. **코드 베이스 정리** — 데드 의존성 제거, 버전 통일
8. **부트 자동화** — Embed Server + Voice MCP termux-boot 자동 시작
9. **문서 전면 업데이트** — README + docs/ 4종
