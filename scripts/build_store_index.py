#!/usr/bin/env python3
"""Build dashboard/apps.json from app-registry.json + pubspec.yaml (SSOT).

Reads app-registry.json for app metadata, pubspec.yaml for live versions,
and generates dashboard/apps.json for the Vercel store page + factory.
Also auto-updates stats in dashboard/dashboard-config.json.
"""

import json
import re
import os
from datetime import datetime, timezone

# Dashboard ID aliases: registry id -> dashboard display id
DASHBOARD_ALIASES = {
    "capture-pipeline": "parksy-capture",
    "laser-pen-overlay": "parksy-pen",
    "tts-factory": "parksy-tts",
}

# Download URL template
DOWNLOAD_URL = "https://github.com/dtslib1979/dtslib-apk-lab/releases/download/{tag}/app-debug.apk"


def load_registry(repo_root: str) -> list:
    """Load app-registry.json."""
    path = os.path.join(repo_root, "app-registry.json")
    with open(path, "r") as f:
        return json.load(f)


def read_version(pubspec_path: str) -> str:
    """Extract version from pubspec.yaml, return vX.Y.Z format."""
    try:
        with open(pubspec_path, "r") as f:
            content = f.read()
        match = re.search(r"^version:\s*([^\s]+)", content, re.MULTILINE)
        if match:
            version = match.group(1).split("+")[0]
            return f"v{version}"
    except FileNotFoundError:
        pass
    return "v0.0.0"


def read_build_number(pubspec_path: str) -> int:
    """Extract build number (+N) from pubspec.yaml."""
    try:
        with open(pubspec_path, "r") as f:
            content = f.read()
        match = re.search(r"^version:\s*[^\+]+\+(\d+)", content, re.MULTILINE)
        if match:
            return int(match.group(1))
    except FileNotFoundError:
        pass
    return 0


def build_apps_json(repo_root: str, registry: list) -> list:
    """Generate apps list from ALL registry entries (store + factory)."""
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    apps = []

    for entry in registry:
        app_dir = entry["directory"]
        pubspec = os.path.join(repo_root, app_dir, "pubspec.yaml")
        if not os.path.exists(pubspec):
            pubspec = os.path.join(repo_root, app_dir, "app", "pubspec.yaml")

        version = read_version(pubspec)
        dashboard_id = DASHBOARD_ALIASES.get(entry["id"], entry["id"])
        description = entry.get("description", "")
        reg_status = entry.get("status", "development")

        # Special case: Parksy Pen shows build number
        if entry["id"] == "laser-pen-overlay":
            build_num = read_build_number(pubspec)
            description = f"S Pen 레이저펜 오버레이 판서 (Build #{build_num})"

        release_tag = entry.get("release_tag", f"{dashboard_id}-latest")
        download_url = DOWNLOAD_URL.format(tag=release_tag)
        download_active = entry.get("download_active", False)

        apps.append({
            "id": dashboard_id,
            "name": entry["name"],
            "version": version,
            "registryStatus": reg_status,
            "category": entry.get("category", "utility"),
            "description": description,
            "icon": entry.get("icon_emoji", ""),
            "downloadUrl": download_url if (reg_status == "store-registered" and download_active) else None,
            "workflow": entry.get("workflow"),
            "releaseTag": release_tag,
            "lastUpdated": today,
        })

    return apps


def update_dashboard_config(repo_root: str, registry: list):
    """Auto-update stats in dashboard-config.json."""
    config_path = os.path.join(repo_root, "dashboard", "dashboard-config.json")
    if not os.path.exists(config_path):
        print(f"  [skip] {config_path} not found")
        return

    with open(config_path, "r") as f:
        config = json.load(f)

    total_apps = len(registry)
    store_apps = sum(1 for e in registry if e.get("status") == "store-registered")
    total_dart = sum(e.get("dart_lines", 0) for e in registry)
    total_kotlin = sum(e.get("kotlin_lines", 0) for e in registry)
    total_code = total_dart + total_kotlin
    workflows = sum(1 for e in registry if e.get("workflow"))

    cats = set()
    for e in registry:
        c = e.get("category")
        if c:
            cats.add(c)

    config["stats"]["total_apps"] = total_apps
    config["stats"]["store_apps"] = store_apps
    config["stats"]["total_dart_lines"] = total_dart
    config["stats"]["total_kotlin_lines"] = total_kotlin
    config["stats"]["total_code_lines"] = total_code
    config["stats"]["total_workflows"] = workflows

    for cat in cats:
        if cat not in config.get("categories", {}):
            config.setdefault("categories", {})[cat] = {
                "label": cat.capitalize(),
                "color": "#D4AF37"
            }

    with open(config_path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Updated dashboard-config.json stats:")
    print(f"  total_apps={total_apps}, store={store_apps}, code={total_code}, workflows={workflows}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    os.chdir(repo_root)

    registry = load_registry(repo_root)

    apps = build_apps_json(repo_root, registry)
    output_path = "dashboard/apps.json"

    with open(output_path, "w") as f:
        json.dump(apps, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Updated {output_path} ({len(apps)} apps)")
    for app in apps:
        status = app['registryStatus']
        print(f"  {app['id']}: {app['version']} [{app['category']}] ({status})")

    update_dashboard_config(repo_root, registry)


if __name__ == "__main__":
    main()
