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
        [sys.executable, 'tools/audit_level_designs.py'],
        ['godot', '--headless', '--path', '.', '--editor', '--import', '--quit'],
        ['godot', '--headless', '--path', '.', '--script', 'tests/run_tests.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/ui_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/pointer_controls_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/level_intro_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/layout_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/home_layout_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/settings_layout_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/audio_smoke.gd'],
        ['godot', '--headless', '--path', '.', '--script', 'tests/custom_records_tests.gd'],
        ['godot', '--headless', '--path', '.', '--script', 'tests/field_tests.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/editor_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/library_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/progression_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/navigation_layout_smoke.gd'],
        ['godot', *headless, '--path', '.', '--script', 'tests/app_smoke.gd'],
    ]
    for command in commands:
        print('Running:', ' '.join(command), flush=True)
        try:
            result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=180 if 'tests/run_tests.gd' in command else 120)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or ''
            print(output.decode(errors='replace') if isinstance(output, bytes) else output,
                  end='', flush=True)
            print('Check timed out:', ' '.join(command), flush=True)
            raise SystemExit(1) from None
        print(result.stdout, end='', flush=True)
        if result.returncode or re.search(r'(?m)^(?:SCRIPT ERROR|ERROR):', result.stdout):
            raise SystemExit(1)
    print('All ANNIHILATION checks passed.')


if __name__ == '__main__':
    main()
