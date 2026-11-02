class_name GrayProgress
extends RefCounted

var path: String
var records: Dictionary = {}

func _init(save_path: String = "user://progress.json") -> void:
	path = save_path
	load_records()

func load_records() -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("records") is Dictionary:
		push_warning("GRAY: unreadable progress file; starting with empty records.")
		return
	for id in data.records:
		var record = data.records[id]
		if not record is Dictionary:
			continue
		var best = record.get("best", 0)
		if not (best is int or best is float) or best < 1 or best != floor(best):
			continue
		records[str(id)] = {"best": int(best), "easy": record.get("easy") == true,
			"hard": record.get("hard") == true}

func record_clear(id: String, steps: int, minimum: int, hard_mode: bool) -> Error:
	var previous: Dictionary = records.get(id, {})
	records[id] = {
		"best": mini(int(previous.get("best", steps)), steps),
		"easy": true,
		"hard": previous.get("hard", false) or (hard_mode and steps == minimum),
	}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "records": records}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temporary, path)

func completed(hard_mode: bool) -> int:
	var count := 0
	for record in records.values():
		if record.get("hard" if hard_mode else "easy", false):
			count += 1
	return count
