#!/usr/bin/env python3
"""Constitution Guard - Hybrid Enforcement Mode.

Enforces PARKSY PERSONAL APK CONSTITUTION v1.3.
- HARD BLOCK: Critical zones (CI fails)
- SOFT WARNING: Experimental zones (warning only)
"""

import re
import sys
import os
from pathlib import Path

# === ZONE DEFINITIONS ===

CRITICAL_PATHS = [
    '.github/',
    'scripts/',
    'dashboard/apps.json',
]

SOFT_PATHS = [
    'apps/',
    'dashboard/',
]

# === FORBIDDEN PATTERNS (§1.1, §11.5) ===

FORBIDDEN_PATTERNS = [
    (r'firebase', 'Firebase is forbidden (§1.1)'),
    (r'analytics', 'Analytics is forbidden (§1.1)'),
    (r'crashlytics', 'Crashlytics is forbidden (§1.1)'),
    (r'admob', 'AdMob is forbidden (§1.1)'),
    (r'play[_\-\s]?store', 'Play Store prep is forbidden (§1.1)'),
    (r'app[_\-\s]?store', 'App Store prep is forbidden (§1.1)'),
    (r'\b(login|signup|sign[_\-\s]?up)\b', 'Auth is forbidden (§1.1)'),
    (r'subscription|payment|billing', 'Payments are forbidden (§1.1)'),
    (r'telemetry|tracking', 'Telemetry is forbidden (§1.1)'),
    (r'multi[_\-\s]?user|multi[_\-\s]?device', 'Multi-user is forbidden (§1.1)'),
]

# === ZONE CLASSIFICATION ===

def get_zone(file_path: str) -> str:
    """Determine zone for a file path."""
    for critical in CRITICAL_PATHS:
        if file_path.startswith(critical) or file_path == critical.rstrip('/'):
            return 'HARD'
    for soft in SOFT_PATHS:
        if file_path.startswith(soft):
            return 'SOFT'
    return 'NONE'

# === PATTERN SCANNER ===

def scan_file(file_path: str) -> list:
    """Scan file for forbidden patterns."""
    violations = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read().lower()
        for pattern, message in FORBIDDEN_PATTERNS:
            if re.search(pattern, content, re.IGNORECASE):
                violations.append(message)
    except Exception:
        pass
    return violations

# === MAIN GUARD ===

def main():
    """Run constitution guard on changed files."""
    # Get changed files from git or args
    if len(sys.argv) > 1:
        changed_files = sys.argv[1:]
    else:
        import subprocess
        result = subprocess.run(
            ['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'],
            capture_output=True, text=True
        )
        changed_files = result.stdout.strip().split('\n')
    
    hard_violations = []
    soft_violations = []
    
    print('\n🔍 CONSTITUTION GUARD v1.3 - Hybrid Mode')
    print('=' * 50)
    
    for file_path in changed_files:
        if not file_path or not os.path.exists(file_path):
            continue
        
        zone = get_zone(file_path)
        violations = scan_file(file_path)
        
        if violations:
            for v in violations:
                entry = f'{file_path}: {v}'
                if zone == 'HARD':
                    hard_violations.append(entry)
                    print(f'🔴 HARD BLOCK: {entry}')
                elif zone == 'SOFT':
                    soft_violations.append(entry)
                    print(f'🟡 SOFT WARN:  {entry}')
    
    print('=' * 50)
    
    # Summary
    if hard_violations:
        print(f'\n❌ HARD VIOLATIONS: {len(hard_violations)}')
        print('   CI MUST FAIL. Fix violations before merge.')
        sys.exit(1)
    
    if soft_violations:
        print(f'\n⚠️  SOFT WARNINGS: {len(soft_violations)}')
        print('   Human review required. Check PR template.')
        sys.exit(0)  # CI passes, but warnings logged
    
    print('\n✅ No constitutional violations detected.')
    sys.exit(0)

if __name__ == '__main__':
    main()
