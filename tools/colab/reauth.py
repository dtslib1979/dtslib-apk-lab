"""
Google OAuth 재인증 — drive.file + youtube + spreadsheets 스코프
refresh_token이 만료됐을 때만 실행
실행: python reauth.py
"""

import json
import os
import webbrowser
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
import requests
import threading

PAPYRUS = os.path.expanduser("~/dtslib-papyrus")
SECRET_PATH = f"{PAPYRUS}/tools/youtube/client_secret.json"
TOKEN_PATH  = f"{PAPYRUS}/tools/youtube/accounts/token_a.json"

SCOPES = [
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/yt-analytics.readonly",
    "https://www.googleapis.com/auth/spreadsheets"
]
REDIRECT_URI = "http://localhost:8765"

auth_code = None

class OAuthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        if "code" in params:
            auth_code = params["code"][0]
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"<h2>OK! 탭 닫아도 됩니다.</h2>")
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"error")

    def log_message(self, *args):
        pass

def main():
    with open(SECRET_PATH) as f:
        client = json.load(f)["installed"]

    # 인증 URL 생성
    auth_url = (
        "https://accounts.google.com/o/oauth2/v2/auth?"
        + urllib.parse.urlencode({
            "client_id":     client["client_id"],
            "redirect_uri":  REDIRECT_URI,
            "response_type": "code",
            "scope":         " ".join(SCOPES),
            "access_type":   "offline",
            "prompt":        "consent"
        })
    )

    print("🔐 Google 재인증 필요")
    print(f"\n브라우저 자동 열기... 안 열리면 아래 URL 복사해서 열기:")
    print(f"\n{auth_url}\n")
    webbrowser.open(auth_url)

    # 로컬 서버로 코드 수신
    server = HTTPServer(("localhost", 8765), OAuthHandler)
    print("⏳ 인증 대기 중... (localhost:8765)")
    server.handle_request()

    if not auth_code:
        print("❌ 인증 코드 없음")
        return

    # 코드 → 토큰 교환
    resp = requests.post("https://oauth2.googleapis.com/token", data={
        "code":          auth_code,
        "client_id":     client["client_id"],
        "client_secret": client["client_secret"],
        "redirect_uri":  REDIRECT_URI,
        "grant_type":    "authorization_code"
    })

    if resp.status_code != 200:
        print(f"❌ 토큰 교환 실패: {resp.json()}")
        return

    token_data = resp.json()

    # 기존 파일과 병합 (refresh_token 보존)
    existing = {}
    if os.path.exists(TOKEN_PATH):
        with open(TOKEN_PATH) as f:
            existing = json.load(f)

    existing.update(token_data)
    with open(TOKEN_PATH, "w") as f:
        json.dump(existing, f, indent=2)

    print(f"\n✅ 재인증 완료!")
    print(f"   스코프: {token_data.get('scope', '')}")
    print(f"   저장: {TOKEN_PATH}")
    print(f"\n이제 python upload_to_drive.py 실행하세요.")

if __name__ == "__main__":
    main()
