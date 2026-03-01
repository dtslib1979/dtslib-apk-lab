#!/data/data/com.termux/files/usr/bin/bash
# source-pool-clone.sh — F-Droid 참조 소스 일괄 clone
#
# source-map.json에 등록된 모든 Tier 1 레포를 ~/references/fdroid/에 clone.
# 이미 clone된 레포는 pull로 업데이트.
#
# Usage:
#   ./scripts/source-pool-clone.sh              # 전체 clone/update
#   ./scripts/source-pool-clone.sh --shallow     # shallow clone (용량 절약)
#   ./scripts/source-pool-clone.sh <repo-name>   # 특정 레포만

set -euo pipefail

REFS_DIR="$HOME/references"
FDROID_DIR="$REFS_DIR/fdroid"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[X]${NC} $1"; }

# === F-Droid 참조 레포 목록 ===
# 형식: "이름|URL|라이선스|Parksy 앱"
REPOS=(
    "ringdroid|https://github.com/nicenoise/ringdroid|Apache-2.0|parksy-wavesy"
    "sherpa-onnx|https://github.com/k2-fsa/sherpa-onnx|Apache-2.0|chrono-call,tts-factory"
    "transcribro|https://github.com/soupslurpr/Transcribro|Apache-2.0|chrono-call"
    "whisper-keyboard|https://github.com/woheller69/whisperkeyboard|Apache-2.0|chrono-call"
    "clipboard-cleaner|https://github.com/nicenoise/clipboard-cleaner|MIT|capture-pipeline"
)

# === clone 또는 update ===
clone_or_update() {
    local name="$1"
    local url="$2"
    local license="$3"
    local parksy_app="$4"
    local shallow="${5:-false}"
    local target="$FDROID_DIR/$name"

    echo ""
    log "$name ($license) → $parksy_app"

    if [ -d "$target/.git" ]; then
        # 이미 있으면 pull
        log "  기존 clone 발견. git pull..."
        (cd "$target" && git pull --ff-only 2>/dev/null) || warn "  pull 실패 (네트워크?). 기존 상태 유지."
        local size=$(du -sh "$target" 2>/dev/null | cut -f1)
        log "  → $target ($size)"
    else
        # 새로 clone
        if [ "$shallow" = "true" ]; then
            log "  shallow clone (--depth 1)..."
            git clone --depth 1 "$url" "$target" 2>/dev/null || {
                err "  clone 실패: $url"
                return 1
            }
        else
            log "  full clone..."
            git clone "$url" "$target" 2>/dev/null || {
                err "  clone 실패: $url"
                return 1
            }
        fi
        local size=$(du -sh "$target" 2>/dev/null | cut -f1)
        log "  → $target ($size)"
    fi

    # 라이선스 검증
    if [ -f "$target/LICENSE" ] || [ -f "$target/LICENSE.md" ] || [ -f "$target/LICENSE.txt" ]; then
        local lic_file=$(ls "$target"/LICENSE* 2>/dev/null | head -1)
        if grep -qi "$license" "$lic_file" 2>/dev/null; then
            log "  라이선스 확인: $license"
        else
            warn "  라이선스 불일치! 예상: $license, 파일 내용 확인 필요"
        fi
    else
        warn "  LICENSE 파일 없음! 수동 확인 필요: $url"
    fi
}

# === 메인 ===
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  F-DROID SOURCE POOL CLONE${NC}"
echo -e "${CYAN}========================================${NC}"

# 사전 조건
if ! command -v git &> /dev/null; then
    err "git not found. Run: pkg install git"
    exit 1
fi

mkdir -p "$FDROID_DIR"

# 인수 파싱
SHALLOW="false"
TARGET=""
for arg in "$@"; do
    case "$arg" in
        --shallow) SHALLOW="true" ;;
        --help|-h)
            echo "F-Droid Source Pool Clone"
            echo ""
            echo "Usage:"
            echo "  $0                    전체 clone/update"
            echo "  $0 --shallow          shallow clone (용량 절약)"
            echo "  $0 <repo-name>        특정 레포만"
            echo ""
            echo "Registered repos:"
            for repo in "${REPOS[@]}"; do
                IFS='|' read -r name url lic app <<< "$repo"
                echo "  $name ($lic) → $app"
            done
            exit 0
            ;;
        *) TARGET="$arg" ;;
    esac
done

# clone 실행
SUCCESS=0
FAIL=0

for repo in "${REPOS[@]}"; do
    IFS='|' read -r name url license parksy_app <<< "$repo"

    # 특정 타겟 필터
    if [ -n "$TARGET" ] && [ "$name" != "$TARGET" ]; then
        continue
    fi

    if clone_or_update "$name" "$url" "$license" "$parksy_app" "$SHALLOW"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
done

# 요약
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "  결과: ${GREEN}$SUCCESS 성공${NC}, ${RED}$FAIL 실패${NC}"
if [ -d "$FDROID_DIR" ]; then
    local_total=$(du -sh "$FDROID_DIR" 2>/dev/null | cut -f1)
    echo -e "  총 용량: $local_total"
fi
echo -e "${CYAN}========================================${NC}"
echo ""

# source-map.json 타임스탬프 업데이트
if [ -f "$REFS_DIR/source-map.json" ]; then
    # updated 필드 갱신 (sed로 간단히)
    sed -i "s/\"updated\": \".*\"/\"updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$REFS_DIR/source-map.json" 2>/dev/null
    log "source-map.json 타임스탬프 갱신"
fi

exit $FAIL
