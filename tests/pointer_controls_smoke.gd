extends SceneTree
## Exercise pointer selection and keyboard-only movement through real UI events.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var viewport: SubViewport
var app
var checks := 0
var failures := 0
var directory := "user://pointer_controls_%d" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		viewport.push_input(event, true)

func cell(index: int) -> void:
	click(app.game.board.global_position + app.game.board.center_of(index))

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	redraw(viewport)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://builds/pointer-controls-" + name_value + ".png")

func redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): redraw(child)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("settings.cfg")
	check(not Settings.new(path).keyboard_only_movement, "Older settings keep mouse movement enabled")
	var invalid := ConfigFile.new()
	invalid.set_value("preferences", "keyboard_only_movement", "yes")
	invalid.save(path)
	check(not Settings.new(path).keyboard_only_movement, "Invalid saved input preferences fall back safely")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(path)
	app.settings.reduce_motion = true
	app.settings.music_enabled = false
	app.settings.developer_mode = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	viewport.add_child(app)
	app.start_level(5, false)
	await settle()
	var original := Puzzle.key(app.game.session.state)
	var checkpoint := FileAccess.get_file_as_string(app.progress.path)
	for point in [app.game.board.global_position + Vector2.ONE,
		app.game.board.global_position + app.game.board.center_of(6), Vector2(640, 8)]:
		cell(0)
		check(app.game.session.selected == 0, "Clicking a particle selects it")
		click(point)
		check(app.game.session.selected == -1, "Board margins, holes and the surrounding sky deselect")
	check(Puzzle.key(app.game.session.state) == original and app.game.session.steps == 0 and app.game.session.history.is_empty(), "Deselecting leaves particles, steps and undo history intact")
	check(FileAccess.get_file_as_string(app.progress.path) == checkpoint, "Selection changes do not rewrite the campaign checkpoint")
	cell(0)
	cell(1)
	check(app.game.session.steps == 1 and app.game.session.selected == 1, "Mouse movement still works with the switch off")
	var before := Puzzle.key(app.game.session.state)
	app._navigate("settings")
	await settle()
	click(app.preferences.controls_button.get_global_rect().get_center())
	await settle()
	check(app.preferences.controls.visible, "The Controls tab opens by pointer input")
	click(app.preferences.switches.keyboard_only_movement.get_global_rect().get_center())
	check(app.settings.keyboard_only_movement and Settings.new(path).keyboard_only_movement, "The Controls switch enables and saves keyboard-only movement")
	check(app.preferences.pointer_action.text == "Select particle" and app.preferences.pointer_binding.text == "Click a particle", "Controls describe selection-only mouse input")
	check(Puzzle.key(app.game.session.state) == before and app.game.session.steps == 1 and app.game.session.selected == 1, "Changing the switch preserves the current run and selection")
	viewport.size = Vector2i(960, 680)
	await settle()
	await capture("en-960")
	app.settings.language = "zh_CN"
	app.settings.apply_language()
	await settle()
	check(app.preferences.pointer_action.text == "选中粒子", "Selection-only instructions follow the selected language")
	await capture("zh-960")
	app.settings.language = "en"
	app.settings.apply_language()
	viewport.size = Vector2i(1280, 820)
	app._navigate("back")
	app.start_level(0, false)
	await settle()
	cell(0)
	cell(1)
	check(app.game.session.selected == 1 and app.game.session.steps == 0 and not Puzzle.won(app.game.session.state), "Clicking an adjacent opposite particle selects it without a collision")
	cell(1)
	check(app.game.session.selected == -1, "Clicking the selected particle again deselects it")
	cell(1)
	key(KEY_LEFT)
	check(app.game.session.cleared() and app.game.session.steps == 1, "Arrow keys still move and merge particles")
	app.start_level(1, false)
	await settle()
	cell(0)
	cell(1)
	check(app.game.session.selected == -1 and app.game.session.steps == 0, "Empty floor only deselects in keyboard-only mode")
	cell(0)
	key(KEY_D)
	check(app.game.session.steps == 1 and app.game.session.selected == 1, "WASD still moves the selected particle")
	key(KEY_TAB)
	check(app.game.session.selected == 3, "Keyboard selection cycling remains available")
	app.pause_game()
	click(Vector2(640, 8))
	check(app.game.session.selected == 3, "Clicks behind the pause menu cannot change selection")
	app.resume_game()
	click(Vector2(640, 8))
	check(app.game.session.selected == -1, "Blank space works again after resuming")
	app._navigate("settings")
	await settle()
	app.preferences._tab(true)
	await settle()
	click(app.preferences.switches.keyboard_only_movement.get_global_rect().get_center())
	check(not app.settings.keyboard_only_movement and not Settings.new(path).keyboard_only_movement, "Disabling the switch is saved too")
	app._navigate("back")
	app.start_level(0, false)
	await settle()
	cell(0)
	cell(1)
	check(app.game.session.cleared(), "Disabling the switch restores mouse collisions")
	viewport.queue_free()
	await settle()
	for file_name in ["settings.cfg", "progress.json"]: DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
	print("ANNIHILATION pointer controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
