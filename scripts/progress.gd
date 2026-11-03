class_name NullProgress
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const UserData = preload("res://scripts/user_data.gd")
var path: String
var records: Dictionary = {}
var resume: Dictionary = {}
var loaded_version := 2

func _init(save_path: String = "user://progress.json") -> void:
	path = save_path
	if save_path == "user://progress.json":
		var error := UserData.migrate_legacy()
		if error != OK:
			push_warning("ANNIHILATION: could not migrate existing progress (error %d)." % error)
	load_records()

func load_records() -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or (data.get("version") != 1 and data.get("version") != 2) or not data.get("records") is Dictionary:
		push_warning("ANNIHILATION: unreadable progress file; starting with empty records.")
		return
	loaded_version = int(data.version)
	for id in data.records:
		var record = data.records[id]
		if not record is Dictionary:
			continue
		var best = record.get("best", 0)
		if not (best is int or best is float) or best < 1 or best != floor(best):
			continue
		records[str(id)] = {"best": int(best), "easy": record.get("easy") == true or record.get("hard") == true,
			"hard": record.get("hard") == true, "content_hash": str(record.get("content_hash", ""))}
	var saved = data.get("resume")
	if saved is Dictionary and saved.get("level_id") is String and saved.get("content_hash") is String and saved.get("hard_mode") is bool and saved.get("actions") is Array and saved.actions.size() <= 10000:
		resume = saved

func bind_catalog(levels: Array) -> void:
	var legacy = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_v1.json"))
	if not legacy is Dictionary:
		legacy = {}
	var matching := {}
	for level in levels:
		if not records.has(level.id):
			continue
		var record: Dictionary = records[level.id]
		var hash_value := Catalog.fingerprint(level)
		var saved_hash: String = record.content_hash
		if loaded_version == 1:
			saved_hash = legacy.get(level.id, "")
		if saved_hash == hash_value:
			record.content_hash = hash_value
			matching[level.id] = record
	records = matching
	loaded_version = 2
	if not resume.is_empty():
		var index := Catalog.index_of(levels, str(resume.get("level_id", "")))
		if index < 0 or resume.get("content_hash") != Catalog.fingerprint(levels[index]):
			resume = {}

func record_clear(level: Dictionary, steps: int, hard_mode: bool) -> Error:
	if steps < int(level.optimal_moves):
		return ERR_INVALID_DATA
	var previous: Dictionary = records.get(level.id, {})
	var hash_value := Catalog.fingerprint(level)
	if previous.get("content_hash") != hash_value:
		previous = {}
	records[level.id] = {
		"best": mini(int(previous.get("best", steps)), steps), "easy": true,
		"hard": previous.get("hard", false) or (hard_mode and steps == int(level.optimal_moves)),
		"content_hash": hash_value,
	}
	resume = {}
	return save()

func checkpoint(session) -> Error:
	resume = {} if Puzzle.won(session.state) else {
		"level_id": session.level.id, "content_hash": Catalog.fingerprint(session.level),
		"hard_mode": session.hard_mode, "actions": session.actions(),
	}
	return save()

func save() -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 2, "records": records, "resume": resume}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temporary, path)

func easy_cleared(id: String) -> bool:
	var record: Dictionary = records.get(id, {})
	return record.get("easy", false) or record.get("hard", false)

func chapter_complete(levels: Array, chapter: String) -> bool:
	var found := false
	for level in levels:
		if level.chapter != chapter: continue
		found = true
		if not easy_cleared(level.id): return false
	return found

func unlocked_chapters(levels: Array, developer: bool = false) -> Array[String]:
	var unlocked: Array[String] = []
	for chapter in Catalog.chapters(levels):
		unlocked.append(chapter)
		if not developer and not chapter_complete(levels, chapter): break
	return unlocked

func level_unlocked(levels: Array, index: int, developer: bool = false) -> bool:
	return index >= 0 and index < levels.size() and levels[index].chapter in unlocked_chapters(levels, developer)

func blocking_chapter(levels: Array, target: String) -> String:
	for chapter in Catalog.chapters(levels):
		if chapter == target: return ""
		if not chapter_complete(levels, chapter): return chapter
	return ""

func completed(hard_mode: bool) -> int:
	var count := 0
	for record in records.values():
		var cleared: bool = record.get("hard", false) if hard_mode else (record.get("easy", false) or record.get("hard", false))
		if cleared:
			count += 1
	return count
