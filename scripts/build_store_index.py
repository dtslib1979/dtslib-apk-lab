#!/usr/bin/env python3
"""Build dashboard/apps.json from pubspec.yaml files (SSOT).

This script reads version info from each app's pubspec.yaml
and generates the dashboard/apps.json file automatically.
"""

import json
import re
import os
from datetime import datetime, timezone

# App configurations (Parksy Branding)
APPS_CONFIG = [
    {
        "id": "parksy-axis",
        "name": "Parksy Axis",
        "description": "방송용 사고 단계 오버레이 (FSM 상태 전이)",
        "icon": "🎯",
        "pubspec": "apps/parksy-axis/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip"
    },
    {
        "id": "parksy-pen",
        "name": "Parksy Pen",
        "description": "S Pen 레이저펜 오버레이 판서",
        "icon": "✍️",
        "pubspec": "apps/laser-pen-overlay/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip"
    },
    {
        "id": "parksy-capture",
        "name": "Parksy Capture",
        "description": "텍스트 캡처 → GitHub 자동 아카이브",
        "icon": "💾",
        "pubspec": "apps/capture-pipeline/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-capture-pipeline/main/capture-pipeline-debug.zip"
    },
    {
        "id": "parksy-subtitle",
        "name": "Parksy Subtitle",
        "description": "이중자막 오버레이",
        "icon": "🖊️",
        "pubspec": "apps/overlay-dual-sub/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/overlay-dual-sub/main/overlay-dual-sub-debug.zip"
    },
    {
        "id": "parksy-aiva",
        "name": "Parksy AIVA",
        "description": "AIVA MP3 무음 트리밍",
        "icon": "🎧",
        "pubspec": "apps/aiva-trimmer/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-aiva-trimmer/main/aiva-trimmer-debug.zip"
    },
    {
        "id": "parksy-tts",
        "name": "Parksy TTS",
        "description": "배치 TTS 생성기 (Google Cloud)",
        "icon": "🎙️",
        "pubspec": "apps/tts-factory/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-tts-factory/main/tts-factory-debug.zip"
    }
]

def read_version(pubspec_path: str) -> str:
    """Extract version from pubspec.yaml."""
    try:
        with open(pubspec_path, 'r') as f:
            content = f.read()
        match = re.search(r'^version:\s*([^\s]+)', content, re.MULTILINE)
        if match:
            # Return just major.minor.patch (strip build number)
            version = match.group(1).split('+')[0]
            return f"v{version}"
    except FileNotFoundError:
        pass
    return "v0.0.0"

def build_apps_json():
    """Generate apps.json from pubspec versions."""
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    apps = []
    
    for config in APPS_CONFIG:
        version = read_version(config['pubspec'])
        # Append build number for Parksy Pen
        if config['id'] == 'parksy-pen':
            build = version.split('.')[-1] if version != 'v0.0.0' else '0'
            config['description'] = f"S Pen 레이저펜 오버레이 판서 (Build #{build})"
        
        apps.append({
            "id": config['id'],
            "name": config['name'],
            "version": version,
            "description": config['description'],
            "icon": config['icon'],
            "downloadUrl": config['downloadUrl'],
            "lastUpdated": today
        })
    
    return apps

def main():
    # Ensure we're in repo root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    os.chdir(repo_root)
    
    apps = build_apps_json()
    output_path = 'dashboard/apps.json'
    
    with open(output_path, 'w') as f:
        json.dump(apps, f, indent=2, ensure_ascii=False)
        f.write('\n')
    
    print(f"✅ Updated {output_path}")
    for app in apps:
        print(f"   {app['id']}: {app['version']}")

if __name__ == '__main__':
    main()
