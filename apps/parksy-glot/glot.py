#!/usr/bin/env python3
"""
glot.py — Parksy Glot v2.0 PC 오케스트레이터
실시간 다국어 자막: VB-Cable → Web Speech API → 번역 → WebSocket → 태블릿 Axis-shell WebView

Architecture:
    [아무 영상 재생] → VB-Cable → PC Chrome (Web Speech API, 무료)
    → 원어 STT → 한국어 번역 → 영어 번역
    → WebSocket 서버 → 태블릿 Glot APK (WebView)
    → 드래그/핀치 가능 오버레이 → scrcpy 캡처 → 영상에 찍힘

Usage:
    python3 glot.py                    # WebSocket 서버 시작 (포트 8765)
    python3 glot.py --port 8765        # 포트 지정
    python3 glot.py --lang ja          # 소스 언어 고정 (기본: 자동 감지)
"""

import asyncio
import argparse
import json
import datetime
import webbrowser
import http.server
import threading
import os
from pathlib import Path

# pip install websockets
try:
    import websockets
except ImportError:
    print("설치 필요: pip install websockets")
    exit(1)

# ─── 설정 ────────────────────────────────────────────────────────────────────

WS_PORT    = 8765       # WebSocket 서버 포트
HTTP_PORT  = 8766       # 컨트롤 페이지 HTTP 서버 포트
HOST       = "0.0.0.0"  # 태블릿에서 접속 가능하도록 전체 바인드

# ─── WebSocket 서버 ───────────────────────────────────────────────────────────

connected_clients = set()

async def ws_handler(websocket):
    """태블릿 Glot APK WebView 연결 처리"""
    connected_clients.add(websocket)
    client_ip = websocket.remote_address[0]
    print(f"[연결] {client_ip} — 현재 {len(connected_clients)}개 클라이언트")

    try:
        async for message in websocket:
            # 태블릿에서 오는 메시지 (컨트롤 신호 등)
            data = json.loads(message)
            print(f"[태블릿] {data}")
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        connected_clients.discard(websocket)
        print(f"[해제] {client_ip} — 현재 {len(connected_clients)}개 클라이언트")

async def broadcast(payload: dict):
    """모든 연결된 클라이언트에 자막 송출"""
    if not connected_clients:
        return
    msg = json.dumps(payload, ensure_ascii=False)
    await asyncio.gather(
        *[ws.send(msg) for ws in connected_clients],
        return_exceptions=True
    )

# ─── 컨트롤 페이지 (PC Chrome에서 열림) ─────────────────────────────────────

CONTROL_HTML = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<title>Parksy Glot — 컨트롤</title>
<style>
  body { background:#0a0a0a; color:#e0e0e0; font-family:monospace; padding:20px; }
  h2 { color:#D4AF37; }
  button { background:#1a1a1a; color:#D4AF37; border:1px solid #D4AF37;
           padding:10px 24px; font-size:16px; cursor:pointer; border-radius:6px; margin:8px; }
  button:hover { background:#D4AF37; color:#000; }
  button.active { background:#D4AF37; color:#000; }
  select { background:#1a1a1a; color:#e0e0e0; border:1px solid #444;
           padding:8px; font-size:14px; border-radius:4px; }
  #status { color:#888; margin:12px 0; font-size:13px; }
  #log { background:#111; border:1px solid #222; padding:12px;
         height:200px; overflow-y:auto; font-size:12px; color:#666; }
  .orig { color:#aaa; } .ko { color:#7ec8e3; } .en { color:#98d98e; }
</style>
</head>
<body>
<h2>🌐 Parksy Glot v2.0</h2>

<div>
  소스 언어:
  <select id="lang">
    <option value="">자동 감지</option>
    <option value="ja">일본어</option>
    <option value="en">영어</option>
    <option value="es">스페인어</option>
    <option value="zh">중국어</option>
    <option value="fr">프랑스어</option>
    <option value="de">독일어</option>
  </select>
</div>

<br>
<button id="btnStart" onclick="startCapture()">▶ 자막 시작</button>
<button onclick="stopCapture()">■ 중지</button>
<div id="status">대기 중...</div>

<div id="log"></div>

<script>
const WS_URL = 'ws://' + location.hostname + ':WSPORT';
let ws, recognition, isRunning = false;

// WebSocket 연결 (→ 자막 서버)
function connectWS() {
  ws = new WebSocket(WS_URL);
  ws.onopen  = () => log('서버 연결됨');
  ws.onclose = () => { log('서버 연결 끊김'); setTimeout(connectWS, 2000); };
}
connectWS();

// Web Speech API 시작
function startCapture() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) { alert('Web Speech API 미지원 브라우저'); return; }

  recognition = new SpeechRecognition();
  const lang = document.getElementById('lang').value;
  recognition.lang = lang || 'ja';   // 자동감지 미지원 시 일본어 기본
  recognition.continuous = true;
  recognition.interimResults = true;

  recognition.onresult = async (e) => {
    let interim = '', final = '';
    for (let i = e.resultIndex; i < e.results.length; i++) {
      const t = e.results[i][0].transcript;
      if (e.results[i].isFinal) final += t;
      else interim += t;
    }

    if (final) {
      const ko = await translate(final, 'ko');
      const en = await translate(ko, 'en');
      const payload = { type:'subtitle', orig:final, ko, en,
                        ts: new Date().toLocaleTimeString() };
      if (ws && ws.readyState === 1) ws.send(JSON.stringify(payload));
      log(`<span class=orig>${final}</span> → <span class=ko>${ko}</span> → <span class=en>${en}</span>`);
    }
  };

  recognition.onerror = (e) => log('오류: ' + e.error);
  recognition.onend   = () => { if (isRunning) recognition.start(); };

  isRunning = true;
  recognition.start();
  document.getElementById('btnStart').classList.add('active');
  document.getElementById('status').textContent = '🔴 캡처 중...';
}

function stopCapture() {
  isRunning = false;
  if (recognition) recognition.stop();
  document.getElementById('btnStart').classList.remove('active');
  document.getElementById('status').textContent = '대기 중...';
}

// 번역 (Google Translate 무료 엔드포인트)
async function translate(text, target) {
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${target}&dt=t&q=${encodeURIComponent(text)}`;
    const r = await fetch(url);
    const d = await r.json();
    return d[0].map(x => x[0]).join('');
  } catch { return text; }
}

function log(msg) {
  const el = document.getElementById('log');
  el.innerHTML += '<div>' + msg + '</div>';
  el.scrollTop = el.scrollHeight;
}
</script>
</body>
</html>
""".replace("WSPORT", str(WS_PORT))

SUBTITLE_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Glot Subtitles</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { background:transparent; overflow:hidden; touch-action:none; }

  #box {
    position:fixed; bottom:60px; left:50%; transform:translateX(-50%);
    background:rgba(0,0,0,0.75); border-radius:10px;
    padding:12px 18px; min-width:200px; max-width:90vw;
    text-align:center; cursor:grab;
    border:1px solid rgba(255,255,255,0.1);
  }
  #box:active { cursor:grabbing; }

  .orig { font-size:14px; color:#aaa; margin-bottom:4px; }
  .ko   { font-size:18px; color:#7ec8e3; font-weight:bold; margin-bottom:2px; }
  .en   { font-size:13px; color:#98d98e; }

  #resize-handle {
    position:absolute; bottom:4px; right:8px;
    color:#555; font-size:12px; cursor:se-resize;
  }
</style>
</head>
<body>
<div id="box">
  <div class="orig" id="orig">—</div>
  <div class="ko"   id="ko">자막 대기 중...</div>
  <div class="en"   id="en">waiting...</div>
  <span id="resize-handle">⤡</span>
</div>

<script>
// WebSocket 연결
const ws = new WebSocket('ws://PC_IP:WSPORT');
ws.onmessage = (e) => {
  const d = JSON.parse(e.data);
  if (d.type === 'subtitle') {
    document.getElementById('orig').textContent = d.orig;
    document.getElementById('ko').textContent   = d.ko;
    document.getElementById('en').textContent   = d.en;
  }
};

// 드래그
const box = document.getElementById('box');
let dragging = false, startX, startY, origLeft, origTop;

box.addEventListener('touchstart', e => {
  if (e.target.id === 'resize-handle') return;
  dragging = true;
  const t = e.touches[0];
  const r = box.getBoundingClientRect();
  startX = t.clientX - r.left;
  startY = t.clientY - r.top;
  box.style.transform = 'none';
  box.style.left = r.left + 'px';
  box.style.top  = r.top  + 'px';
  box.style.bottom = 'auto';
});

document.addEventListener('touchmove', e => {
  if (!dragging) return;
  e.preventDefault();
  const t = e.touches[0];
  box.style.left = (t.clientX - startX) + 'px';
  box.style.top  = (t.clientY - startY) + 'px';
}, { passive: false });

document.addEventListener('touchend', () => { dragging = false; });

// 핀치 줌 (폰트 크기)
let initDist = 0, baseFontKo = 18;
document.addEventListener('touchstart', e => {
  if (e.touches.length === 2) {
    initDist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    );
  }
});
document.addEventListener('touchmove', e => {
  if (e.touches.length === 2) {
    const dist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    );
    const scale = dist / initDist;
    const newSize = Math.max(10, Math.min(36, baseFontKo * scale));
    document.getElementById('ko').style.fontSize = newSize + 'px';
  }
});
document.addEventListener('touchend', e => {
  if (e.touches.length < 2) {
    baseFontKo = parseInt(document.getElementById('ko').style.fontSize) || 18;
  }
});
</script>
</body>
</html>
""".replace("WSPORT", str(WS_PORT))

# ─── HTTP 서버 (컨트롤 + 자막 페이지 서빙) ───────────────────────────────────

class GlotHTTPHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/control':
            self._serve(CONTROL_HTML)
        elif self.path == '/subtitle':
            # PC IP를 실제 IP로 교체해서 서빙
            local_ip = self._get_local_ip()
            html = SUBTITLE_HTML.replace("PC_IP", local_ip)
            self._serve(html)
        else:
            self.send_response(404); self.end_headers()

    def _serve(self, html):
        body = html.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def _get_local_ip(self):
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "localhost"

    def log_message(self, *args): pass  # 로그 억제

# ─── 메인 ────────────────────────────────────────────────────────────────────

async def main(args):
    # HTTP 서버 (별도 스레드)
    httpd = http.server.HTTPServer(("0.0.0.0", HTTP_PORT), GlotHTTPHandler)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()

    # WebSocket 서버
    print("=" * 55)
    print("  Parksy Glot v2.0 — PC 자막 서버")
    print(f"  컨트롤 페이지 → http://localhost:{HTTP_PORT}/control")
    print(f"  태블릿 자막   → http://[PC_IP]:{HTTP_PORT}/subtitle")
    print(f"  WebSocket     → ws://[PC_IP]:{WS_PORT}")
    print("=" * 55)

    # 컨트롤 페이지 자동으로 Chrome에서 열기
    webbrowser.open(f"http://localhost:{HTTP_PORT}/control")

    async with websockets.serve(ws_handler, HOST, args.port):
        print(f"\n[대기] WebSocket 서버 실행 중 (포트 {args.port})...")
        print("  1. PC Chrome 컨트롤 페이지에서 [▶ 자막 시작] 클릭")
        print("  2. 태블릿 Glot APK에서 위 URL 접속")
        print("  3. 아무 영상이나 재생 → 자막 자동 표시\n")
        await asyncio.Future()  # 무한 대기


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=WS_PORT)
    parser.add_argument("--lang", default="", help="소스 언어 (ja/en/es 등, 기본: 자동)")
    args = parser.parse_args()

    asyncio.run(main(args))
