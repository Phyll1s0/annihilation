class_name NullEditorLibrary
extends RefCounted
const Model = preload("res://scripts/editor_model.gd")
var directory: String

func _init(path: String = "user://editor") -> void:
	directory = path
	DirAccess.make_dir_recursive_absolute(directory.path_join("levels"))

func _write(path: String, model) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(model.document(), "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	var renamed := DirAccess.rename_absolute(path + ".tmp", path)
	if renamed == OK and OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return renamed

func save_draft(model) -> Error:
	return _write(directory.path_join("draft.json"), model)

func save_level(model) -> Error:
	return _write(directory.path_join("levels").path_join(model.id + ".json"), model)

func archive_draft(model) -> Error:
	var target = model
	if FileAccess.file_exists(directory.path_join("levels").path_join(model.id + ".json")):
		target = Model.parse(model.document()).model
		target.title = model.title.left(54) + " · " + tr("Draft")
	return save_level(target)

func load_file(path: String, new_identity: bool = true) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Could not open the level file."}
	if file.get_length() > 1000000: return {"error": "The level file is too large."}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {"error": "The file is not valid JSON."}
	return Model.parse(json.data, new_identity)

func load_draft():
	var result := load_file(directory.path_join("draft.json"), false)
	if not result.has("model"): return Model.new()
	var model = result.model
	var saved := load_file(directory.path_join("levels").path_join(model.id + ".json"), false)
	model.dirty = not saved.has("model") or saved.model.definition() != model.definition()
	return model

func list_levels() -> Array:
	var folder := DirAccess.open(directory.path_join("levels"))
	var result: Array = []
	if folder == null: return result
	for name in folder.get_files():
		if not name.ends_with(".json"): continue
		var path := directory.path_join("levels").path_join(name)
		var parsed := load_file(path, false)
		if parsed.has("model"):
			result.append({"title": parsed.model.title, "path": path, "definition": parsed.model.definition(), "playable": parsed.model.validation_error().is_empty()})
	result.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0 if a.title != b.title else a.path < b.path)
	return result
