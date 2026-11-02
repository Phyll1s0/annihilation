class_name NullCustomRecords
extends RefCounted
## Best known completed runs, never a claim of a theoretical minimum.
const Puzzle = preload("res://scripts/puzzle.gd")
const RULES_VERSION := 1
const MAX_ENTRIES := 100
const MAX_ACTIONS := 10000
var path: String
var player := "Player"
var boards: Dictionary = {}
var cache: Dictionary = {}

func _init(directory: String = "user://editor") -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	path = directory.path_join("records.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return
	var data: Dictionary = json.data
	if data.get("format") != "null-records" or data.get("version") != 1: return
	if data.get("boards") is Dictionary: boards = data.boards
	if data.get("player") is String: player = clean_name(data.player)

static func clean_name(value: String) -> String:
	var result := ""
	for glyph in value.strip_edges():
		if glyph.unicode_at(0) >= 32 and glyph.unicode_at(0) != 127: result += glyph
	result = result.left(32).strip_edges()
	return "Player" if result.is_empty() else result

static func fingerprint(level: Dictionary) -> String:
	var state := Puzzle.from_level(level)
	var groups := {}
	var terrain: Array = []
	for tag in state.board:
		if tag > 0:
			if not groups.has(tag): groups[tag] = groups.size() + 1
			terrain.append(groups[tag])
		else: terrain.append(tag)
	return JSON.stringify([RULES_VERSION, state.width, state.height, terrain, state.pieces]).sha256_text()

static func replay(level: Dictionary, actions) -> Array:
	if not actions is Array or actions.is_empty() or actions.size() > MAX_ACTIONS: return []
	var state := Puzzle.from_level(level)
	var canonical: Array = []
	for action in actions:
		if not action is Dictionary or not action.get("direction") is String: return []
		var source = action.get("source")
		if not (source is int or source is float) or not is_finite(source) or source != floor(source): return []
		if source < 0 or source >= state.pieces.size() or Puzzle.won(state): return []
		var result := Puzzle.move(state, int(source), action.direction)
		if result.is_empty(): return []
		canonical.append({"source": int(source), "direction": action.direction})
		state = result.state
	return canonical if Puzzle.won(state) else []

func entries(level: Dictionary) -> Array:
	var key := fingerprint(level)
	if not cache.has(key):
		cache[key] = []
		var stored = boards.get(key, {})
		if stored is Dictionary and stored.get("records") is Array:
			for entry in stored.records.slice(0, MAX_ENTRIES):
				_accept(level, entry)
	return cache[key].duplicate(true)

func best(level: Dictionary) -> int:
	var rows := entries(level)
	return 0 if rows.is_empty() else int(rows[0].moves)

func _accept(level: Dictionary, entry) -> bool:
	if not entry is Dictionary or not entry.get("player") is String: return false
	var actions := replay(level, entry.get("actions"))
	if actions.is_empty(): return false
	var name_value := clean_name(entry.player)
	var key := fingerprint(level)
	var rows: Array = cache[key]
	for i in rows.size():
		if rows[i].player.to_lower() == name_value.to_lower():
			if rows[i].moves <= actions.size(): return false
			rows.remove_at(i)
			break
	rows.append({"player": name_value, "moves": actions.size(), "actions": actions})
	rows.sort_custom(func(a, b):
		if a.moves != b.moves: return a.moves < b.moves
		return a.player.naturalnocasecmp_to(b.player) < 0)
	if rows.size() > MAX_ENTRIES: rows.resize(MAX_ENTRIES)
	return true

func _store(level: Dictionary) -> void:
	var key := fingerprint(level)
	boards[key] = {"records": cache[key].duplicate(true)}

func submit(level: Dictionary, name_value: String, actions: Array) -> Dictionary:
	entries(level)
	var previous := best(level)
	var updated := _accept(level, {"player": name_value, "actions": actions})
	if updated: _store(level)
	return {"updated": updated, "improved": updated and (previous == 0 or best(level) < previous), "saved": save() == OK}

func merge(level: Dictionary, shared) -> Dictionary:
	entries(level)
	var updated := 0
	var rejected := 0
	if not shared is Array: return {"updated": 0, "rejected": 1}
	for entry in shared.slice(0, MAX_ENTRIES):
		if not entry is Dictionary or not entry.get("player") is String or replay(level, entry.get("actions")).is_empty():
			rejected += 1
		elif _accept(level, entry): updated += 1
	if updated > 0: _store(level)
	return {"updated": updated, "rejected": rejected, "saved": save() == OK}

func document(model) -> Dictionary:
	var result: Dictionary = model.document()
	var shared: Array = []
	var remaining := 6000000
	for entry in entries(result.level):
		# Include the nested indentation used by the sharing panel.
		var formatted := JSON.stringify(entry, "\t")
		var bytes := formatted.to_utf8_buffer().size() + (formatted.count("\n") + 1) * 3 + 4
		if bytes > remaining: break
		shared.append(entry)
		remaining -= bytes
	result.records = shared
	return result

func set_player(value: String) -> Error:
	player = clean_name(value)
	return save()

func save() -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format": "null-records", "version": 1, "player": player, "boards": boards}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK and OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return error
