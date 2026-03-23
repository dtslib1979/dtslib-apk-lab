# Claude API 일괄 전환 계획서

> **목표:** 텍스트 생성 API를 Claude API(Anthropic)로 통합하여 과금 구조 단순화
> **작성일:** 2026-03-23
> **상태:** Phase 1 완료, Phase 2 미착수

---

## 1. 전환 매트릭스

### 전환 완료 (Phase 1)

| 앱 | 기능 | Before | After | 모델 | 상태 |
|----|------|--------|-------|------|------|
| Parksy Glot | 실시간 번역 | GPT-4o | Claude API | `claude-haiku-4-5-20251001` | ✅ |
| Parksy ChronoCall | 학자 대화 | Gemini 2.5 Flash | Claude API | `claude-haiku-4-5-20251001` → `sonnet-4` 폴백 | ✅ |
| Parksy Capture | RAG 답변 생성 | GPT-4o-mini | Claude API | `claude-sonnet-4-20250514` | ✅ |

### 전환 불가 — 유지 (OpenAI/Google)

| 앱 | 기능 | API | 이유 |
|----|------|-----|------|
| Parksy Glot | 음성→텍스트 (STT) | OpenAI Whisper | Claude에 STT API 없음 |
| Parksy Capture | 벡터 임베딩 | OpenAI Embeddings (`text-embedding-3-small`) | Claude에 임베딩 API 없음 |
| Parksy TTS Factory | 음성 합성 | Google Cloud TTS | Claude에 TTS API 없음 |
| Parksy ChronoCall | 음성→텍스트 (STT) | OpenAI Whisper | Claude에 STT API 없음 |

### 미전환 — 검토 필요 (Phase 2)

| 앱 | 기능 | 현재 API | 전환 가능성 | 비고 |
|----|------|----------|-------------|------|
| Parksy Capture | 임베딩 기반 RAG | OpenAI Embeddings + Supabase pgvector | **중** | Voyager 임베딩 출시 시 재검토, 또는 Claude의 긴 컨텍스트로 RAG 없이 직접 처리 |
| Parksy Studio | 동시통역 | Web Speech API (미동작) | **높음** | v2.0에서 네이티브 전환 시 Claude 연동 가능 |

---

## 2. 변경된 파일 목록

### Parksy Glot (6파일)

| 파일 | 변경 |
|------|------|
| `lib/services/translation_service.dart` | OpenAI Chat → Anthropic Messages API |
| `lib/services/whisper_service.dart` | `AppConfig.apiKey` → `AppConfig.whisperKey` |
| `lib/config/app_config.dart` | `claude_api_key` + `openai_api_key`(Whisper) 분리 |
| `lib/screens/settings_screen.dart` | Claude 키 + Whisper 키 이중 입력 UI |
| `lib/screens/home_screen.dart` | 안내 텍스트 Claude 변경 |
| `lib/utils/constants.dart` | 힌트 텍스트 변경 |
| `lib/utils/error_handler.dart` | 에러 메시지 변경 |

### Parksy ChronoCall (2파일)

| 파일 | 변경 |
|------|------|
| `lib/screens/chat_screen.dart` | Gemini generateContent → Anthropic Messages, 키 저장소 `claude_api_keys` |
| `lib/screens/landing_screen.dart` | `gemini_*` → `claude_*` 키 마이그레이션, 검증 엔드포인트 변경 |

### Parksy Capture (1파일)

| 파일 | 변경 |
|------|------|
| `lib/main.dart` | `_generateAnswer()` Claude 전환, `claudeKey` 필드 추가, Settings UI 이중 키 |

---

## 3. 메타데이터 동기화 (TODO)

| 파일 | 현재 | 변경 필요 |
|------|------|-----------|
| `apps/parksy-glot/app-meta.json` | `"OpenAI Whisper + GPT-4o"` | `"OpenAI Whisper + Claude"` |
| `dashboard/apps.json` | `"OpenAI Whisper + GPT-4o"` | `"OpenAI Whisper + Claude"` |

---

## 4. API 키 구조 (전환 후)

```
┌─────────────────────────────────────────────────┐
│  Claude API Key (sk-ant-...)                    │
│  ├─ Glot: 실시간 번역                            │
│  ├─ ChronoCall: 학자 대화                        │
│  └─ Capture: RAG 답변 생성                       │
├─────────────────────────────────────────────────┤
│  OpenAI API Key (sk-proj-...)                   │
│  ├─ Glot: Whisper STT                           │
│  ├─ Capture: 임베딩 (text-embedding-3-small)     │
│  └─ ChronoCall: Whisper STT                     │
├─────────────────────────────────────────────────┤
│  Google Cloud TTS Key                           │
│  └─ TTS Factory: 음성 합성                       │
└─────────────────────────────────────────────────┘
```

---

## 5. Phase 2 로드맵

### 5-1. 임베딩 제거 검토 (Capture)

Claude의 200K 컨텍스트 윈도우를 활용하면 임베딩+벡터검색 없이도 RAG가 가능할 수 있다.

```
현재: query → OpenAI embedding → Supabase pgvector → top-K docs → Claude 답변
대안: query → Supabase 전문검색(FTS) → top-K docs → Claude 답변 (임베딩 제거)
```

**장점:** OpenAI 키 Capture에서 완전 제거
**단점:** 의미 기반 검색 품질 하락 가능
**판단:** 실제 사용 패턴 보고 결정

### 5-2. SharedPreferences 키 마이그레이션

기존 사용자의 `gemini_api_keys`, `openai_api_key` 데이터가 새 키 이름 `claude_api_keys`, `claude_api_key`로 자동 이관되지 않는다. 앱 첫 실행 시 마이그레이션 로직 필요.

```dart
// TODO: 앱 시작 시 한 번 실행
final old = prefs.getString('gemini_api_keys');
if (old != null && prefs.getString('claude_api_keys') == null) {
  await prefs.setString('claude_api_keys', old);
  await prefs.remove('gemini_api_keys');
}
```

### 5-3. 모델 선택 UI (선택사항)

현재 모델이 하드코딩되어 있다. Settings에서 모델 선택 드롭다운 추가 고려:

```
Haiku 4.5  — 빠름, 저렴 (실시간 자막, 대화)
Sonnet 4   — 균형 (RAG, 번역)
Opus 4     — 최고 품질 (복잡한 분석)
```

---

## 6. 과금 구조 비교

### Before (3개 제공자)
```
OpenAI:  GPT-4o (Glot 번역) + GPT-4o-mini (Capture RAG) + Whisper + Embeddings
Gemini:  Flash 2.5 (ChronoCall 대화)
Google:  Cloud TTS (TTS Factory)
```

### After (2개 제공자)
```
Claude:  Haiku 4.5 (Glot 번역, ChronoCall 대화) + Sonnet 4 (Capture RAG)
OpenAI:  Whisper STT + Embeddings only
Google:  Cloud TTS (TTS Factory)
```

**텍스트 생성 비용:** Claude Max 5x 요금제로 흡수 가능
**잔여 외부 비용:** Whisper STT + Embeddings (소량) + Cloud TTS
