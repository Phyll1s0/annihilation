extends SceneTree
const Model = preload("res://scripts/editor_model.gd")
const Library = preload("res://scripts/editor_library.gd")
const Solver = preload("res://scripts/editor_solver.gd")
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

func solve_async(state: Dictionary, limit: int = 100000, background: bool = true) -> Dictionary:
	var job := Solver.new()
	check(job.start(state, limit, 10000, background) == OK, "The authoring solver starts")
	for i in 2000:
		var result := job.poll()
		if not result.is_empty(): return result
		await process_frame
	job.shutdown()
	check(false, "The authoring solver finishes within its deadline")
	return {}

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
	for index in [0, 2, 7]:
		var result := await solve_async(Puzzle.from_level(catalog[index]))
		check(result.get("status") == "solved" and result.get("moves") == catalog[index].optimal_moves, "Packed solver agrees with certified campaign minimum")
	var impossible := Puzzle.from_level({"layout": ["w#b"]})
	check((await solve_async(impossible)).get("status") == "unsolvable", "An impossible draft is distinguished from a search limit")
	check((await solve_async(Puzzle.from_level(catalog[1]), 1)).get("status") == "limit", "A limited search never certifies a minimum")
	check((await solve_async(Puzzle.from_level(catalog[1]), 100000, false)).get("moves") == 3, "Frame-batched Web searches produce the same minimum")
	var cancelled := Solver.new()
	cancelled.start(Puzzle.from_level(catalog[-1]))
	cancelled.cancel()
	cancelled.shutdown()
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
	check(editor.model.certificate.is_empty(), "An imported certificate is not trusted")
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
	check(app.screen == "editor_test" and app.test_game.hard_button.disabled, "Unverified maps can be played in Easy while Hard remains unavailable")
	app.test_game.session.selected = 0
	app.test_game._try_move("right")
	await settle()
	check(app.test_game.session.cleared(), "A custom map can be completed")
	app.test_game._next()
	await settle()
	check(app.screen == "editor", "Completing a playtest returns to the editor")
	check(Puzzle.key(app.game.session.state) == campaign_state and FileAccess.get_file_as_string(app.progress.path) == campaign_save,
		"Editor playtests preserve the live campaign and its saved checkpoint")
	editor._verify()
	for i in 1000:
		await process_frame
		if editor.job == null: break
	check(not editor.model.certificate.is_empty() and Catalog.validate(editor.model.definition()).is_empty(), "Verification supplies a replayable minimum certificate")
	editor._save()
	var reopened: Dictionary = editor.library.load_file(editor.directory.path_join("levels").path_join(editor.model.id + ".json"), true, false)
	check(reopened.model.certificate.optimal_moves == 1, "Locally verified minima persist across reopening")
	var certified: Dictionary = editor.model.document()
	check(Model.parse(certified).model.certificate.is_empty(), "Exported minimum claims are checked again on import")
	editor._playtest()
	await settle()
	check(not app.test_game.hard_button.disabled, "Verified maps enable Hard playtesting")
	app.test_game._change_mode(true)
	app.test_game.session.selected = 0
	app.test_game._try_move("right")
	check(app.test_game.session.cleared(), "A custom map completes in verified Hard mode")
	app.test_game._next()
	await settle()
	editor._verify()
	editor._replace(Model.new())
	for i in 1000:
		await process_frame
		if editor.job == null: break
	check(editor.model.certificate.is_empty(), "A stale search cannot certify a replacement document")
	editor._replace(Model.parse(catalog[-1], true, true).model)
	for dimensions in [Vector2i(960,680), Vector2i(2940,1846), Vector2i(5120,2880), Vector2i(1280,820)]:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for language in Settings.LANGUAGES:
			app.settings.language = language
			app.settings.apply_language()
			await settle()
			for control in [editor.board, editor.play_button, editor.verify_button, editor.title_input, editor.status]:
				check(screen.encloses(control.get_global_rect()), "Authoring controls fit after resizing and translating")
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
	check(not app.test_game.hard_available, "Resizing invalidates a previous minimum certificate")
	app.pause_game()
	app._navigate("settings")
	app._navigate("back")
	check(app.screen == "editor_test" and app.paused, "Playtest settings return to the paused custom run")
	app._navigate("editor")
	app._navigate("editor_back")
	app._navigate("back")
	check(app.screen == "game" and app.paused and Puzzle.key(app.game.session.state) == campaign_state, "Leaving the editor restores the original paused campaign")
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("NULL editor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
