"""
ComfyUI 노트북 → Google Drive 업로드
토큰: dtslib-papyrus/tools/youtube/accounts/token_a.json (drive.file 스코프)
실행: python upload_to_drive.py
"""

import json
import os
import requests

PAPYRUS = os.path.expanduser("~/dtslib-papyrus")
SECRET_PATH = f"{PAPYRUS}/tools/youtube/client_secret.json"
TOKEN_PATH  = f"{PAPYRUS}/tools/youtube/accounts/token_a.json"
NOTEBOOK    = os.path.join(os.path.dirname(__file__), "comfyui_batch.ipynb")

def load_credentials():
    with open(SECRET_PATH) as f:
        client = json.load(f)["installed"]
    with open(TOKEN_PATH) as f:
        token = json.load(f)
    return client, token

def refresh_token(client, token):
    print("🔄 액세스 토큰 갱신 중...")
    resp = requests.post("https://oauth2.googleapis.com/token", data={
        "client_id":     client["client_id"],
        "client_secret": client["client_secret"],
        "refresh_token": token.get("drive_refresh_token", token["refresh_token"]),
        "grant_type":    "refresh_token"
    })
    if resp.status_code != 200:
        raise RuntimeError(
            f"토큰 갱신 실패 ({resp.status_code}): {resp.json()}\n"
            "→ re-auth 필요: python reauth.py"
        )
    new_access = resp.json()["access_token"]
    token["access_token"] = new_access
    with open(TOKEN_PATH, "w") as f:
        json.dump(token, f, indent=2)
    print("✅ 토큰 갱신 완료")
    return new_access

def upload_notebook(access_token):
    print(f"📤 업로드 중: {NOTEBOOK}")
    metadata = {
        "name": "ComfyUI_Batch_Parksy.ipynb",
        "mimeType": "application/vnd.google.colab"
    }
    with open(NOTEBOOK, "rb") as nb:
        resp = requests.post(
            "https://www.googleapis.com/upload/drive/v3/files"
            "?uploadType=multipart&fields=id,name,webViewLink",
            headers={"Authorization": f"Bearer {access_token}"},
            files={
                "metadata": (None, json.dumps(metadata), "application/json"),
                "file":     (None, nb, "application/octet-stream")
            }
        )
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"업로드 실패 ({resp.status_code}): {resp.json()}")
    return resp.json()

if __name__ == "__main__":
    client, token = load_credentials()
    access_token = refresh_token(client, token)
    result = upload_notebook(access_token)

    file_id = result.get("id")
    colab_url = f"https://colab.research.google.com/drive/{file_id}"

    print()
    print("=" * 60)
    print(f"✅ 업로드 성공!")
    print(f"   파일명: {result.get('name')}")
    print(f"   파일ID: {file_id}")
    print()
    print(f"🔗 Colab 실행 URL:")
    print(f"   {colab_url}")
    print()
    print("📋 사용법:")
    print("   1. 위 URL 태블릿/폰 브라우저에서 열기")
    print("   2. 런타임 유형 → GPU (T4) 확인")
    print("   3. 런타임 → 모두 실행 (Ctrl+F9)")
    print("   4. Google Drive 마운트 허용")
    print("   5. MyDrive/ComfyUI_Batch/prompts.txt 수정 후 재실행")
    print("   6. 결과: MyDrive/ComfyUI_Batch/output/ 폴더")
    print("=" * 60)
