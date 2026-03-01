#!/usr/bin/env python3
"""License Audit — pubspec.yaml 의존성 라이선스 자동 감사.

모든 Parksy 앱의 pubspec.yaml을 스캔하여:
1. 의존성 목록 추출
2. 알려진 라이선스 DB와 대조
3. GPL 오염 여부 확인
4. 컴플라이언스 리포트 생성

Usage:
  python3 scripts/license-audit.py              # 전체 감사
  python3 scripts/license-audit.py --app wavesy  # 특정 앱만
  python3 scripts/license-audit.py --strict      # GPL 포함 시 exit 1
"""

import os
import re
import sys
import json
from pathlib import Path
from datetime import datetime, timezone

# === 알려진 Flutter 패키지 라이선스 DB ===
# pub.dev 기준. 새 패키지 추가 시 여기에 등록.
# 라이선스가 불명이면 UNKNOWN → 수동 확인 필요.

LICENSE_DB = {
    # === Flutter SDK (BSD-3) ===
    "flutter": "BSD-3-Clause",
    "flutter_test": "BSD-3-Clause",
    "flutter_lints": "BSD-3-Clause",

    # === Google/Dart 팀 (BSD-3) ===
    "path_provider": "BSD-3-Clause",
    "shared_preferences": "BSD-3-Clause",
    "share_plus": "BSD-3-Clause",
    "permission_handler": "MIT",
    "intl": "BSD-3-Clause",
    "file_picker": "MIT",

    # === 오디오 ===
    "just_audio": "Apache-2.0",
    "ffmpeg_kit_flutter_audio": "LGPL-3.0",
    "ffmpeg_kit_flutter_new_audio": "LGPL-3.0",
    "flutter_midi_pro": "MIT",

    # === 네트워크 ===
    "dio": "MIT",
    "http": "BSD-3-Clause",

    # === UI ===
    "cupertino_icons": "MIT",
    "flutter_colorpicker": "MIT",
    "google_fonts": "Apache-2.0",

    # === 이미지/그래픽 ===
    "image": "Apache-2.0",
    "image_picker": "Apache-2.0",
    "photo_view": "MIT",

    # === 저장/DB ===
    "sqflite": "BSD-2-Clause",
    "hive": "Apache-2.0",
    "isar": "Apache-2.0",

    # === 유틸 ===
    "uuid": "MIT",
    "collection": "BSD-3-Clause",
    "meta": "BSD-3-Clause",
    "args": "BSD-3-Clause",
    "url_launcher": "BSD-3-Clause",
    "provider": "MIT",
    "connectivity_plus": "BSD-3-Clause",

    # === 음성/오디오 ===
    "speech_to_text": "MIT",
    "system_audio_recorder": "MIT",

    # === UI/오버레이 ===
    "flutter_overlay_window": "MIT",

    # === 테스트 ===
    "mocktail": "MIT",
}

# === 라이선스 분류 ===

LICENSE_CATEGORIES = {
    "PERMISSIVE": ["MIT", "BSD-2-Clause", "BSD-3-Clause", "Apache-2.0", "ISC", "Zlib"],
    "WEAK_COPYLEFT": ["LGPL-2.1", "LGPL-3.0", "MPL-2.0"],
    "STRONG_COPYLEFT": ["GPL-2.0", "GPL-3.0", "AGPL-3.0"],
}

def categorize_license(license_id: str) -> str:
    """라이선스 카테고리 반환."""
    for category, licenses in LICENSE_CATEGORIES.items():
        if license_id in licenses:
            return category
    if license_id == "UNKNOWN":
        return "UNKNOWN"
    return "OTHER"


def parse_pubspec(pubspec_path: str) -> dict:
    """pubspec.yaml에서 앱 이름과 의존성 추출."""
    with open(pubspec_path, 'r') as f:
        content = f.read()

    # 앱 이름
    name_match = re.search(r'^name:\s*(\S+)', content, re.MULTILINE)
    app_name = name_match.group(1) if name_match else "unknown"

    # dependencies 블록 파싱
    deps = []
    in_deps = False
    in_dev_deps = False
    for line in content.split('\n'):
        if re.match(r'^dependencies:', line):
            in_deps = True
            in_dev_deps = False
            continue
        if re.match(r'^dev_dependencies:', line):
            in_deps = False
            in_dev_deps = True
            continue
        if re.match(r'^\S', line) and not line.startswith('#'):
            in_deps = False
            in_dev_deps = False
            continue

        if in_deps or in_dev_deps:
            dep_match = re.match(r'^\s{2}(\w[\w_]*)\s*:', line)
            if dep_match:
                dep_name = dep_match.group(1)
                if dep_name not in ('sdk', 'flutter'):
                    deps.append({
                        "name": dep_name,
                        "dev": in_dev_deps,
                    })

    return {"name": app_name, "path": pubspec_path, "dependencies": deps}


def audit_app(app_info: dict) -> dict:
    """앱 하나를 감사하고 결과 반환."""
    results = {
        "app": app_info["name"],
        "path": app_info["path"],
        "total_deps": len(app_info["dependencies"]),
        "deps": [],
        "violations": [],
        "warnings": [],
    }

    for dep in app_info["dependencies"]:
        dep_name = dep["name"]
        license_id = LICENSE_DB.get(dep_name, "UNKNOWN")
        category = categorize_license(license_id)

        dep_result = {
            "name": dep_name,
            "license": license_id,
            "category": category,
            "dev_only": dep["dev"],
        }
        results["deps"].append(dep_result)

        # 위반 체크
        if category == "STRONG_COPYLEFT" and not dep["dev"]:
            results["violations"].append(
                f"GPL CONTAMINATION: {dep_name} ({license_id}) — "
                f"runtime 의존성에 GPL 코드 포함. Parksy 앱 소스 공개 의무 발생!"
            )
        elif category == "WEAK_COPYLEFT":
            results["warnings"].append(
                f"WEAK COPYLEFT: {dep_name} ({license_id}) — "
                f"동적 링크 시 OK, 정적 링크 시 해당 라이브러리 수정분 공개 필요"
            )
        elif category == "UNKNOWN":
            results["warnings"].append(
                f"UNKNOWN LICENSE: {dep_name} — "
                f"pub.dev에서 라이선스 수동 확인 필요. LICENSE_DB에 등록해라."
            )

    return results


def print_report(all_results: list, strict: bool = False):
    """감사 결과 출력."""
    print()
    print("=" * 60)
    print("  PARKSY LICENSE AUDIT REPORT")
    print(f"  {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
    print("=" * 60)

    total_violations = 0
    total_warnings = 0

    for result in all_results:
        print(f"\n--- {result['app']} ({result['total_deps']} deps) ---")
        print(f"    {result['path']}")

        for dep in result["deps"]:
            icon = {
                "PERMISSIVE": "O",
                "WEAK_COPYLEFT": "~",
                "STRONG_COPYLEFT": "X",
                "UNKNOWN": "?",
            }.get(dep["category"], " ")
            dev_tag = " (dev)" if dep["dev_only"] else ""
            print(f"    [{icon}] {dep['name']:30s} {dep['license']:15s} {dep['category']}{dev_tag}")

        for v in result["violations"]:
            print(f"    !! {v}")
            total_violations += 1

        for w in result["warnings"]:
            print(f"    >> {w}")
            total_warnings += 1

    print("\n" + "=" * 60)
    print(f"  SUMMARY: {total_violations} violations, {total_warnings} warnings")

    if total_violations > 0:
        print("  STATUS: FAIL — GPL 오염 발견. 수정 필요.")
        print("=" * 60)
        if strict:
            sys.exit(1)
    elif total_warnings > 0:
        print("  STATUS: WARN — 수동 확인 필요 항목 있음.")
        print("=" * 60)
    else:
        print("  STATUS: PASS — 모든 의존성 라이선스 확인됨.")
        print("=" * 60)


def export_json(all_results: list, output_path: str):
    """감사 결과를 JSON으로 내보내기."""
    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "tool": "license-audit.py",
        "apps": all_results,
    }
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f"\n  JSON exported: {output_path}")


def main():
    # 레포 루트로 이동
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    os.chdir(repo_root)

    # 인수 파싱
    target_app = None
    strict = False
    export = False
    for arg in sys.argv[1:]:
        if arg == '--strict':
            strict = True
        elif arg == '--json':
            export = True
        elif arg == '--app':
            pass  # 다음 인수에서 처리
        elif sys.argv[sys.argv.index(arg) - 1] == '--app':
            target_app = arg

    # pubspec.yaml 수집
    apps_dir = Path("apps")
    pubspecs = sorted(apps_dir.glob("*/pubspec.yaml"))

    if not pubspecs:
        print("ERROR: apps/*/pubspec.yaml not found")
        sys.exit(1)

    all_results = []
    for pubspec in pubspecs:
        app_info = parse_pubspec(str(pubspec))
        if target_app and target_app not in app_info["name"] and target_app not in str(pubspec):
            continue
        result = audit_app(app_info)
        all_results.append(result)

    print_report(all_results, strict=strict)

    if export:
        export_json(all_results, "docs/license-audit-report.json")


if __name__ == '__main__':
    main()
