#!/usr/bin/env python3
"""Run repository checks, rejecting Godot script errors even if the engine exits 0."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--visual', action='store_true', help='Open native windows and capture UI screenshots')
    args = parser.parse_args()
    headless = [] if args.visual else ['--headless']
    commands = [
        [sys.executable, 'tools/certify_levels.py'],
        ['godot', '--headless', '--path', '.', '--editor', '--import', '--quit'],
        ['godot', '--headless', '--path', '.', '--script', 'tests/run_tests.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/ui_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/app_smoke.gd'],
    ]
    for command in commands:
        print('Running:', ' '.join(command), flush=True)
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=120)
        print(result.stdout, end='', flush=True)
        if result.returncode or re.search(r'(?m)^(?:SCRIPT ERROR|ERROR):', result.stdout):
            raise SystemExit(1)
    print('All GRAY checks passed.')


if __name__ == '__main__':
    main()
