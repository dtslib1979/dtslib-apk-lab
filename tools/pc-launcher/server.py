"""
PC Launch Server — 태블릿 ADB 런처 백엔드
태블릿에서 HTTP 요청 → Windows PC 프로그램 실행

포트: 7777
실행: python server.py  (Windows PowerShell / cmd에서)
ADB: adb reverse tcp:7777 tcp:7777 (WSL에서 먼저 실행)
"""

import subprocess
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 7777

# ─── PC에 설치된 프로그램 매핑 ─────────────────────────────────────────────
APPS = {
    # ── DAW / 음악 제작 ──────────────────────────────────────────────────
    "reaper": {
        "name": "REAPER",
        "exe": r"C:\Program Files\REAPER (x64)\reaper.exe",
        "icon": "🎛️",
        "category": "daw",
    },
    "pianoteq": {
        "name": "Pianoteq 9",
        "exe": r"C:\Program Files\Modartt\Pianoteq 9\Pianoteq 9.exe",
        "icon": "🎹",
        "category": "daw",
    },
    "focusrite": {
        "name": "Focusrite Control",
        "exe": r"C:\Program Files\Focusrite\Focusrite Control\Focusrite Control.exe",
        "icon": "🎚️",
        "category": "daw",
    },
    "spitfire": {
        "name": "Spitfire Audio",
        "exe": r"C:\Program Files\Spitfire Audio\Spitfire Audio.exe",
        "icon": "🎻",
        "category": "daw",
    },
    # ── Microsoft Office ─────────────────────────────────────────────────
    "excel": {
        "name": "Excel",
        "exe": r"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE",
        "icon": "📊",
        "category": "office",
    },
    "word": {
        "name": "Word",
        "exe": r"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
        "icon": "📄",
        "category": "office",
    },
    "powerpoint": {
        "name": "PowerPoint",
        "exe": r"C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE",
        "icon": "📽️",
        "category": "office",
    },
    # ── 브라우저 / 네트워크 ───────────────────────────────────────────────
    "chrome": {
        "name": "Chrome",
        "exe": r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        "icon": "🌐",
        "category": "browser",
    },
    "filezilla": {
        "name": "FileZilla",
        "exe": r"C:\Program Files\FileZilla FTP Client\filezilla.exe",
        "icon": "📡",
        "category": "browser",
    },
    # ── 원격 제어 ─────────────────────────────────────────────────────────
    "rustdesk": {
        "name": "RustDesk",
        "exe": r"C:\Program Files\RustDesk\rustdesk.exe",
        "icon": "🖥️",
        "category": "remote",
    },
}


class LaunchHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[{self.address_string()}] {fmt % args}")

    def send_json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        # ── GET /apps → 앱 목록 ──────────────────────────────────────────
        if parsed.path == "/apps":
            result = []
            for app_id, info in APPS.items():
                exists = os.path.exists(info["exe"])
                result.append({
                    "id": app_id,
                    "name": info["name"],
                    "icon": info["icon"],
                    "category": info["category"],
                    "available": exists,
                })
            self.send_json(200, {"apps": result})
            return

        # ── GET /launch?app=ID → 실행 ────────────────────────────────────
        if parsed.path == "/launch":
            app_id = qs.get("app", [None])[0]
            if not app_id or app_id not in APPS:
                self.send_json(404, {"error": f"Unknown app: {app_id}"})
                return

            info = APPS[app_id]
            exe = info["exe"]

            if not os.path.exists(exe):
                self.send_json(404, {"error": f"Not found: {exe}"})
                return

            try:
                subprocess.Popen(
                    [exe],
                    creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
                    close_fds=True,
                )
                print(f"  ✅ Launched: {info['name']}")
                self.send_json(200, {"ok": True, "launched": info["name"]})
            except Exception as e:
                print(f"  ❌ Failed: {e}")
                self.send_json(500, {"error": str(e)})
            return

        # ── GET / → 헬스체크 ─────────────────────────────────────────────
        if parsed.path == "/":
            self.send_json(200, {"status": "PC Launch Server running", "port": PORT})
            return

        self.send_json(404, {"error": "Not found"})


if __name__ == "__main__":
    print(f"🚀 PC Launch Server — port {PORT}")
    print(f"   태블릿에서: http://localhost:{PORT}/launch?app=reaper")
    print(f"   앱 목록:    http://localhost:{PORT}/apps")
    print(f"   ADB 셋업:   adb reverse tcp:{PORT} tcp:{PORT}")
    print()
    server = HTTPServer(("0.0.0.0", PORT), LaunchHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료")
