#!/usr/bin/env python3
"""Check authored puzzle ideas by searching for solutions that bypass them."""
from collections import deque
import json

from certify_levels import ROOT, DIRECTIONS, initial, move


def event(state, width, source, direction):
    board, pieces = state
    dx, dy = DIRECTIONS[direction]
    entry = source + dx + dy * width
    partner = next((i for i, tag in enumerate(board)
                    if 1 <= board[entry] <= 26 and tag == board[entry] and i != entry), None)
    target = entry if pieces[entry] or partner is None else partner
    return entry, target, target != entry


def search(level, requirement, limit=250000):
    start = initial(level)
    original_board = start[0]
    width = len(level['layout'][0])
    initial_count = sum(bool(piece) for piece in start[1])
    queue = deque([(start, 0)])
    seen = {start}
    admitted = 0
    kind = requirement['kind']
    group = ord(requirement.get('group', 'A')) - 64
    while queue:
        state, depth = queue.popleft()
        if not any(state[1]):
            return depth, len(seen), admitted
        for source, color in enumerate(state[1]):
            if not color:
                continue
            for direction in DIRECTIONS:
                result = move(state, width, source, direction)
                if result is None:
                    continue
                entry, target, teleported = event(state, width, source, direction)
                merged = result[1].count(0) > state[1].count(0)
                if kind == 'mandatory_teleport':
                    if teleported and state[0][entry] == group and color == requirement.get('color', color):
                        continue
                elif kind == 'mandatory_collapsed_tile':
                    if original_board[entry] == group and state[0][entry] == 0:
                        continue
                elif kind == 'mandatory_field_departure':
                    if 27 <= state[0][source] <= 30:
                        continue
                elif kind == 'opening_collision_fatal':
                    if state == start:
                        if not merged:
                            continue
                        admitted += 1
                elif kind == 'first_collision_avoids':
                    if merged and sum(bool(piece) for piece in state[1]) == initial_count:
                        if target not in requirement['cells']:
                            continue
                        admitted += 1
                else:
                    raise ValueError('Unknown design check: ' + kind)
                if result in seen:
                    continue
                if len(seen) >= limit:
                    raise RuntimeError(f'{level["id"]}: design search limit reached; NOT verified')
                seen.add(result)
                queue.append((result, depth + 1))
    return None, len(seen), admitted


def main():
    levels = json.loads((ROOT / 'data/levels.json').read_text())
    checks = 0
    for level in levels:
        for requirement in level.get('design_checks', []):
            distance, visited, admitted = search(level, requirement)
            kind = requirement['kind']
            if kind in ('opening_collision_fatal', 'first_collision_avoids'):
                assert admitted, f'{level["id"]}: the supposedly tempting collision is unreachable'
            if requirement.get('optimal_only', False):
                assert distance is None or distance > level['optimal_moves'], f'{level["id"]}: an optimal solution bypasses the intended idea'
            else:
                assert distance is None, f'{level["id"]}: intended idea can be bypassed in {distance} moves'
            detail = requirement.get('group', requirement.get('cells', ''))
            if 'color' in requirement:
                detail += f' (particle {requirement["color"]})'
            if requirement.get('optimal_only', False):
                detail += f' (Hard; bypass needs {distance if distance is not None else "no solution"})'
            print(f'{level["id"]} {kind} {detail}: verified ({visited} states)')
            checks += 1
    assert checks, 'No authored design checks were found'
    print(f'NULL design audit: {checks} verified requirements')


if __name__ == '__main__':
    main()
