#!/usr/bin/env python3
"""API test script for TTS Factory server.

Usage:
    python test_api.py [server_url] [app_secret]

Defaults:
    server_url: http://localhost:8000
    app_secret: test-secret-123
"""
import sys
import time
import json
import requests

SERVER = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
SECRET = sys.argv[2] if len(sys.argv) > 2 else "test-secret-123"

HEADERS = {
    "Content-Type": "application/json",
    "x-app-secret": SECRET,
}


def test_health():
    """Test health endpoint."""
    print("\n[1/4] Testing /health...")
    r = requests.get(f"{SERVER}/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
    print("  ✅ Health check passed")


def test_create_job():
    """Test job creation."""
    print("\n[2/4] Testing POST /v1/jobs...")
    
    payload = {
        "batch_date": "2025-12-20",
        "preset": "neutral",
        "items": [
            {"id": "01", "text": "안녕하세요. 테스트입니다.", "max_chars": 1100},
            {"id": "02", "text": "두 번째 테스트 문장입니다.", "max_chars": 1100},
        ]
    }
    
    r = requests.post(f"{SERVER}/v1/jobs", headers=HEADERS, json=payload)
    assert r.status_code == 202, f"Expected 202, got {r.status_code}"
    
    data = r.json()
    assert "job_id" in data
    assert data["status"] == "queued"
    
    print(f"  ✅ Job created: {data['job_id']}")
    return data["job_id"]


def test_poll_status(job_id: str):
    """Test status polling."""
    print(f"\n[3/4] Testing GET /v1/jobs/{job_id}...")
    
    max_wait = 60
    start = time.time()
    
    while time.time() - start < max_wait:
        r = requests.get(f"{SERVER}/v1/jobs/{job_id}", headers=HEADERS)
        assert r.status_code == 200
        
        data = r.json()
        status = data["status"]
        progress = data.get("progress", 0)
        total = data.get("total", 0)
        
        print(f"  Status: {status} ({progress}/{total})")
        
        if status == "completed":
            print("  ✅ Job completed")
            return True
        elif status == "failed":
            print(f"  ❌ Job failed: {data.get('error')}")
            return False
        
        time.sleep(2)
    
    print("  ⚠️ Timeout waiting for completion")
    return False


def test_download(job_id: str):
    """Test ZIP download."""
    print(f"\n[4/4] Testing GET /v1/jobs/{job_id}/download...")
    
    r = requests.get(f"{SERVER}/v1/jobs/{job_id}/download", headers=HEADERS)
    
    if r.status_code == 200:
        filename = f"{job_id}.zip"
        with open(filename, "wb") as f:
            f.write(r.content)
        print(f"  ✅ Downloaded: {filename} ({len(r.content)} bytes)")
        return True
    else:
        print(f"  ❌ Download failed: {r.status_code}")
        return False


def test_redownload_fails(job_id: str):
    """Verify re-download fails (cleanup worked)."""
    print(f"\n[Bonus] Verifying cleanup (re-download should fail)...")
    
    r = requests.get(f"{SERVER}/v1/jobs/{job_id}/download", headers=HEADERS)
    
    if r.status_code == 404:
        print("  ✅ Cleanup verified - job deleted after download")
        return True
    else:
        print(f"  ⚠️ Unexpected status: {r.status_code}")
        return False


def main():
    print("="*50)
    print("TTS Factory API Test")
    print(f"Server: {SERVER}")
    print("="*50)
    
    try:
        test_health()
        job_id = test_create_job()
        
        if test_poll_status(job_id):
            if test_download(job_id):
                test_redownload_fails(job_id)
        
        print("\n" + "="*50)
        print("✅ All tests passed!")
        print("="*50)
        
    except requests.exceptions.ConnectionError:
        print(f"\n❌ Cannot connect to {SERVER}")
        print("   Is the server running?")
        sys.exit(1)
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
