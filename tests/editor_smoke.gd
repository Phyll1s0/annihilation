extends SceneTree
const Model = preload("res://scripts/editor_model.gd")
const Library = preload("res://scripts/editor_library.gd")
const Records = preload("res://scripts/custom_records.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
var failures := 0
var checks := 0
var viewport: SubViewport
var app
var directory := "user://editor_test_%d" % OS.get_process_id()

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
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)

func click_cell(board, index: int) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = board.global_position + board.center_of(index)
		event.pressed = pressed
		viewport.push_input(event, true)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name in folder.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories(): remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)

func redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): redraw(child)

func _run() -> void:
	var model := Model.new()
	model.resize_grid(4, 2)
	model.begin_edit()
	model.paint(0, "white")
	model.paint(1, "white")
	model.paint(2, "black")
	model.paint(3, "black")
	model.commit_edit()
	check(model.history.size() == 2, "A paint stroke is one undo action")
	model.undo()
	check(model.pieces.count(1) == 0, "Undo restores an entire stroke")
	model.redo()
	check(model.pieces.count(1) == 2, "Redo restores the particles")
	check(model.paint(0, "portal", 1) and model.paint(3, "portal", 1), "Portals can hold particles")
	check(not model.paint(4, "portal", 1), "A third end cannot silently replace a portal pair")
	var text := JSON.stringify(model.document())
	var parsed := Model.parse(JSON.parse_string(text))
	check(parsed.has("model") and parsed.model.state() == model.state(), "JSON round trips portal terrain and particles")
	check(parsed.model.id != model.id, "Imported levels get their own safe identity")
	check(not Model.parse({"layout": ["..", "."]}).has("model"), "Malformed JSON maps are rejected")
	check(not Model.parse({"layout": ["..."], "tokens": [[0,1],[0,-1]]}).has("model"), "Overlapping imported particles are rejected")
	var library := Library.new(directory)
	check(library.save_level(model) == OK and library.save_draft(model) == OK, "Incomplete drafts and levels save locally")
	check(library.load_draft().state() == model.state(), "Drafts restore after restarting")
	var catalog: Array = Catalog.load_campaign().levels
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.reduce_motion = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	app.editor_directory = directory.path_join("workspace")
	viewport.add_child(app)
	await settle()
	app.start_level(1, true)
	app.game.session.selected = 0
	app.game._try_move("right")
	var campaign_state := Puzzle.key(app.game.session.state)
	var campaign_save := FileAccess.get_file_as_string(app.progress.path)
	app.pause_game()
	app._navigate("settings")
	app.preferences._developer_tab()
	await settle()
	check(app.preferences.editor_button.disabled, "Developer mode starts disabled")
	click(app.preferences.switches.developer_mode)
	await settle()
	check(app.settings.developer_mode and not app.preferences.editor_button.disabled, "The developer toggle unlocks the editor")
	check(Settings.new(app.settings.path).developer_mode, "Developer mode persists after restarting")
	click(app.preferences.editor_button)
	await settle()
	check(app.screen == "editor" and app.editor != null, "Settings opens the native level editor")
	var editor = app.editor
	click(editor.brushes.white)
	click_cell(editor.board, 0)
	check(editor.model.pieces[0] == 1, "The paint brush accepts pointer input")
	click(editor.undo_button)
	check(editor.model.pieces[0] == 0, "The editor undo button restores the draft")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = editor.board.global_position + editor.board.center_of(0)
	press.pressed = true
	viewport.push_input(press, true)
	await create_timer(0.5).timeout
	var drag := InputEventMouseMotion.new()
	drag.position = editor.board.global_position + editor.board.center_of(1)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(drag, true)
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = drag.position
	viewport.push_input(press, true)
	check(editor.model.pieces[0] == 1 and editor.model.pieces[1] == 1, "Dragging paints multiple cells")
	click(editor.undo_button)
	check(editor.model.pieces.count(1) == 0, "One undo removes the full pointer stroke")
	check(editor.import_text(JSON.stringify(catalog[0])), "An existing level can be imported")
	check(editor.model.definition().optimal_moves == 0, "Campaign minimum claims are absent from custom maps")
	var imported_id: String = editor.model.id
	check(not editor.import_text("{broken") and editor.model.id == imported_id, "Failed import preserves the current draft")
	editor._save()
	check(not editor.library.list_levels().is_empty(), "Saved levels appear in the personal library")
	var saved_path: String = editor.directory.path_join("levels").path_join(editor.model.id + ".json")
	var saved_contents := FileAccess.get_file_as_string(saved_path)
	editor.model.paint(0, "black")
	editor._new_level()
	check(FileAccess.get_file_as_string(saved_path) == saved_contents, "Leaving unsaved edits preserves the saved original")
	check(editor.library.list_levels().size() >= 2, "Unsaved changes remain available as a draft copy")
	editor.import_text(JSON.stringify(catalog[0]))
	editor._playtest()
	await settle()
	check(app.screen == "editor_test" and not app.test_game.modes.visible, "Custom maps play immediately without minimum verification or mode gates")
	app.test_game.session.selected = 0
	app.test_game._try_move("right")
	await settle()
	check(app.test_game.session.cleared(), "A custom map can be completed")
	check(editor.records.best(editor.model.definition()) == 1 and app.test_game.custom_new_record, "A completed playtest adds a best known record")
	check(app.test_game.result_title.text == "New record", "Completion shows the new record")
	app.test_game._next()
	await settle()
	check(app.screen == "editor", "Completing a playtest returns to the editor")
	check(Puzzle.key(app.game.session.state) == campaign_state and FileAccess.get_file_as_string(app.progress.path) == campaign_save,
		"Editor playtests preserve the live campaign and its saved checkpoint")
	editor._show_records()
	await settle()
	check(editor.records_layer.visible and editor.records_table.get_child_count() == 1, "The local leaderboard lists the completed run")
	if DisplayServer.get_name() != "headless":
		redraw(viewport)
		await process_frame
		RenderingServer.force_draw()
		viewport.get_texture().get_image().save_png("res://builds/records-1280.png")
	editor.player_input.text = "Guest"
	editor._save_player()
	check(Records.new(editor.directory).player == "Guest", "The player name persists")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape, true)
	await settle()
	check(app.screen == "editor" and not editor.records_layer.visible, "Escape closes records without leaving the editor")
	editor._exchange(true)
	var shared: String = editor.exchange_text.text
	check(JSON.parse_string(shared).records.size() == 1, "JSON exports include the completed walk")
	check(editor.import_text(shared), "A shared map and score can be imported")
	check(editor.records.best(editor.model.definition()) == 1, "Importing under a new identity keeps matching-map records")
	var broken_share: Dictionary = JSON.parse_string(shared)
	broken_share.records.append({"player": "Cheater", "moves": 0, "actions": []})
	check(editor.import_text(JSON.stringify(broken_share)) and editor.records.entries(editor.model.definition()).size() == 1,
		"Invalid imported scores are skipped while preserving the map and valid records")
	editor._save()
	var reopened: Dictionary = editor.library.load_file(editor.directory.path_join("levels").path_join(editor.model.id + ".json"), false)
	check(reopened.model.state() == editor.model.state(), "Saved custom maps reopen without a minimum certificate")
	editor._replace(Model.parse(catalog[-1]).model)
	for dimensions in [Vector2i(960,680), Vector2i(2940,1846), Vector2i(5120,2880), Vector2i(1280,820)]:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for language in Settings.LANGUAGES:
			app.settings.language = language
			app.settings.apply_language()
			await settle()
			for control in [editor.board, editor.play_button, editor.records_button, editor.title_input, editor.status]:
				check(screen.encloses(control.get_global_rect()), "Authoring controls fit after resizing and translating")
			editor._show_records()
			await settle()
			for control in [editor.records_panel, editor.player_input, editor.records_table]:
				check(screen.encloses(control.get_global_rect()), "Leaderboard controls fit after resizing and translating")
			if DisplayServer.get_name() != "headless" and dimensions.x == 960:
				redraw(viewport)
				await process_frame
				RenderingServer.force_draw()
				viewport.get_texture().get_image().save_png("res://builds/records-960-%s.png" % language)
			editor.records_layer.hide()
		if DisplayServer.get_name() != "headless" and dimensions.x in [960, 2940]:
			redraw(viewport)
			await process_frame
			RenderingServer.force_draw()
			viewport.get_texture().get_image().save_png("res://builds/editor-%dx%d.png" % [dimensions.x,dimensions.y])
	viewport.size = Vector2i(960,680)
	editor.model.resize_grid(12,12)
	editor._edited()
	editor._playtest()
	await settle()
	var test_board = app.test_game.board
	var test_grid := Rect2(test_board.global_position + test_board.origin, Vector2(12,12) * test_board.unit)
	check(test_board.unit >= 28 and Rect2(Vector2.ZERO,Vector2(960,680)).encloses(test_grid), "A 12 by 12 custom map fits the minimum desktop window")
	check(app.test_game.custom_best == 0, "Resizing starts a separate leaderboard for the changed map")
	app.pause_game()
	app._navigate("settings")
	app._navigate("back")
	check(app.screen == "editor_test" and app.paused, "Playtest settings return to the paused custom run")
	app._navigate("editor")
	app._navigate("editor_back")
	app._navigate("back")
	check(app.screen == "game" and app.paused and Puzzle.key(app.game.session.state) == campaign_state, "Leaving the editor restores the original paused campaign")
	app.show_screen("home")
	app.home.create_button.grab_focus()
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	viewport.push_input(enter, true)
	await settle()
	check(app.screen == "editor", "Enter on the home Create shortcut opens the editor")
	app._navigate("editor_back")
	check(app.screen == "home", "The home shortcut returns directly to Home")
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("NULL editor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
