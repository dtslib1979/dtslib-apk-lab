# Parksy Capture v11.0.0 — Setup Guide

Lossless LLM conversation capture. Share Intent bypasses clipboard limits.
**No cloud APIs required. On-device AI search + DeepSeek API (optional).**

---

## What It Does

1. 텍스트 Share → Parksy Capture → `Downloads/parksy-logs/*.md` 저장
2. **AI 검색**: 로그 내용을 MiniML 임베딩 + DeepSeek API로 검색/질의
3. **Tools**: JSONL 변환, 워딩 프로파일, MCP 생성, 언어 변환
4. **GitHub 백업** (선택): `parksy-logs` 레포 자동 푸시

---

## Requirements

| 항목 | 필수 | 비고 |
|------|------|------|
| Android 8.0+ (API 26) | ✅ | S25 Ultra / Tab S9 권장 |
| Termux | ✅ | Embed Server (:8018) 구동용 |
| Python 3.13+ (Termux) | ✅ | aiohttp + transformers + torch |
| DeepSeek API Key | 선택 | LLM Q&A 기능 사용 시 (`~/.config/deepseek.env`) |
| HuggingFace 모델 캐시 | ✅ | MiniLM-L6-v2 (로컬, 86.6MB) |

---

## Termux Setup (Embed Server)

APK의 AI 검색 기능은 Termux에서 실행되는 Embed Server (:8018)에 의존합니다.

### 1. Install Dependencies

```bash
pkg update && pkg upgrade
pkg install python ninja cmake build-essential rust
pip install aiohttp transformers torch sentencepiece sacremoses
```

### 2. Download MiniLM Model (Offline)

HuggingFace Hub의 rustls panic을 우회하기 위해 직접 다운로드:

```bash
HUB_DIR=~/.cache/huggingface/hub/models--sentence-transformers--all-MiniLM-L6-v2/snapshots/$(python3 -c "import uuid; print(uuid.uuid4().hex)")
mkdir -p "$HUB_DIR"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/pytorch_model.bin" -o "$HUB_DIR/pytorch_model.bin"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer.json" -o "$HUB_DIR/tokenizer.json"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer_config.json" -o "$HUB_DIR/tokenizer_config.json"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/config.json" -o "$HUB_DIR/config.json"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/special_tokens_map.json" -o "$HUB_DIR/special_tokens_map.json"
curl -L "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/vocab.txt" -o "$HUB_DIR/vocab.txt"
# SHA256 해시로 refs 설정
HASH=$(basename "$HUB_DIR")
mkdir -p ~/.cache/huggingface/hub/models--sentence-transformers--all-MiniLM-L6-v2/refs
echo "$HASH" > ~/.cache/huggingface/hub/models--sentence-transformers--all-MiniLM-L6-v2/refs/main
```

### 3. Set Up DeepSeek API Key (선택)

```bash
mkdir -p ~/.config
echo 'export DEEPSEEK_API_KEY=sk-your-key-here' > ~/.config/deepseek.env
```

키는 `~/.bashrc`에도 추가:
```bash
echo 'source ~/.config/deepseek.env' >> ~/.bashrc
```

### 4. Install Embed Server Script

```bash
# parksy_embed_server.py를 ~/에 배치 (별도 제공)
# 또는 직접 작성
nano ~/parksy_embed_server.py
```

스크립트 내용은 [ONDEVICE_UPGRADE_PLAN.md](./ONDEVICE_UPGRADE_PLAN.md) 참조.

### 5. Auto-Start (Termux Boot)

```bash
mkdir -p ~/.termux/boot
```

`~/.termux/boot/start_all_mcp.sh`:
```bash
#!/data/data/com.termux/files/usr/bin/bash
export PATH=$PATH:/data/data/com.termux/files/usr/bin
# Embed Server (:8018)
HF_HUB_OFFLINE=1 python3 ~/parksy_embed_server.py 8018 > /dev/null 2>&1 &
# 기타 MCP 서버
# voice(:8015), audio(:8016), publish(:8020), webpage(:8789)
```

`termux-boot` 활성화:
```bash
chmod +x ~/.termux/boot/start_all_mcp.sh
termux-wake-lock
```

---

## APK Build

### Debug Build (로컬)

```bash
cd apps/capture-pipeline
flutter build apk --debug
# 출력: build/app/outputs/flutter-apk/app-debug.apk
```

### Version Info

| 파일 | 필드 | 값 |
|------|------|-----|
| `pubspec.yaml` | `version` | `11.0.0+34` (권위 소스) |
| `android/local.properties` | `flutter.versionName` | `11.0.0` |
| `android/local.properties` | `flutter.versionCode` | `34` |

---

## Phone Test Checklist

### Test 1: Chrome Share
1. Chrome에서 텍스트 선택 → Share → Parksy Capture
2. Toast: "Saved locally ✅"
3. `Downloads/parksy-logs/ParksyLog_*.md` 확인

### Test 2: AI Search
1. Browse 탭 → 🔍 검색 아이콘
2. 키워드 검색: 로그 내용 전체 텍스트 검색
3. AI 검색 (Embed Server 필요):
   - 검색 모드 → "AI 검색" 전환
   - 질문 입력 → Embed Server (:8018) → DeepSeek 응답
   - Embed Server 미응답 시 자동 로컬 텍스트 검색 fallback

### Test 3: Tools
1. Tools 탭 → JSONL Converter
2. 로그 선택 → `.jsonl` 변환 확인
3. Wording Profiler → 단어 빈도 분석 확인

### Test 4: Embed Server Health
```bash
# Termux에서
curl -s http://localhost:8018/health
# → {"status": "ok", "models": ["minilm", "deepseek-chat"], "deepseek": true}
```

---

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| "AI 검색 실패" / "연결 오류" | Embed Server 꺼짐 | Termux에서 `python3 ~/parksy_embed_server.py 8018` 실행 |
| `rustls panic` | HuggingFace Hub Rust TLS | `HF_HUB_OFFLINE=1` 설정 + 로컬 캐시 직접 구성 |
| `HuggingFace Hub` 연결 오류 | offline 모드 미설정 | `export HF_HUB_OFFLINE=1` 환경변수 확인 |
| APK 설치 안됨 | Debug 서명 문제 | `adb install -r app-debug.apk` |
| "Save Failed ❌" | 저장소 권한 없음 | 앱 설정 → 권한 → 저장소 허용 |

---

## File Structure

```
apps/capture-pipeline/
├── lib/main.dart                 # Flutter UI (Capture/Browse/Tools/Settings)
├── android/.../MainActivity.kt   # Share handler + onDeviceSearch + Tools
├── docs/
│   ├── SETUP.md                  # This file
│   ├── ONDEVICE_UPGRADE_PLAN.md  # AI implementation details
│   ├── CAPTURE_V2_DEVPLAN.md     # Development history
│   └── CTO_HARDENING_REPORT.md   # Security audit
└── pubspec.yaml                  # version 11.0.0+34
```

---

## Architecture Overview

```
Share Intent → MainActivity.kt → Downloads/parksy-logs/*.md
                                    │
AI Search:                          │
  Flutter UI → MethodChannel → onDeviceSearch()
    → callMcpSearch() → POST localhost:8018/api/tool
      → Embed Server (Termux Python)
        ├── llm_generate → DeepSeek API (클라우드)
        └── embed_search → MiniLM L6-v2 (로컬, 384차원)
    → localTextSearch() (fallback, Kotlin native)

Tools:
  JSONL Converter → .md → .jsonl (conversation turns)
  Wording Profiler → 단어 빈도/패턴 분석
  MCP Generator → 프로파일 기반 MCP 스펙 생성
  Language Converter → 한국어 ↔ 영어 (ML Kit)
```
