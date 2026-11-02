class_name NullEditorSolver
extends RefCounted
## Packed-state BFS: authoring searches never retain full Variant board snapshots.
const Puzzle = preload("res://scripts/puzzle.gd")
var thread := Thread.new()
var mutex := Mutex.new()
var cancelled := false
var visited := 0
var initial: Dictionary
var budget := 100000
var deadline := 0
var queue: Array[PackedByteArray] = []
var parents := PackedInt32Array()
var sources := PackedInt32Array()
var directions := PackedByteArray()
var names := ["up", "right", "down", "left"]
var seen := {}
var cursor := 0
var result: Dictionary = {}
var cooperative := false

func start(state: Dictionary, max_states: int = 250000, milliseconds: int = 45000, background: bool = true) -> Error:
	initial = state.duplicate(true)
	budget = mini(max_states, maxi(1000, 48000000 / (state.board.size() * 2 + 64)))
	deadline = Time.get_ticks_msec() + milliseconds
	queue = [_pack(initial)]
	parents = PackedInt32Array([-1])
	sources = PackedInt32Array([-1])
	directions = PackedByteArray([0])
	seen = {queue[0]: true}
	cooperative = OS.has_feature("web") or not background
	if cooperative: return OK
	return thread.start(_search, Thread.PRIORITY_LOW)

func poll() -> Dictionary:
	if cooperative:
		_step(4)
		return result
	if thread.is_started() and not thread.is_alive():
		return thread.wait_to_finish()
	return {}

func shutdown() -> void:
	cancel()
	if thread.is_started(): thread.wait_to_finish()

func cancel() -> void:
	mutex.lock()
	cancelled = true
	mutex.unlock()

func count() -> int:
	mutex.lock()
	var value := visited
	mutex.unlock()
	return value

func _pack(state: Dictionary) -> PackedByteArray:
	var count_cells: int = state.board.size()
	var key := PackedByteArray()
	key.resize(count_cells * 2)
	for i in count_cells:
		key[i] = int(state.board[i]) + 1
		key[i + count_cells] = int(state.pieces[i]) + 1
	return key

func _unpack(key: PackedByteArray) -> Dictionary:
	var cells: int = key.size() / 2
	var board: Array[int] = []
	var pieces: Array[int] = []
	for i in cells:
		board.append(int(key[i]) - 1)
		pieces.append(int(key[i + cells]) - 1)
	return {"width": initial.width, "height": initial.height, "board": board, "pieces": pieces}

func _search() -> Dictionary:
	while result.is_empty(): _step(20)
	return result

func _step(milliseconds: int) -> void:
	var until := Time.get_ticks_msec() + milliseconds
	while result.is_empty() and cursor < queue.size():
		mutex.lock()
		visited = queue.size()
		var stop := cancelled
		mutex.unlock()
		if stop:
			result = {"status": "cancelled", "visited": seen.size()}
			return
		if Time.get_ticks_msec() >= deadline:
			result = {"status": "limit", "visited": seen.size()}
			return
		var state := _unpack(queue[cursor])
		if Puzzle.won(state):
			var path: Array = []
			var node := cursor
			while parents[node] >= 0:
				path.push_front({"source": sources[node], "direction": names[directions[node]]})
				node = parents[node]
			result = {"status": "solved", "moves": path.size(), "solution": path, "visited": seen.size()}
			return
		for source in state.pieces.size():
			if state.pieces[source] == 0: continue
			for direction in 4:
				var moved := Puzzle.move(state, source, names[direction])
				if moved.is_empty(): continue
				var key := _pack(moved.state)
				if seen.has(key): continue
				if seen.size() >= budget:
					result = {"status": "limit", "visited": seen.size()}
					return
				seen[key] = true
				queue.append(key)
				parents.append(cursor)
				sources.append(source)
				directions.append(direction)
		cursor += 1
		if Time.get_ticks_msec() >= until: return
	if result.is_empty() and cursor >= queue.size(): result = {"status": "unsolvable", "visited": seen.size()}
