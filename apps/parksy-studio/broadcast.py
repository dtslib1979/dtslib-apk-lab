#!/usr/bin/env python3
"""
broadcast.py — Parksy Studio v2.0 오케스트레이터
강의 영상 자동 제작 파이프라인: URL 오픈 → 녹화 → 인코딩 → YouTube 업로드

Usage:
    python3 broadcast.py --url https://example.com/lecture
    python3 broadcast.py --url https://example.com/lecture --title "강의 제목" --device 100.74.21.77:5555
"""

import argparse
import subprocess
import signal
import sys
import os
import time
import datetime
import json
from pathlib import Path

# ─── 설정 ────────────────────────────────────────────────────────────────────

TABLET_SERIAL   = "100.74.21.77:5555"   # SM-X716N Tab S9 FE (Tailscale IP)
OUTPUT_DIR      = Path.home() / "parksy-recordings"
FRAME_PNG       = Path(__file__).parent / "assets" / "broadcast" / "frame.png"
YT_SCRIPT       = Path(__file__).parent.parent.parent / "tools" / "youtube-studio.js"

# FFmpeg 설정
FFMPEG_BIN      = "ffmpeg.exe"          # Windows FFmpeg (WSL에서 호출)
SCRCPY_WINDOW   = "scrcpy"              # DirectShow 소스 이름 (scrcpy 창 타이틀)
VBCABLE_DEVICE  = "CABLE Output (VB-Audio Virtual Cable)"  # DirectShow 오디오
VIDEO_WIDTH     = 1920
VIDEO_HEIGHT    = 1080
VIDEO_FPS       = 30
VIDEO_BITRATE   = "4M"
AUDIO_BITRATE   = "192k"

# 태블릿 크롭 설정 (status bar / nav bar 제거)
# frame.png 콘텐츠 영역: x=42, y=58, w=1836, h=922
CROP_TOP        = 60    # status bar 높이 (px)
CROP_BOTTOM     = 60    # nav bar 높이 (px)

# frame.png 오버레이 파라미터 (1920×1080 칠판 액자)
# 콘텐츠 영역: x=42 y=58 w=1836 h=922 → 태블릿 크롭 후 이 영역에 스케일
FRAME_CONTENT_X = 42
FRAME_CONTENT_Y = 58
FRAME_CONTENT_W = 1836
FRAME_CONTENT_H = 922

# ─── 유틸 ────────────────────────────────────────────────────────────────────

def log(msg: str):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}")

def run_adb(serial: str, *args) -> str:
    cmd = ["adb", "-s", serial] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout.strip()

def win_path(wsl_path: Path) -> str:
    """WSL 경로 → Windows 경로 변환"""
    result = subprocess.run(["wslpath", "-w", str(wsl_path)], capture_output=True, text=True)
    return result.stdout.strip()

# ─── Phase 1: ADB intent → 태블릿 웹페이지 오픈 ─────────────────────────────

def phase1_open_url(serial: str, url: str):
    log(f"[Phase 1] 태블릿 URL 오픈: {url}")

    # 혹시 꺼진 화면 깨우기
    run_adb(serial, "shell", "input", "keyevent", "KEYCODE_WAKEUP")
    time.sleep(0.5)

    # 전체화면 인텐트 전송
    run_adb(serial, "shell",
        "am", "start",
        "-a", "android.intent.action.VIEW",
        "-d", url,
        "--activity-clear-top"
    )
    log("[Phase 1] ✅ URL 전송 완료 — 태블릿 브라우저 로딩 중...")
    time.sleep(3)  # 브라우저 로딩 대기


# ─── Phase 2: FFmpeg 녹화 시작 ───────────────────────────────────────────────

def phase2_start_recording(output_path: Path, frame_png: Path) -> subprocess.Popen:
    log(f"[Phase 2] FFmpeg 녹화 시작 → {output_path.name}")

    win_output = win_path(output_path)
    has_frame  = frame_png.exists()

    # FFmpeg 필터 구성
    # scrcpy 창 → 크롭 → 스케일 → 액자 오버레이 합성
    crop_filter = (
        f"crop=iw:ih-{CROP_TOP + CROP_BOTTOM}:0:{CROP_TOP},"
        f"scale={VIDEO_WIDTH}:{VIDEO_HEIGHT}:flags=lanczos"
    )

    if has_frame:
        win_frame = win_path(frame_png)
        filter_complex = (
            f"[0:v]{crop_filter}[tablet];"
            f"[1:v]scale={VIDEO_WIDTH}:{VIDEO_HEIGHT}[frame];"
            f"[frame][tablet]overlay=0:0[out]"
        )
        cmd = [
            FFMPEG_BIN, "-y",
            # 입력 1: scrcpy 화면 (DirectShow)
            "-f", "dshow", "-i", f"video={SCRCPY_WINDOW}",
            # 입력 2: 액자 PNG
            "-loop", "1", "-i", win_frame,
            # 입력 3: VB-Cable 오디오
            "-f", "dshow", "-i", f"audio={VBCABLE_DEVICE}",
            # 필터
            "-filter_complex", filter_complex,
            "-map", "[out]", "-map", "2:a",
            # 인코딩
            "-c:v", "libx264", "-preset", "fast", "-b:v", VIDEO_BITRATE,
            "-c:a", "aac", "-b:a", AUDIO_BITRATE,
            "-r", str(VIDEO_FPS),
            "-pix_fmt", "yuv420p",
            win_output
        ]
    else:
        # 액자 없이 크롭만
        log("[Phase 2] ⚠️  frame.png 없음 — 액자 없이 녹화 진행")
        cmd = [
            FFMPEG_BIN, "-y",
            "-f", "dshow", "-i", f"video={SCRCPY_WINDOW}",
            "-f", "dshow", "-i", f"audio={VBCABLE_DEVICE}",
            "-vf", crop_filter,
            "-c:v", "libx264", "-preset", "fast", "-b:v", VIDEO_BITRATE,
            "-c:a", "aac", "-b:a", AUDIO_BITRATE,
            "-r", str(VIDEO_FPS),
            "-pix_fmt", "yuv420p",
            win_output
        ]

    # WSL → Windows ffmpeg.exe 호출
    win_cmd = ["cmd.exe", "/c"] + cmd
    proc = subprocess.Popen(win_cmd, stdin=subprocess.PIPE)
    log("[Phase 2] ✅ 녹화 시작됨")
    return proc


# ─── Phase 3: 종료 신호 → FFmpeg flush ──────────────────────────────────────

def phase3_stop_recording(proc: subprocess.Popen, output_path: Path):
    log("[Phase 3] 녹화 종료 신호 전송 (FFmpeg SIGINT)...")

    # FFmpeg는 stdin 'q' 또는 SIGINT로 정상 종료 + flush
    try:
        proc.stdin.write(b"q")
        proc.stdin.flush()
    except Exception:
        pass

    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        log("[Phase 3] ⚠️  타임아웃 — 강제 종료")
        proc.kill()

    if output_path.exists():
        size_mb = output_path.stat().st_size / (1024 * 1024)
        log(f"[Phase 3] ✅ 녹화 완료 — {output_path.name} ({size_mb:.1f} MB)")
    else:
        log("[Phase 3] ❌ 출력 파일 없음 — FFmpeg 오류 확인 필요")
        sys.exit(1)


# ─── Phase 4: YouTube 자동 업로드 ───────────────────────────────────────────

def phase4_upload(output_path: Path, title: str, description: str = ""):
    log(f"[Phase 4] YouTube 업로드 시작: {title}")

    if not YT_SCRIPT.exists():
        log(f"[Phase 4] ⚠️  youtube-studio.js 없음: {YT_SCRIPT}")
        log("[Phase 4] 수동 업로드 필요")
        return

    win_video = win_path(output_path)
    win_script = win_path(YT_SCRIPT)

    meta = {
        "title": title,
        "description": description or f"Parksy Studio 자동 생성 — {datetime.date.today()}",
        "privacyStatus": "private",   # 기본 비공개 (검토 후 공개)
    }

    meta_json = json.dumps(meta, ensure_ascii=False)
    cmd = [
        "cmd.exe", "/c",
        "node", win_script,
        "--file", win_video,
        "--meta", meta_json
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        log("[Phase 4] ✅ YouTube 업로드 완료")
        log(result.stdout.strip())
    else:
        log("[Phase 4] ❌ 업로드 실패")
        log(result.stderr.strip())


# ─── 메인 ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Parksy Studio v2.0 — 강의 영상 자동 제작")
    parser.add_argument("--url",     required=True,  help="태블릿에 열 웹페이지 URL")
    parser.add_argument("--title",   default="",     help="YouTube 업로드 제목")
    parser.add_argument("--device",  default=TABLET_SERIAL, help="ADB 기기 serial (IP:PORT)")
    parser.add_argument("--no-upload", action="store_true", help="업로드 생략 (로컬 저장만)")
    args = parser.parse_args()

    title = args.title or f"Parksy Lecture {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"

    # 출력 경로 준비
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp   = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = OUTPUT_DIR / f"lecture_{timestamp}.mp4"

    ffmpeg_proc = None

    # Ctrl+C 처리
    def on_interrupt(sig, frame):
        log("\n[Ctrl+C] 종료 신호 수신")
        if ffmpeg_proc:
            phase3_stop_recording(ffmpeg_proc, output_path)
            if not args.no_upload:
                phase4_upload(output_path, title)
        sys.exit(0)

    signal.signal(signal.SIGINT, on_interrupt)

    # ── 실행 ──
    log("=" * 60)
    log("  Parksy Studio v2.0 — broadcast.py")
    log(f"  URL   : {args.url}")
    log(f"  Title : {title}")
    log(f"  Device: {args.device}")
    log(f"  Output: {output_path}")
    log("=" * 60)

    # ADB 연결 확인
    devices = subprocess.run(["adb", "devices"], capture_output=True, text=True).stdout
    if args.device not in devices:
        log(f"❌ ADB 기기 없음: {args.device}")
        log("   adb connect {IP}:5555 먼저 실행하세요")
        sys.exit(1)

    phase1_open_url(args.device, args.url)

    log("")
    log("📹 scrcpy가 실행 중이어야 합니다. (별도 터미널에서 실행)")
    log("   scrcpy --serial 100.74.21.77 --window-title scrcpy")
    log("")
    input("► REAPER와 scrcpy 준비되면 Enter를 눌러 녹화를 시작하세요...")

    ffmpeg_proc = phase2_start_recording(output_path, FRAME_PNG)

    log("")
    log("🔴 녹화 중... Ctrl+C 누르면 종료 후 자동 업로드")
    log("")

    try:
        ffmpeg_proc.wait()
    except KeyboardInterrupt:
        pass

    phase3_stop_recording(ffmpeg_proc, output_path)

    if not args.no_upload:
        phase4_upload(output_path, title)
    else:
        log(f"[완료] 파일 저장됨: {output_path}")


if __name__ == "__main__":
    main()
