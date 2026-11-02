extends RefCounted
## Preserve existing local saves when the display name changes.

static func migrate_file(file_name: String, destination_directory: String = "", source_directory: String = "") -> Error:
	var directory := OS.get_user_data_dir() if destination_directory.is_empty() else destination_directory
	var legacy := directory.get_base_dir().path_join("GRAY") if source_directory.is_empty() else source_directory
	var destination := directory.path_join(file_name)
	var source := legacy.path_join(file_name)
	if FileAccess.file_exists(destination) or not FileAccess.file_exists(source):
		return OK
	var error := DirAccess.make_dir_recursive_absolute(directory)
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
