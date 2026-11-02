#!/usr/bin/env python3
"""Independent BFS oracle. Certifies minimum move counts for the NULL campaign."""
import argparse
from collections import deque
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = {"up": (0, -1), "right": (1, 0), "down": (0, 1), "left": (-1, 0)}
FIELDS = {glyph: 27 + index for index, glyph in enumerate("^>v<")}
FIELD_DIRECTIONS = dict(zip(range(27, 31), DIRECTIONS))


def initial(level):
    layout = "".join(level["layout"])
    board = tuple(-1 if c == "#" else ord(c) - 64 if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" else FIELDS.get(c, 0) for c in layout)
    pieces = [1 if c == "w" else -1 if c == "b" else 0 for c in layout]
    for cell, color in level.get("tokens", []):
        pieces[cell] = color
    return board, tuple(pieces)


def validate(level):
    rows = level["layout"]
    assert rows and rows[0] and all(len(row) == len(rows[0]) for row in rows)
    assert all(c in "#.wbABCDEFGHIJKLMNOPQRSTUVWXYZ^>v<" for row in rows for c in row)
    assert len({int(t[0]) for t in level.get("tokens", [])}) == len(level.get("tokens", []))
    for cell, color in level.get("tokens", []):
        assert isinstance(cell, int) and 0 <= cell < len("".join(rows))
        assert color in (-1, 1) and "".join(rows)[cell] not in "#wb"
    board, pieces = initial(level)
    assert sum(pieces) == 0 and any(pieces), "Equal, nonzero black/white counts required"
    assert all(board[i] >= 0 for i, c in enumerate(pieces) if c)
    assert all(board.count(group) in (0, 2) for group in range(1, 27))


def move(state, width, source, direction):
    board, pieces = state
    color = pieces[source]
    if board[source] in FIELD_DIRECTIONS and FIELD_DIRECTIONS[board[source]] != direction:
        return None
    dx, dy = DIRECTIONS[direction]
    x, y = source % width + dx, source // width + dy
    if not color or not (0 <= x < width and 0 <= y < len(board) // width):
        return None
    entry = y * width + x
    if board[entry] < 0 or pieces[entry] == color:
        return None
    partner = next((i for i, t in enumerate(board) if 1 <= board[entry] <= 26 and t == board[entry] and i != entry), None)
    if partner is not None and partner != source and pieces[partner] == color:
        return None
    target = entry if pieces[entry] or partner is None else partner
    floor, tokens = list(board), list(pieces)
    tokens[source] = 0
    if tokens[target] == -color:
        tokens[target] = 0
        if 1 <= floor[target] <= 26:
            for i, t in enumerate(floor):
                if i != target and t == floor[target]:
                    floor[i] = 0
        floor[target] = -1
    else:
        tokens[target] = color
    return tuple(floor), tuple(tokens)


def solve(level, limit=250000):
    start = initial(level)
    width = len(level["layout"][0])
    queue = deque([start])
    parents = {start: None}
    while queue:
        state = queue.popleft()
        if not any(state[1]):
            path = []
            while parents[state] is not None:
                previous, source, direction = parents[state]
                path.append({"source": source, "direction": direction})
                state = previous
            return list(reversed(path)), len(parents)
        for source, color in enumerate(state[1]):
            if not color:
                continue
            for direction in DIRECTIONS:
                result = move(state, width, source, direction)
                if result is None or result in parents:
                    continue
                if len(parents) >= limit:
                    raise RuntimeError(f'{level["id"]}: search limit reached; minimum NOT certified')
                parents[result] = state, source, direction
                queue.append(result)
    raise RuntimeError(f'{level["id"]}: unsolvable')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="Update certified solutions in the catalog")
    args = parser.parse_args()
    path = ROOT / "data/levels.json"
    levels = json.loads(path.read_text())
    assert len({level["id"] for level in levels}) == len(levels)
    for level in levels:
        validate(level)
        solution, visited = solve(level)
        if args.write:
            level.update(optimal_moves=len(solution), solution=solution,
                         proof={"method": "exhaustive_bfs", "visited": visited})
        else:
            assert level["optimal_moves"] == len(solution), level["id"]
            state = initial(level)
            for action in level["solution"]:
                state = move(state, len(level["layout"][0]), action["source"], action["direction"])
                assert state is not None, level["id"]
            assert not any(state[1]) and len(level["solution"]) == len(solution)
        print(f'{level["id"]:>3}  {level["title"]:<8}  minimum={len(solution):2}  states={visited}')
    if args.write:
        path.write_text(json.dumps(levels, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
