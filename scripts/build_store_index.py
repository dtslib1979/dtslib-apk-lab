#!/usr/bin/env python3
"""Build dashboard/apps.json from pubspec.yaml files (SSOT).

This script reads version info from each app's pubspec.yaml
and generates the dashboard/apps.json file automatically.
"""

import json
import re
import os
from datetime import datetime, timezone

# App configurations (static metadata)
APPS_CONFIG = [
    {
        "id": "capture-pipeline",
        "name": "Capture Pipeline",
        "description": "Lossless conversation capture for LLM power users",
        "icon": "💾",
        "pubspec": "apps/capture-pipeline/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-capture-pipeline/main/capture-pipeline-debug.zip"
    },
    {
        "id": "laser-pen-overlay",
        "name": "Laser Pen Overlay",
        "description": "S Pen drawing overlay with finger passthrough",
        "icon": "✍️",
        "pubspec": "apps/laser-pen-overlay/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip"
    },
    {
        "id": "aiva-trimmer",
        "name": "AIVA Trimmer",
        "description": "Audio trimmer optimized for AIVA exports",
        "icon": "🎧",
        "pubspec": "apps/aiva-trimmer/pubspec.yaml",
        "downloadUrl": "https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-aiva-trimmer/main/aiva-trimmer-debug.zip"
    },
    {
        "id": "tts-factory",
        "name": "TTS Factory",
        "description": "Batch TTS processing with Google Cloud",
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
