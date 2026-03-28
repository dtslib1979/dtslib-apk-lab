"""
PC Launch Server — 태블릿 ADB 런처 백엔드
태블릿에서 HTTP 요청 → Windows PC 프로그램 실행 / Excel win32com 작업

포트: 7777
실행: python server.py  (Windows PowerShell / cmd에서)
ADB: adb reverse tcp:7777 tcp:7777 (WSL에서 먼저 실행)

엔드포인트:
  GET /apps               → 앱 목록 + 설치 여부
  GET /launch?app=ID      → 프로그램 실행 (Popen)
  GET /task?id=TASK_ID    → Excel win32com 작업 실행 (화면에 그대로 보임)
  GET /tasks              → 사용 가능한 작업 목록
"""

import subprocess
import json
import os
import threading
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
    "outlook": {
        "name": "Outlook",
        "exe": r"C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "icon": "📧",
        "category": "office",
    },
    "onenote": {
        "name": "OneNote",
        "exe": r"C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE",
        "icon": "📓",
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

# ─── win32com Excel 작업 목록 ──────────────────────────────────────────────
EXCEL_TASKS = {
    "pivot_demo": {
        "name": "매출 피벗 테이블",
        "desc": "12행 매출 데이터 입력 → 피벗 테이블 생성",
        "icon": "📊",
        "duration": "약 30초",
    },
    "chart_demo": {
        "name": "월별 매출 차트",
        "desc": "월별 데이터 입력 → 막대+꺾은선 혼합 차트",
        "icon": "📈",
        "duration": "약 20초",
    },
    "formula_demo": {
        "name": "성과 분석 + 조건부 서식",
        "desc": "담당자별 실적 → 달성률 수식 → 컬러스케일",
        "icon": "🎨",
        "duration": "약 25초",
    },
}

# 실행 중인 작업 상태 추적
_running_task = {"id": None, "status": "idle"}


def _run_excel_task_bg(task_id):
    """백그라운드에서 Excel 작업 실행 (서버 블로킹 방지)"""
    _running_task["id"] = task_id
    _running_task["status"] = "running"
    try:
        from tasks.excel_tasks import run_task
        result = run_task(task_id)
        _running_task["status"] = "done"
        _running_task["result"] = result
    except ImportError:
        _running_task["status"] = "error"
        _running_task["result"] = {"ok": False, "error": "win32com not available (Windows only)"}
    except Exception as e:
        _running_task["status"] = "error"
        _running_task["result"] = {"ok": False, "error": str(e)}


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

        # ── GET /launch?app=ID → 프로그램 실행 ───────────────────────────
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

        # ── GET /tasks → Excel 작업 목록 ─────────────────────────────────
        if parsed.path == "/tasks":
            result = [
                {"id": tid, **info}
                for tid, info in EXCEL_TASKS.items()
            ]
            self.send_json(200, {"tasks": result, "running": _running_task})
            return

        # ── GET /task?id=TASK_ID → Excel win32com 작업 실행 ──────────────
        if parsed.path == "/task":
            task_id = qs.get("id", [None])[0]
            if not task_id or task_id not in EXCEL_TASKS:
                self.send_json(404, {"error": f"Unknown task: {task_id}"})
                return

            if _running_task["status"] == "running":
                self.send_json(409, {"error": "이미 작업 실행 중", "running": _running_task["id"]})
                return

            # 백그라운드 실행 (HTTP 응답 먼저 보내고 Excel 작업)
            t = threading.Thread(target=_run_excel_task_bg, args=(task_id,), daemon=True)
            t.start()

            task_info = EXCEL_TASKS[task_id]
            print(f"  ▶ Task started: {task_info['name']}")
            self.send_json(200, {
                "ok": True,
                "task": task_id,
                "name": task_info["name"],
                "status": "started",
                "duration": task_info["duration"],
            })
            return

        # ── GET /task-status → 작업 상태 확인 ────────────────────────────
        if parsed.path == "/task-status":
            self.send_json(200, _running_task)
            return

        # ── GET / → 헬스체크 ─────────────────────────────────────────────
        if parsed.path == "/":
            self.send_json(200, {"status": "PC Launch Server running", "port": PORT})
            return

        self.send_json(404, {"error": "Not found"})


if __name__ == "__main__":
    print(f"🚀 PC Launch Server — port {PORT}")
    print(f"   앱 목록:     http://localhost:{PORT}/apps")
    print(f"   앱 실행:     http://localhost:{PORT}/launch?app=reaper")
    print(f"   작업 목록:   http://localhost:{PORT}/tasks")
    print(f"   작업 실행:   http://localhost:{PORT}/task?id=pivot_demo")
    print(f"   작업 상태:   http://localhost:{PORT}/task-status")
    print(f"   ADB 셋업:    adb reverse tcp:{PORT} tcp:{PORT}")
    print()
    server = HTTPServer(("0.0.0.0", PORT), LaunchHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료")
