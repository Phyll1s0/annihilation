extends SceneTree
## Real touch events, duplicate emulated mouse events, and live phone-size resizes.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const SIZES := [Vector2i(390, 664), Vector2i(844, 300), Vector2i(844, 390),
	Vector2i(375, 667), Vector2i(320, 568), Vector2i(1280, 820)]
var viewport: SubViewport
var app
var checks := 0
var failures := 0
var directory := "user://mobile_ui_%d" % OS.get_process_id()
var geometry := {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 8: await process_frame

func mouse(point: Vector2, emulated := false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
		event.position = point
		event.pressed = pressed
		viewport.push_input(event, true)

func touch(point: Vector2, finger := 0) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = finger
		event.position = point
		event.pressed = pressed
		viewport.push_input(event, true)

func point(index: int) -> Vector2:
	return app.game.board.global_position + app.game.board.center_of(index)

func coords(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name_value in folder.get_files(): DirAccess.remove_absolute(path.path_join(name_value))
	for name_value in folder.get_directories(): remove_tree(path.path_join(name_value))
	DirAccess.remove_absolute(path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.reduce_motion = true
	app.settings.music_enabled = false
	app.settings.developer_mode = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	viewport.add_child(app)
	await settle()
	for dimensions in SIZES:
		viewport.size = dimensions
		app.show_screen("home")
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		var tag := "%dx%d" % [dimensions.x, dimensions.y]
		var controls := {"start": coords(app.home.continue_button.get_global_rect().get_center())}
		check(screen.encloses(app.home.continue_button.get_global_rect()), tag + ": Start fits")
		check(app.home.continue_button.size.y >= 44, tag + ": Start has a comfortable touch target")
		app._navigate("campaign")
		app.campaign.chapter = app.campaign.chapter_names[0]
		app.campaign.refresh()
		await settle()
		for button in app.campaign.cards + [app.campaign.previous_button, app.campaign.following_button]:
			check(screen.encloses(button.get_global_rect()), tag + ": campaign controls fit")
		controls.level = coords(app.campaign.cards[0].get_global_rect().get_center())
		check(not app.campaign.tabs.get_global_rect().intersects(app.campaign.cards[0].get_global_rect()), tag + ": campaign tabs clear cards")
		if dimensions.x >= 600 and dimensions.y < 600:
			for card in app.campaign.cards:
				check(app.campaign.scroll.get_global_rect().encloses(card.get_global_rect()), tag + ": landscape cards are not clipped by scrolling")
		for chapter in app.campaign.chapter_names:
			app.campaign.chapter = chapter
			app.campaign.refresh()
			await settle()
			check(app.campaign.body.size.x <= dimensions.x, tag + ": chapter %s fits horizontally" % chapter)
		for index in app.levels.size():
			app.start_level(index, false)
			await settle()
			var board = app.game.board
			var grid := Rect2(board.global_position + board.origin, Vector2(board.state.width, board.state.height) * board.unit)
			check(screen.encloses(grid), tag + ": level %d fits" % index)
			check(grid.position.y >= app.game.toolbar.get_global_rect().end.y + 4, tag + ": level %d clears toolbar" % index)
			check(not app.game.modes.get_global_rect().intersects(app.game.toolbar.get_global_rect()), tag + ": HUD controls do not overlap")
		app.start_level(0, false)
		await settle()
		controls.source = coords(point(0))
		controls.target = coords(point(1))
		controls.cell_size = app.game.board.unit
		controls.pause = coords(app.game.pause_button.get_global_rect().get_center())
		touch(point(0))
		check(app.game.session.selected == 0, tag + ": a touch selects a particle")
		mouse(point(0), true)
		check(app.game.session.selected == 0, tag + ": emulated mouse does not cancel a touch")
		touch(point(1))
		mouse(point(1), true)
		check(app.game.session.cleared() and app.game.session.steps == 1, tag + ": taps complete a level exactly once")
		app.start_level(1, false)
		await settle()
		app.settings.keyboard_only_movement = true
		touch(point(0))
		touch(point(1))
		check(app.game.session.steps == 1, tag + ": keyboard-only mouse preference does not disable touch movement")
		var saved := Puzzle.key(app.game.session.state)
		viewport.size = Vector2i(dimensions.y, dimensions.x)
		await settle()
		check(Puzzle.key(app.game.session.state) == saved and app.game.session.steps == 1, tag + ": rotation preserves the run")
		viewport.size = dimensions
		await settle()
		touch(app.game.board.global_position + Vector2.ONE)
		check(app.game.session.selected == -1, tag + ": tapping blank space deselects")
		var primary := InputEventScreenTouch.new()
		primary.index = 41
		primary.position = point(1)
		primary.pressed = true
		viewport.push_input(primary, true)
		touch(point(3), 42)
		primary.pressed = false
		viewport.push_input(primary, true)
		check(app.game.session.selected == 1, tag + ": a nonzero primary touch works while secondary fingers are ignored")
		app.settings.keyboard_only_movement = false
		app.pause_game()
		await settle()
		controls.pause_settings = coords(app.pause_actions.settings.get_global_rect().get_center())
		check(screen.encloses(app.pause_panel.get_global_rect()), tag + ": pause menu fits")
		app._navigate("settings")
		await settle()
		controls.settings_back = coords(app.preferences.back_button.get_global_rect().get_center())
		controls.settings_tabs = coords(app.preferences.mobile_tabs.get_global_rect().get_center())
		for language in Settings.LANGUAGES:
			app.settings.language = language
			app.settings.apply_language()
			for tab in 4:
				app.preferences._mobile_tab_selected(tab)
				await settle()
				check(screen.encloses(app.preferences.frame.get_global_rect()), tag + ": settings frame fits (%s / %d / %s)" % [language, tab, app.preferences.frame.get_global_rect()])
				check(app.preferences.inside.size.x <= dimensions.x, tag + ": settings do not overflow horizontally")
		app.settings.language = "en"
		app.settings.apply_language()
		app.preferences._tab(false)
		await settle()
		controls.hints = coords(app.preferences.switches.show_hints.get_global_rect().get_center())
		app._navigate("create_level")
		app.editor.tools_open = false
		app.editor._layout_editor()
		await settle()
		check(screen.encloses(app.editor.frame.get_global_rect()), tag + ": editor fits")
		check(screen.encloses(app.editor.board.get_global_rect()), tag + ": editor board fits")
		var editor_point = app.editor.board.global_position + app.editor.board.center_of(0)
		app.editor._brush("white")
		touch(editor_point)
		mouse(editor_point, true)
		check(app.editor.model.pieces[0] == 1, tag + ": one tap paints one particle")
		app.editor.tools_open = true
		app.editor._layout_editor()
		await settle()
		check(screen.encloses(app.editor.sidebar_shell.get_global_rect()), tag + ": editor tools fit")
		app.editor._save()
		app._navigate("my_levels")
		await settle()
		for row in app.my_levels.rows:
			for button in [row.play, row.scores, row.edit]:
				var rect: Rect2 = button.get_global_rect()
				check(rect.position.x >= 0 and rect.end.x <= dimensions.x, tag + ": saved level actions fit horizontally")
		check(screen.encloses(app.my_levels.frame.get_global_rect()), tag + ": level library fits")
		geometry[tag] = controls
	# Simulate the usable area left by a landscape phone's notch and home indicator.
	viewport.size = Vector2i(750, 279)
	app.start_level(0, false)
	await settle()
	geometry["750x279"] = {"source": coords(point(0)), "target": coords(point(1))}
	if "--geometry" in OS.get_cmdline_user_args():
		var output := FileAccess.open("res://builds/mobile-controls.json", FileAccess.WRITE)
		output.store_string(JSON.stringify(geometry, "\t"))
		output.close()
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION mobile UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
