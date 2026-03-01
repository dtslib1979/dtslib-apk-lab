#!/data/data/com.termux/files/usr/bin/bash
# extract-apk.sh — APK 추출 + 디컴파일 자동화 (Tier 3)
#
# Termux 환경 전용. ADB 무선 연결 후 사용.
# jadx 대신 apktool 사용 (Termux에서 jadx JVM 이슈 회피).
#
# Usage:
#   ./scripts/extract-apk.sh <package_name>          # 추출 + 디컴파일
#   ./scripts/extract-apk.sh --list <keyword>        # 패키지 검색
#   ./scripts/extract-apk.sh --manifest <package>    # 매니페스트만
#   ./scripts/extract-apk.sh --connect <ip:port>     # ADB 연결
#
# 필수 패키지:
#   pkg install android-tools apktool
#
# 디컴파일 결과: ~/references/decompiled/<app-name>/

set -euo pipefail

# === 경로 설정 ===
REFS_DIR="$HOME/references"
APK_DIR="$REFS_DIR/apks"
DECOMPILE_DIR="$REFS_DIR/decompiled"

# === 색상 ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[X]${NC} $1"; }

# === 사전 조건 체크 ===
check_prereqs() {
    local missing=0

    if ! command -v adb &> /dev/null; then
        err "adb not found. Run: pkg install android-tools"
        missing=1
    fi

    if ! command -v apktool &> /dev/null; then
        warn "apktool not found. Run: pkg install apktool"
        warn "디컴파일 없이 APK 추출만 가능합니다."
    fi

    # ADB 연결 확인
    if ! adb devices 2>/dev/null | grep -q "device$"; then
        err "ADB 연결 없음. 먼저 연결하세요:"
        echo "  ./scripts/extract-apk.sh --connect <ip:port>"
        echo "  또는: adb pair <ip:port>  →  adb connect <ip:port>"
        if [ $missing -eq 1 ]; then exit 1; fi
        return 1
    fi

    return 0
}

# === ADB 연결 ===
cmd_connect() {
    local target="$1"
    log "ADB connecting to $target..."
    adb connect "$target"
    adb devices
}

# === 패키지 검색 ===
cmd_list() {
    local keyword="$1"
    log "패키지 검색: '$keyword'"
    adb shell pm list packages 2>/dev/null | grep -i "$keyword" | sed 's/package://' | sort
}

# === 매니페스트 추출 ===
cmd_manifest() {
    local pkg="$1"
    local name=$(echo "$pkg" | rev | cut -d. -f1 | rev)
    local tmp_dir="$APK_DIR/$name"

    mkdir -p "$tmp_dir"

    log "APK 경로 확인: $pkg"
    local apk_path
    apk_path=$(adb shell pm path "$pkg" 2>/dev/null | head -1 | sed 's/package://' | tr -d '\r')

    if [ -z "$apk_path" ]; then
        err "패키지를 찾을 수 없음: $pkg"
        exit 1
    fi

    log "APK 추출 중..."
    adb pull "$apk_path" "$tmp_dir/base.apk"

    if command -v apktool &> /dev/null; then
        log "매니페스트 디코딩 중..."
        apktool d -f -s "$tmp_dir/base.apk" -o "$tmp_dir/decoded" 2>/dev/null
        cat "$tmp_dir/decoded/AndroidManifest.xml"
    else
        warn "apktool 없음. aapt로 대체 시도..."
        if command -v aapt &> /dev/null; then
            aapt dump xmltree "$tmp_dir/base.apk" AndroidManifest.xml
        else
            err "apktool/aapt 모두 없음. 매니페스트 디코딩 불가."
        fi
    fi
}

# === 전체 추출 + 디컴파일 ===
cmd_extract() {
    local pkg="$1"
    local name=$(echo "$pkg" | rev | cut -d. -f1 | rev)

    mkdir -p "$APK_DIR/$name"
    mkdir -p "$DECOMPILE_DIR"

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  APK EXTRACTION: $pkg${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # Step 1: APK 경로 찾기
    log "Step 1/4: APK 경로 확인"
    local paths
    paths=$(adb shell pm path "$pkg" 2>/dev/null | sed 's/package://' | tr -d '\r')

    if [ -z "$paths" ]; then
        err "패키지를 찾을 수 없음: $pkg"
        echo "패키지명 확인: ./scripts/extract-apk.sh --list <keyword>"
        exit 1
    fi

    echo "  $paths"

    # Step 2: APK 파일 추출
    log "Step 2/4: APK 추출 중..."
    echo "$paths" | while IFS= read -r p; do
        local filename=$(basename "$p")
        adb pull "$p" "$APK_DIR/$name/$filename" 2>/dev/null
        local size=$(du -h "$APK_DIR/$name/$filename" 2>/dev/null | cut -f1)
        echo "  → $APK_DIR/$name/$filename ($size)"
    done

    # Step 3: apktool 디컴파일
    if command -v apktool &> /dev/null; then
        log "Step 3/4: apktool 디컴파일 중..."
        apktool d -f "$APK_DIR/$name/base.apk" -o "$DECOMPILE_DIR/$name" 2>/dev/null
        log "  → $DECOMPILE_DIR/$name/"
    else
        warn "Step 3/4: apktool 미설치 — 스킵"
        warn "  설치: pkg install apktool"
    fi

    # Step 4: 구조 요약
    log "Step 4/4: 구조 분석"
    if [ -d "$DECOMPILE_DIR/$name" ]; then
        echo ""
        echo "  AndroidManifest.xml:"
        if [ -f "$DECOMPILE_DIR/$name/AndroidManifest.xml" ]; then
            # 권한 추출
            grep -oP 'android:name="\K[^"]*permission[^"]*' "$DECOMPILE_DIR/$name/AndroidManifest.xml" 2>/dev/null | head -10 | while read perm; do
                echo "    - $perm"
            done
            # Activity 추출
            echo "  Activities:"
            grep -oP 'android:name="\K[^"]*Activity[^"]*' "$DECOMPILE_DIR/$name/AndroidManifest.xml" 2>/dev/null | head -10 | while read act; do
                echo "    - $act"
            done
            # Intent Filter 추출
            echo "  Intent Filters:"
            grep -c '<intent-filter' "$DECOMPILE_DIR/$name/AndroidManifest.xml" 2>/dev/null | xargs -I{} echo "    {} 개 발견"
        fi

        echo ""
        echo "  디렉토리 구조:"
        find "$DECOMPILE_DIR/$name" -maxdepth 2 -type d 2>/dev/null | head -20 | sed "s|$DECOMPILE_DIR/$name|  .|"

        echo ""
        local total_files=$(find "$DECOMPILE_DIR/$name" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sh "$DECOMPILE_DIR/$name" 2>/dev/null | cut -f1)
        log "총 $total_files 파일, $total_size"
    fi

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}  완료: $DECOMPILE_DIR/$name/${NC}"
    echo -e "${CYAN}========================================${NC}"

    # 증빙 기록 (매니페스트 JSON)
    if [ -f "$DECOMPILE_DIR/$name/AndroidManifest.xml" ]; then
        local audit_file="$DECOMPILE_DIR/$name/.extraction-audit.json"
        cat > "$audit_file" << AUDIT_EOF
{
  "package": "$pkg",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tool": "extract-apk.sh",
  "purpose": "structure_reference_only",
  "code_copied": false,
  "notes": "Tier 3 참조용. 코드 복사 금지. 개념/구조만 참고."
}
AUDIT_EOF
        log "감사 증빙 생성: $audit_file"
    fi
}

# === 메인 ===
case "${1:-}" in
    --connect)
        [ -z "${2:-}" ] && { err "Usage: $0 --connect <ip:port>"; exit 1; }
        cmd_connect "$2"
        ;;
    --list)
        [ -z "${2:-}" ] && { err "Usage: $0 --list <keyword>"; exit 1; }
        check_prereqs || true
        cmd_list "$2"
        ;;
    --manifest)
        [ -z "${2:-}" ] && { err "Usage: $0 --manifest <package>"; exit 1; }
        check_prereqs
        cmd_manifest "$2"
        ;;
    --help|-h|"")
        echo "APK Extraction Tool (Termux)"
        echo ""
        echo "Usage:"
        echo "  $0 <package_name>          추출 + 디컴파일 (apktool)"
        echo "  $0 --list <keyword>        패키지 검색"
        echo "  $0 --manifest <package>    매니페스트만 추출"
        echo "  $0 --connect <ip:port>     ADB 무선 연결"
        echo ""
        echo "Examples:"
        echo "  $0 com.samsung.android.callrecording"
        echo "  $0 --list samsung.call"
        echo "  $0 --manifest com.example.app"
        echo ""
        echo "Prerequisites:"
        echo "  pkg install android-tools apktool"
        echo ""
        echo "Output: ~/references/decompiled/<app-name>/"
        echo "Note: jadx → apktool 대체 (Termux JVM 호환성)"
        ;;
    *)
        check_prereqs
        cmd_extract "$1"
        ;;
esac
