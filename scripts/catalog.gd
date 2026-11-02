class_name NullCatalog
extends RefCounted
const Puzzle = preload("res://scripts/puzzle.gd")
const RULES_VERSION := 1

static func fingerprint(level: Dictionary) -> String:
	var state := Puzzle.from_level(level)
	return JSON.stringify([RULES_VERSION, state.width, state.height, state.board, state.pieces, int(level.optimal_moves)]).sha256_text()

static func load_campaign(path: String = "res://data/levels.json") -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array or parsed.is_empty():
		return {"levels": [], "errors": ["The level catalog is empty or malformed."]}
	var errors: Array[String] = []
	var ids := {}
	for definition in parsed:
		var error := validate(definition)
		if not error.is_empty():
			errors.append(error)
			continue
		if ids.has(definition.id):
			errors.append("Duplicate level ID: " + definition.id)
		ids[definition.id] = true
	return {"levels": parsed if errors.is_empty() else [], "errors": errors}

static func _integer(value) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value)

static func validate(level) -> String:
	if not level is Dictionary:
		return "Each level must be an object."
	for field in ["id", "title", "chapter", "description"]:
		if not level.get(field) is String or level[field].is_empty():
			return "Missing level text field: " + field
	var prefix: String = level.id + ": "
	var rows = level.get("layout")
	if not rows is Array or rows.is_empty() or not rows[0] is String or rows[0].is_empty():
		return prefix + "The layout is empty."
	var width: int = rows[0].length()
	for row in rows:
		if not row is String or row.length() != width:
			return prefix + "All layout rows must have the same width."
		for glyph in row:
			if not glyph in "#.wbABCDEFGHIJKLMNOPQRSTUVWXYZ":
				return prefix + "Unknown layout character."
	var tokens = level.get("tokens", [])
	if not tokens is Array:
		return prefix + "Malformed additional particles."
	var occupied := {}
	for token in tokens:
		if not token is Array or token.size() != 2 or not _integer(token[0]) or not _integer(token[1]):
			return prefix + "Particle coordinates and colors must be integers."
		var cell := int(token[0])
		if cell < 0 or cell >= width * rows.size() or not int(token[1]) in [-1, 1] or occupied.has(cell):
			return prefix + "A particle is out of bounds, duplicated, or has an invalid color."
		var glyph: String = rows[cell / width][cell % width]
		if glyph in "#wb":
			return prefix + "An additional particle overlaps a missing tile or another particle."
		occupied[cell] = true
	if not _integer(level.get("optimal_moves")) or level.optimal_moves < 1:
		return prefix + "Missing a valid minimum move count."
	var state := Puzzle.from_level(level)
	var balance := 0
	var count := 0
	for piece in state.pieces:
		balance += piece
		count += 1 if piece != 0 else 0
	if balance != 0 or count == 0:
		return prefix + "Black and white particle counts must be equal and nonzero."
	for group in range(1, 27):
		if not state.board.count(group) in [0, 2]:
			return prefix + "Portals must appear in pairs."
	var solution = level.get("solution")
	if not solution is Array or solution.size() != int(level.optimal_moves):
		return prefix + "Solution length does not match the minimum move count."
	for action in solution:
		if not action is Dictionary or not _integer(action.get("source")) or not action.get("direction") is String:
			return prefix + "Malformed solution action."
		var result := Puzzle.move(state, int(action.source), action.direction)
		if result.is_empty():
			return prefix + "The solution contains an illegal move."
		state = result.state
	if not Puzzle.won(state):
		return prefix + "The solution does not clear the board."
	var proof = level.get("proof")
	if not proof is Dictionary or proof.get("method") != "exhaustive_bfs":
		return prefix + "Missing BFS certification."
	return ""

static func chapters(levels: Array) -> Array[String]:
	var result: Array[String] = []
	for level in levels:
		if not level.chapter in result:
			result.append(level.chapter)
	return result

static func index_of(levels: Array, id: String) -> int:
	for i in levels.size():
		if levels[i].id == id:
			return i
	return -1

static func recommended(levels: Array, records: Dictionary, hard: bool) -> int:
	for i in levels.size():
		if not records.get(levels[i].id, {}).get("hard" if hard else "easy", false):
			return i
	return 0
