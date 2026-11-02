class_name GrayPuzzle
extends RefCounted
## Pure, deterministic rules. No animation, input, or save state lives here.

const DIRECTIONS := {
	"up": Vector2i(0, -1), "right": Vector2i(1, 0),
	"down": Vector2i(0, 1), "left": Vector2i(-1, 0),
}

static func from_level(level: Dictionary) -> Dictionary:
	var rows: Array = level.layout
	var width: int = rows[0].length()
	var board: Array[int] = []
	var pieces: Array[int] = []
	for row in rows:
		for glyph in str(row):
			board.append(-1 if glyph == "#" else (1 if glyph == "A" else (2 if glyph == "B" else 0)))
			pieces.append(1 if glyph == "w" else (-1 if glyph == "b" else 0))
	for token in level.get("tokens", []):
		pieces[int(token[0])] = int(token[1])
	return {"width": width, "height": rows.size(), "board": board, "pieces": pieces}

static func other_portal(board: Array, index: int) -> int:
	if board[index] <= 0:
		return -1
	for i in board.size():
		if i != index and board[i] == board[index]:
			return i
	return -1

static func move(state: Dictionary, source: int, direction: String) -> Dictionary:
	if not DIRECTIONS.has(direction) or source < 0 or source >= state.pieces.size():
		return {}
	var color: int = state.pieces[source]
	if color == 0:
		return {}
	var step: Vector2i = DIRECTIONS[direction]
	var x: int = source % state.width + step.x
	var y: int = source / state.width + step.y
	if x < 0 or x >= state.width or y < 0 or y >= state.height:
		return {}
	var entry: int = y * state.width + x
	if state.board[entry] < 0 or state.pieces[entry] == color:
		return {}
	var exit := other_portal(state.board, entry)
	# Match Neutronic's validation order, including occupied portal entrances.
	if exit >= 0 and exit != source and state.pieces[exit] == color:
		return {}
	var next: Dictionary = state.duplicate(true)
	next.pieces[source] = 0
	var target: int = entry
	if next.pieces[entry] == 0 and exit >= 0:
		target = exit
	var merged: bool = next.pieces[target] == -color
	if merged:
		next.pieces[target] = 0
		var partner := other_portal(next.board, target)
		if partner >= 0:
			next.board[partner] = 0
		next.board[target] = -1
	else:
		next.pieces[target] = color
	return {"state": next, "source": source, "entry": entry, "target": target,
		"merged": merged, "teleported": target != entry, "color": color}

static func won(state: Dictionary) -> bool:
	return state.pieces.all(func(value): return value == 0)

static func key(state: Dictionary) -> String:
	return str(state.board) + "/" + str(state.pieces)

static func solve(initial: Dictionary, max_states: int = 250000) -> Dictionary:
	# Unit-cost BFS: the first solution is a proven global minimum.
	var queue: Array = [initial]
	var parents: Array[int] = [-1]
	var actions: Array = [{}]
	var seen := {key(initial): true}
	var cursor := 0
	while cursor < queue.size():
		var state: Dictionary = queue[cursor]
		if won(state):
			var path: Array = []
			var node := cursor
			while parents[node] >= 0:
				path.push_front(actions[node])
				node = parents[node]
			return {"status": "solved", "moves": path.size(), "solution": path, "visited": seen.size()}
		for source in state.pieces.size():
			if state.pieces[source] == 0:
				continue
			for direction in DIRECTIONS:
				var result := move(state, source, direction)
				if result.is_empty():
					continue
				var fingerprint := key(result.state)
				if seen.has(fingerprint):
					continue
				if seen.size() >= max_states:
					return {"status": "limit", "visited": seen.size()}
				seen[fingerprint] = true
				queue.append(result.state)
				parents.append(cursor)
				actions.append({"source": source, "direction": direction})
		cursor += 1
	return {"status": "unsolvable", "visited": seen.size()}
