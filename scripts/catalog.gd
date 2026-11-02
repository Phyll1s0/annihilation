class_name GrayCatalog
extends RefCounted
const Puzzle = preload("res://scripts/puzzle.gd")
const RULES_VERSION := 1

static func fingerprint(level: Dictionary) -> String:
	var state := Puzzle.from_level(level)
	return JSON.stringify([RULES_VERSION, state.width, state.height, state.board, state.pieces, int(level.optimal_moves)]).sha256_text()

static func load_campaign(path: String = "res://data/levels.json") -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array or parsed.is_empty():
		return {"levels": [], "errors": ["关卡目录为空或格式错误。"]}
	var errors: Array[String] = []
	var ids := {}
	for definition in parsed:
		var error := validate(definition)
		if not error.is_empty():
			errors.append(error)
			continue
		if ids.has(definition.id):
			errors.append("重复的关卡编号：" + definition.id)
		ids[definition.id] = true
	return {"levels": parsed if errors.is_empty() else [], "errors": errors}

static func _integer(value) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value)

static func validate(level) -> String:
	if not level is Dictionary:
		return "关卡必须是对象。"
	for field in ["id", "title", "chapter", "description"]:
		if not level.get(field) is String or level[field].is_empty():
			return "缺少关卡文字字段：" + field
	var prefix: String = level.id + "："
	var rows = level.get("layout")
	if not rows is Array or rows.is_empty() or not rows[0] is String or rows[0].is_empty():
		return prefix + "地图为空。"
	var width: int = rows[0].length()
	for row in rows:
		if not row is String or row.length() != width:
			return prefix + "地图必须每行等宽。"
		for glyph in row:
			if not glyph in "#.wbABCDEFGHIJKLMNOPQRSTUVWXYZ":
				return prefix + "包含未知地图字符。"
	var tokens = level.get("tokens", [])
	if not tokens is Array:
		return prefix + "额外棋子格式错误。"
	var occupied := {}
	for token in tokens:
		if not token is Array or token.size() != 2 or not _integer(token[0]) or not _integer(token[1]):
			return prefix + "棋子坐标与颜色必须为整数。"
		var cell := int(token[0])
		if cell < 0 or cell >= width * rows.size() or not int(token[1]) in [-1, 1] or occupied.has(cell):
			return prefix + "棋子越界、重复或颜色错误。"
		var glyph: String = rows[cell / width][cell % width]
		if glyph in "#wb":
			return prefix + "额外棋子覆盖了缺失地板或已有棋子。"
		occupied[cell] = true
	if not _integer(level.get("optimal_moves")) or level.optimal_moves < 1:
		return prefix + "缺少有效的最优步数。"
	var state := Puzzle.from_level(level)
	var balance := 0
	var count := 0
	for piece in state.pieces:
		balance += piece
		count += 1 if piece != 0 else 0
	if balance != 0 or count == 0:
		return prefix + "需要数量相等且非零的黑白棋子。"
	for group in range(1, 27):
		if not state.board.count(group) in [0, 2]:
			return prefix + "传送门必须成对出现。"
	var solution = level.get("solution")
	if not solution is Array or solution.size() != int(level.optimal_moves):
		return prefix + "解法长度与最优步数不符。"
	for action in solution:
		if not action is Dictionary or not _integer(action.get("source")) or not action.get("direction") is String:
			return prefix + "解法动作格式错误。"
		var result := Puzzle.move(state, int(action.source), action.direction)
		if result.is_empty():
			return prefix + "解法包含非法移动。"
		state = result.state
	if not Puzzle.won(state):
		return prefix + "解法未能清空棋盘。"
	var proof = level.get("proof")
	if not proof is Dictionary or proof.get("method") != "exhaustive_bfs":
		return prefix + "缺少 BFS 认证记录。"
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
