extends RefCounted
## Preserve existing local saves when the display name changes.
const MIGRATION_MARKER := ".annihilation-migration-v1"
const SAVE_FILES := ["progress.json", "settings.cfg", "editor/draft.json", "editor/records.json", "editor/playtest.json"]

static func migrate_legacy(destination_directory: String = "", source_directories: Array[String] = []) -> Error:
	var directory := OS.get_user_data_dir() if destination_directory.is_empty() else destination_directory
	var marker := directory.path_join(MIGRATION_MARKER)
	if FileAccess.file_exists(marker): return OK
	var sources: Array[String] = source_directories.duplicate()
	if sources.is_empty():
		for name_value in ["NULL", "GRAY"]:
			sources.append(directory.get_base_dir().path_join(name_value))
	for legacy in sources:
		if legacy == directory: continue
		for relative in SAVE_FILES:
			var error := migrate_file(relative, directory, legacy)
			if error != OK: return error
		var level_directory := legacy.path_join("editor/levels")
		if not DirAccess.dir_exists_absolute(level_directory): continue
		var levels := DirAccess.open(level_directory)
		if levels == null: return DirAccess.get_open_error()
		for file_name in levels.get_files():
			if not file_name.ends_with(".json"): continue
			var error := migrate_file("editor/levels/" + file_name, directory, legacy)
			if error != OK: return error
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var file := FileAccess.open(marker, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string("1\n")
	file.flush()
	return file.get_error()

static func migrate_file(file_name: String, destination_directory: String = "", source_directory: String = "") -> Error:
	var directory := OS.get_user_data_dir() if destination_directory.is_empty() else destination_directory
	var legacy := directory.get_base_dir().path_join("GRAY") if source_directory.is_empty() else source_directory
	var destination := directory.path_join(file_name)
	var source := legacy.path_join(file_name)
	if FileAccess.file_exists(destination) or not FileAccess.file_exists(source):
		return OK
	var error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if error != OK:
		return error
	var temporary := destination + ".%d.migration.tmp" % OS.get_process_id()
	error = DirAccess.copy_absolute(source, temporary)
	if error != OK:
		return error
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(temporary)
		return OK
	return DirAccess.rename_absolute(temporary, destination)
