class_name NullEditorModel
extends RefCounted
const Puzzle = preload("res://scripts/puzzle.gd")
const Catalog = preload("res://scripts/catalog.gd")
const MAX_SIZE := 12
var id := ""
var title := "Untitled"
var width := 7
var height := 7
var board: Array[int] = []
var pieces: Array[int] = []
var revision := 0
var dirty := false
var last_error := ""
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var before: Dictionary = {}

func _init() -> void:
	id = "custom_" + Crypto.new().generate_random_bytes(10).hex_encode()
	board.resize(width * height)
	pieces.resize(width * height)
	board.fill(0)
	pieces.fill(0)

func state() -> Dictionary:
	return {"width": width, "height": height, "board": board, "pieces": pieces}

func snapshot() -> Dictionary:
	return {"width": width, "height": height, "board": board.duplicate(), "pieces": pieces.duplicate(),
		"title": title}

func begin_edit() -> void:
	if before.is_empty():
		before = snapshot()

func commit_edit() -> void:
	if before.is_empty():
		return
	if before != snapshot():
		history.append(before)
		if history.size() > 128:
			history.pop_front()
		future.clear()
	before = {}

func _changed() -> void:
	revision += 1
	dirty = true

func paint(cell: int, brush: String, group: int = 1) -> bool:
	last_error = ""
	if cell < 0 or cell >= board.size():
		return false
	var tile: int = board[cell]
	var piece: int = pieces[cell]
	match brush:
		"floor": tile = 0
		"void": tile = -1; piece = 0
		"white": tile = maxi(tile, 0); piece = 1
		"black": tile = maxi(tile, 0); piece = -1
		"clear": piece = 0
		"portal":
			if group < 1 or group > 26:
				return false
			if tile != group and board.count(group) >= 2:
				last_error = "This portal already has two ends."
				return false
			tile = group
		_: return false
	if tile == board[cell] and piece == pieces[cell]:
		return false
	var single := before.is_empty()
	begin_edit()
	board[cell] = tile
	pieces[cell] = piece
	_changed()
	if single:
		commit_edit()
	return true

func resize_grid(next_width: int, next_height: int) -> void:
	next_width = clampi(next_width, 1, MAX_SIZE)
	next_height = clampi(next_height, 1, MAX_SIZE)
	if next_width == width and next_height == height:
		return
	commit_edit()
	begin_edit()
	var next_board: Array[int] = []
	var next_pieces: Array[int] = []
	next_board.resize(next_width * next_height)
	next_pieces.resize(next_width * next_height)
	next_board.fill(-1)
	next_pieces.fill(0)
	for y in mini(height, next_height):
		for x in mini(width, next_width):
			next_board[y * next_width + x] = board[y * width + x]
			next_pieces[y * next_width + x] = pieces[y * width + x]
	width = next_width
	height = next_height
	board = next_board
	pieces = next_pieces
	_changed()
	commit_edit()

func rename(value: String) -> void:
	value = value.strip_edges().left(64)
	if value.is_empty():
		value = "Untitled"
	if value == title:
		return
	commit_edit()
	begin_edit()
	title = value
	_changed()
	commit_edit()

func _restore(value: Dictionary) -> void:
	width = value.width
	height = value.height
	board.assign(value.board)
	pieces.assign(value.pieces)
	title = value.title
	revision += 1
	dirty = true

func undo() -> void:
	commit_edit()
	if history.is_empty(): return
	future.append(snapshot())
	_restore(history.pop_back())

func redo() -> void:
	commit_edit()
	if future.is_empty(): return
	history.append(snapshot())
	_restore(future.pop_back())

func validation_error() -> String:
	if pieces.count(1) == 0 or pieces.count(-1) == 0:
		return "Place at least one black and one white particle."
	if pieces.count(1) != pieces.count(-1):
		return "Black and white counts must match."
	for group in range(1, 27):
		if not board.count(group) in [0, 2]:
			return "Every portal group needs exactly two ends."
	return ""

func definition() -> Dictionary:
	var rows: Array[String] = []
	var tokens: Array = []
	for y in height:
		var row := ""
		for x in width:
			var cell := y * width + x
			if board[cell] > 0:
				row += String.chr(64 + board[cell])
				if pieces[cell] != 0:
					tokens.append([cell, pieces[cell]])
			else:
				row += "#" if board[cell] < 0 else ("w" if pieces[cell] == 1 else ("b" if pieces[cell] == -1 else "."))
		rows.append(row)
	var level := {"id": id, "title": title, "chapter": "Custom", "description": "Custom level", "layout": rows,
		"optimal_moves": 0}
	if not tokens.is_empty(): level.tokens = tokens
	return level

func document() -> Dictionary:
	return {"format": "null-level", "version": 1, "level": definition()}

static func parse(value, new_identity: bool = true) -> Dictionary:
	if not value is Dictionary:
		return {"error": "Choose a NULL level JSON file."}
	if value.has("format"):
		if value.format != "null-level" or value.get("version") != 1:
			return {"error": "Unsupported level file version."}
		value = value.get("level")
	if not value is Dictionary or not value.get("layout") is Array:
		return {"error": "Choose a NULL level JSON file."}
	var rows: Array = value.layout
	if rows.size() < 1 or rows.size() > MAX_SIZE or not rows[0] is String or rows[0].length() < 1 or rows[0].length() > MAX_SIZE:
		return {"error": "Maps can be up to 12 by 12 tiles."}
	var columns: int = rows[0].length()
	for row in rows:
		if not row is String or row.length() != columns:
			return {"error": "All rows must have the same width."}
		for glyph in row:
			if not glyph in "#.wbABCDEFGHIJKLMNOPQRSTUVWXYZ":
				return {"error": "The map contains an unknown tile."}
	var tokens = value.get("tokens", [])
	if not tokens is Array: return {"error": "Invalid particle positions."}
	var occupied := {}
	for token in tokens:
		if not token is Array or token.size() != 2 or not Catalog._integer(token[0]) or not Catalog._integer(token[1]):
			return {"error": "Invalid particle positions."}
		var cell := int(token[0])
		if cell < 0 or cell >= columns * rows.size() or int(token[1]) not in [-1, 1] or occupied.has(cell):
			return {"error": "Invalid particle positions."}
		if rows[cell / columns][cell % columns] in "#wb":
			return {"error": "A particle overlaps another particle or a missing tile."}
		occupied[cell] = true
	var model := NullEditorModel.new()
	var source := Puzzle.from_level(value)
	model.width = source.width
	model.height = source.height
	model.board.assign(source.board)
	model.pieces.assign(source.pieces)
	if value.get("title") is String and not value.title.strip_edges().is_empty():
		model.title = value.title.strip_edges().left(64)
	if not new_identity and value.get("id") is String:
		var pattern := RegEx.create_from_string("^custom_[a-zA-Z0-9_]+$")
		if pattern.search(value.id) != null: model.id = value.id
	return {"model": model, "error": ""}
