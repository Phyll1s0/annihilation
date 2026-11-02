extends SceneTree
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Model = preload("res://scripts/editor_model.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var directory := "user://library_test_%d" % OS.get_process_id()
var app
var viewport: SubViewport
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame

func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event,true)

func escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	viewport.push_input(event,true)

func make_app() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.reduce_motion = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	app.editor_directory = directory.path_join("editor")
	viewport.add_child(app)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	redraw(viewport)
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png("res://builds/"+name_value+".png")

func redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): redraw(child)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	make_app()
	await settle()
	click(app.home.continue_button)
	await settle()
	check(app.screen == "campaign", "Start opens the level selection page")
	click(app.campaign.my_levels_button)
	await settle()
	check(app.screen == "my_levels" and app.my_levels.rows.is_empty() and app.my_levels.empty_label != null, "Selection has a discoverable empty My levels page")
	click(app.my_levels.create_button)
	await settle()
	check(app.screen == "editor", "Create in My levels opens the editor")
	app.editor._replace(Model.parse({"layout":["wb"],"title":"First Orbit"}).model)
	app.editor._save()
	var saved_id: String = app.editor.model.id
	app._navigate("editor_back")
	await settle()
	check(app.screen == "my_levels" and app.my_levels.rows.size() == 1, "Saving a map makes it available in level selection")
	app.start_level(1,true)
	app.game.session.selected = 0
	app.game._try_move("right")
	var campaign_state := Puzzle.key(app.game.session.state)
	var campaign_save := FileAccess.get_file_as_string(app.progress.path)
	app.show_screen("home")
	click(app.home.continue_button)
	await settle()
	check(app.screen == "campaign" and app.campaign.resume_button.visible, "Start still opens selection with a live campaign checkpoint")
	click(app.campaign.resume_button)
	await settle()
	check(app.screen == "game" and app.game.session.steps == 1 and Puzzle.key(app.game.session.state) == campaign_state, "Selection Continue resumes the saved game")
	app._navigate("my_levels")
	await settle()
	click(app.my_levels.rows[0].play)
	await settle()
	check(app.screen == "editor_test" and app.test_game.custom_return == "my_levels" and not app.test_game.modes.visible, "Saved levels play directly without opening the editor")
	app.test_game.session.selected = 0
	app.test_game._try_move("right")
	await settle()
	check(app.custom_records.best(app.test_game.session.level) == 1, "Playing from selection updates the shared leaderboard")
	app.pause_game()
	click(app.pause_actions.levels)
	await settle()
	check(app.screen == "my_levels", "Custom pause Back to my levels returns to selection")
	click(app.my_levels.rows[0].play)
	await settle()
	app.test_game.session.selected = 0
	app.test_game._try_move("right")
	app.test_game._next()
	await settle()
	check(app.screen == "my_levels", "Completing a saved map returns to My levels")
	click(app.my_levels.rows[0].scores)
	await settle()
	check(app.my_levels.records_dialog.visible and app.my_levels.records_dialog.table.get_child_count() == 1, "My levels opens the local leaderboard")
	app.my_levels.records_dialog.player_input.text = "Visitor"
	app.my_levels.records_dialog.save_player()
	escape()
	await settle()
	check(app.screen == "my_levels" and not app.my_levels.records_dialog.visible, "Escape closes the leaderboard without leaving My levels")
	click(app.my_levels.rows[0].edit)
	await settle()
	check(app.screen == "editor" and app.editor.model.id == saved_id and app.editor.records.player == "Visitor", "Edit reopens the saved map and shares the player profile")
	app.editor.model.paint(0,"black")
	app.editor._edited()
	app.editor._persist()
	var edited: Dictionary = app.editor.model.state().duplicate(true)
	app._navigate("editor_back")
	await settle()
	click(app.my_levels.rows[0].edit)
	await settle()
	check(app.editor.model.state() == edited, "Reopening Edit preserves active unsaved changes to that map")
	var second = Model.parse({"layout":["w..b"],"title":"Second Orbit"}).model
	app.custom_library.save_level(second)
	app._navigate("editor_back")
	await settle()
	for row in app.my_levels.rows:
		if row.definition.id == second.id: click(row.edit); break
	await settle()
	check(app.editor.model.id == second.id, "Another saved map can be opened for editing")
	app._navigate("editor_back")
	await settle()
	var unfinished := 0
	for row in app.my_levels.rows:
		if row.play.disabled: unfinished += 1
	check(unfinished == 1, "Unsaved incomplete edits remain as a draft copy and cannot start a broken game")
	check(FileAccess.get_file_as_string(app.progress.path) == campaign_save and Puzzle.key(app.game.session.state) == campaign_state, "Custom selection, editing, and records preserve campaign progress")
	for dimensions in [Vector2i(960,680),Vector2i(1280,820),Vector2i(2940,1846),Vector2i(5120,2880),Vector2i(960,1280)]:
		viewport.size = dimensions
		for language in Settings.LANGUAGES:
			app.settings.language = language
			app.settings.apply_language()
			await settle()
			var screen := Rect2(Vector2.ZERO,Vector2(dimensions))
			for control in [app.my_levels.frame, app.my_levels.tabs, app.my_levels.create_button, app.my_levels.rows[0].play, app.my_levels.rows[0].scores, app.my_levels.rows[0].edit]:
				check(screen.encloses(control.get_global_rect()), "My levels controls fit after resizing and translating")
			if dimensions.x in [960,1280] and dimensions.y == 680 or dimensions == Vector2i(1280,820):
				await capture("my-levels-%s-%dx%d" % [language,dimensions.x,dimensions.y])
	viewport.remove_child(app)
	app.queue_free()
	await settle()
	make_app()
	app._navigate("my_levels")
	await settle()
	check(app.my_levels.rows.size() == 3 and app.custom_records.player == "Visitor", "Saved maps, draft copies, and profiles survive restarting")
	check(app.custom_records.best(app.my_levels.rows[0].definition) == 1, "Selection records survive restarting")
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("NULL library: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name in folder.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories(): remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
