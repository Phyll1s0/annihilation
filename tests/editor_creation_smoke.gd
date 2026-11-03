extends SceneTree
## Reproduce creating independent maps and saving with the name field focused.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
var directory := "user://editor_creation_%d" % OS.get_process_id()
var viewport: SubViewport
var app
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame

func button(node: Node, message: String) -> Button:
	if node is Button and node.get_meta("message", "") == message: return node
	for child in node.get_children():
		var found := button(child, message)
		if found != null: return found
	return null

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)

func paint(index: int, brush: String) -> void:
	click(app.editor.brushes[brush])
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = app.editor.board.global_position + app.editor.board.center_of(index)
		event.pressed = pressed
		viewport.push_input(event, true)

func save_key(command: bool) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_S
		event.meta_pressed = command
		event.ctrl_pressed = not command
		event.pressed = pressed
		viewport.push_input(event, true)

func make_app() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.developer_mode = true
	app.settings.reduce_motion = true
	app.settings.music_enabled = false
	app.progress = Progress.new(directory.path_join("progress.json"))
	app.editor_directory = directory.path_join("editor")
	viewport.add_child(app)
	app._navigate("my_levels")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 680)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	make_app()
	await settle()
	click(app.my_levels.create_button)
	await settle()
	paint(0, "white")
	paint(1, "black")
	app.editor.title_input.grab_focus()
	app.editor.title_input.text = "Creation One"
	var first_id: String = app.editor.model.id
	var first_path: String = app.editor.directory.path_join("levels/" + first_id + ".json")
	save_key(true)
	check(FileAccess.file_exists(first_path), "Command-S saves while the level name has focus")
	click(button(app.editor, "Save"))
	check(FileAccess.file_exists(first_path) and not app.editor.model.dirty, "The Save button writes the painted map")
	var first_contents := FileAccess.get_file_as_string(first_path)
	check(JSON.parse_string(first_contents).level.title == "Creation One", "Saving includes the current name field")
	app._navigate("editor_back")
	await settle()
	check(app.my_levels.rows.size() == 1 and app.my_levels.rows[0].definition.id == first_id, "The saved creation appears in My levels")
	click(app.my_levels.create_button)
	await settle()
	check(app.editor.model.id != first_id and app.editor.model.pieces.count(0) == 49, "Create starts a new empty map with its own identity")
	if app.editor.model.id == first_id:
		await finish()
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://builds/editor-creation-960.png")
	paint(2, "white")
	paint(3, "black")
	app.editor.title_input.grab_focus()
	app.editor.title_input.text = "Creation Two"
	var second_id: String = app.editor.model.id
	save_key(false)
	check(FileAccess.file_exists(app.editor.directory.path_join("levels/" + second_id + ".json")), "Control-S also saves from the name field")
	check(FileAccess.get_file_as_string(first_path) == first_contents, "A second creation never overwrites the first")
	app._navigate("editor_back")
	app._navigate("settings")
	app.preferences._developer_tab()
	await settle()
	click(app.preferences.editor_button)
	await settle()
	check(app.editor.model.id != second_id and app.editor.model.pieces.count(0) == 49, "The Developer entry also starts a fresh map")
	paint(0, "white")
	var draft_id: String = app.editor.model.id
	var new_button := button(app.editor, "New")
	check(new_button.is_visible_in_tree(), "New is visible without expanding Map settings")
	click(new_button)
	await settle()
	check(app.editor.model.id != draft_id and app.editor.model.pieces.count(0) == 49, "New clears the workspace using a new map identity")
	check(FileAccess.file_exists(app.editor.directory.path_join("levels/" + draft_id + ".json")), "Starting another map preserves an unfinished creation")
	var saved_count: int = app.custom_library.list_levels().size()
	viewport.remove_child(app)
	app.queue_free()
	await settle()
	make_app()
	await settle()
	click(app.my_levels.create_button)
	await settle()
	check(app.editor.model.pieces.count(0) == 49 and app.custom_library.list_levels().size() == saved_count, "Restarting and creating again does not restore or archive an untouched blank draft")
	var first: Dictionary = app.custom_library.load_file(first_path, false)
	check(first.has("model") and first.model.title == "Creation One" and first.model.pieces[0] == 1 and first.model.pieces[1] == -1, "Saved creations reopen with their original name and particles")
	await finish()

func finish() -> void:
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION editor creation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name_value in folder.get_files(): DirAccess.remove_absolute(path.path_join(name_value))
	for name_value in folder.get_directories(): remove_tree(path.path_join(name_value))
	DirAccess.remove_absolute(path)
