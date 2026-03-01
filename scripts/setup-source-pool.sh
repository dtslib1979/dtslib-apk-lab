#!/data/data/com.termux/files/usr/bin/bash
# setup-source-pool.sh — 소스풀 디렉토리 구조 초기화
#
# ~/references/ 하위에 3-Tier 구조를 생성하고
# .gitignore를 설정하여 decompiled 코드가 git에 올라가지 않게 한다.
#
# Usage:
#   ./scripts/setup-source-pool.sh           # 구조 생성
#   ./scripts/setup-source-pool.sh --status  # 현황 출력
#   ./scripts/setup-source-pool.sh --clean   # decompiled 정리

set -euo pipefail

REFS_DIR="$HOME/references"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# === 디렉토리 구조 생성 ===
cmd_setup() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  SOURCE POOL SETUP${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # Tier 1: F-Droid 오픈소스 풀
    mkdir -p "$REFS_DIR/fdroid"
    log "Tier 1: $REFS_DIR/fdroid/"

    # Tier 2: 삼성 공식 SDK
    mkdir -p "$REFS_DIR/samsung"
    log "Tier 2: $REFS_DIR/samsung/"

    # Tier 3: 디컴파일 참조 (git 제외)
    mkdir -p "$REFS_DIR/decompiled"
    log "Tier 3: $REFS_DIR/decompiled/"

    # APK 임시 저장
    mkdir -p "$REFS_DIR/apks"
    log "APKs:   $REFS_DIR/apks/"

    # .gitignore — decompiled와 apks는 git에 올리지 않음
    cat > "$REFS_DIR/.gitignore" << 'GITIGNORE_EOF'
# Tier 3 디컴파일 결과 — 코드 복사 금지, 로컬 참조 전용
decompiled/

# APK 바이너리 — 임시 파일
apks/

# OS/IDE
.DS_Store
*.iml
.idea/
GITIGNORE_EOF
    log ".gitignore 생성 (decompiled/, apks/ 제외)"

    # README
    cat > "$REFS_DIR/README.md" << 'README_EOF'
# Parksy Source Pool

오픈소스 참조 소스 풀. 자세한 내용은 백서 참고:
`dtslib-apk-lab/docs/SOURCE_POOL_SCM_WHITEPAPER.md`

## 구조

```
references/
├── fdroid/          # Tier 1: F-Droid 오픈소스 (git clone)
├── samsung/         # Tier 2: 삼성 공식 SDK 샘플
├── decompiled/      # Tier 3: 구조 참조용 (.gitignore)
└── apks/            # APK 임시 저장 (.gitignore)
```

## 규칙

1. fdroid/ — clone만. fork 금지. 수정 금지.
2. decompiled/ — 구조 참조만. 코드 복사 절대 금지.
3. 새 참조 추가 시 source-pool-clone.sh에 등록.
README_EOF
    log "README.md 생성"

    # 소스맵 매니페스트 (JSON)
    cat > "$REFS_DIR/source-map.json" << 'MAP_EOF'
{
  "description": "Parksy 앱별 참조 소스 매핑",
  "updated": "",
  "tier1_fdroid": {
    "ringdroid": {
      "repo": "https://github.com/nicenoise/ringdroid",
      "license": "Apache-2.0",
      "parksy_app": "parksy-wavesy",
      "reference_points": ["waveform editing", "audio trimming", "ringtone creation"]
    },
    "sherpa-onnx": {
      "repo": "https://github.com/k2-fsa/sherpa-onnx",
      "license": "Apache-2.0",
      "parksy_app": ["chrono-call", "tts-factory"],
      "reference_points": ["on-device STT", "TTS", "speaker diarization", "VAD"]
    },
    "transcribro": {
      "repo": "https://github.com/soupslurpr/Transcribro",
      "license": "Apache-2.0",
      "parksy_app": "chrono-call",
      "reference_points": ["whisper.cpp integration", "transcription pipeline"]
    },
    "whisper-ime": {
      "repo": "https://github.com/woheller69/whisperkeyboard",
      "license": "Apache-2.0",
      "parksy_app": "chrono-call",
      "reference_points": ["on-device whisper", "keyboard integration"]
    }
  },
  "tier2_samsung": {
    "spen-sdk": {
      "source": "developer.samsung.com",
      "parksy_app": "laser-pen-overlay",
      "reference_points": ["pen pressure", "gesture", "overlay"]
    }
  }
}
MAP_EOF
    log "source-map.json 생성 (참조 매핑)"

    echo ""
    echo -e "${GREEN}  소스풀 초기화 완료.${NC}"
    echo -e "  다음: ./scripts/source-pool-clone.sh 로 F-Droid 소스 clone"
    echo ""
}

# === 현황 출력 ===
cmd_status() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  SOURCE POOL STATUS${NC}"
    echo -e "${CYAN}========================================${NC}"

    # Tier 1
    echo ""
    echo "Tier 1: F-Droid ($REFS_DIR/fdroid/)"
    if [ -d "$REFS_DIR/fdroid" ]; then
        local count=$(find "$REFS_DIR/fdroid" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        echo "  $count repos cloned"
        find "$REFS_DIR/fdroid" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read d; do
            local name=$(basename "$d")
            local size=$(du -sh "$d" 2>/dev/null | cut -f1)
            echo "  - $name ($size)"
        done
    else
        warn "  디렉토리 없음. setup-source-pool.sh 실행 필요."
    fi

    # Tier 2
    echo ""
    echo "Tier 2: Samsung SDK ($REFS_DIR/samsung/)"
    if [ -d "$REFS_DIR/samsung" ]; then
        local count=$(find "$REFS_DIR/samsung" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        echo "  $count items"
    else
        echo "  (없음)"
    fi

    # Tier 3
    echo ""
    echo "Tier 3: Decompiled ($REFS_DIR/decompiled/)"
    if [ -d "$REFS_DIR/decompiled" ]; then
        local count=$(find "$REFS_DIR/decompiled" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        echo "  $count apps decompiled"
        find "$REFS_DIR/decompiled" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read d; do
            local name=$(basename "$d")
            local size=$(du -sh "$d" 2>/dev/null | cut -f1)
            echo "  - $name ($size)"
        done
    else
        echo "  (없음)"
    fi

    # 총 용량
    echo ""
    if [ -d "$REFS_DIR" ]; then
        local total=$(du -sh "$REFS_DIR" 2>/dev/null | cut -f1)
        echo "총 소스풀 용량: $total"
    fi
    echo ""
}

# === decompiled 정리 ===
cmd_clean() {
    if [ -d "$REFS_DIR/decompiled" ]; then
        local size=$(du -sh "$REFS_DIR/decompiled" 2>/dev/null | cut -f1)
        warn "decompiled/ 삭제: $size"
        rm -rf "$REFS_DIR/decompiled"
        mkdir -p "$REFS_DIR/decompiled"
        log "정리 완료."
    else
        log "정리할 것 없음."
    fi
}

# === 메인 ===
case "${1:-}" in
    --status)  cmd_status ;;
    --clean)   cmd_clean ;;
    --help|-h)
        echo "Source Pool Setup (Termux)"
        echo ""
        echo "Usage:"
        echo "  $0               디렉토리 구조 초기화"
        echo "  $0 --status      소스풀 현황"
        echo "  $0 --clean       decompiled/ 정리"
        ;;
    *)         cmd_setup ;;
esac
