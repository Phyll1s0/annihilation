extends SceneTree
## Check entry routes, animation completion, input blocking, and cancellation.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var viewport: SubViewport
var app
var checks := 0
var failures := 0
var directory := "user://level_intro_test_%d" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle(seconds: float = 0.0) -> void:
	if seconds > 0: await create_timer(seconds).timeout
	for i in 3: await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)

func click_cell(index: int) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = app.game.board.global_position + app.game.board.center_of(index)
		event.pressed = pressed
		viewport.push_input(event, true)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png("res://builds/level-intro-" + name_value + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.music_enabled = false
	app.settings.developer_mode = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	app.editor_directory = directory.path_join("editor")
	viewport.add_child(app)
	await settle()
	var intro = app.game.level_intro
	check(not intro.visible and not app.game.intro_pending, "Startup does not play a hidden level introduction")
	app.start_level(4, false)
	check(intro.visible and intro.number.text == "05" and intro.title.text == "Passing By", "Selecting a level presents its number and title")
	check(app.game.modulate.a == 1.0 and intro.modulate.a == 1.0, "The title starts legibly without a competing page fade")
	var state := Puzzle.key(app.game.session.state)
	click_cell(0)
	key(KEY_TAB)
	key(KEY_RIGHT)
	check(app.game.session.selected == -1 and app.game.session.steps == 0 and Puzzle.key(app.game.session.state) == state, "Input cannot move particles behind the title")
	await capture("title")
	await settle(0.25)
	check(intro.visible and intro.modulate.a > 0.0 and intro.modulate.a < 1.0, "The title and black cover fade together")
	await capture("fading")
	await settle(0.55)
	check(not intro.visible and app.game.input_enabled, "The introduction finishes within one second and releases the board")
	await capture("board")
	var action: Dictionary = app.levels[4].solution[0]
	click_cell(int(action.source))
	check(app.game.session.selected == int(action.source), "Pointer input reaches the board after the overlay is removed")
	app.game._try_move(action.direction)
	check(app.game.session.steps == 1, "The first move counts normally after the title")
	app.show_screen("campaign")
	app._navigate("continue")
	check(intro.visible and app.game.session.steps == 1, "Continue introduces the saved level without resetting its run")
	key(KEY_ESCAPE)
	check(not intro.visible and app.paused, "Escape during the introduction opens a usable pause menu")
	app.resume_game()
	check(not intro.visible and app.game.input_enabled, "Resuming does not replay the title")
	app.start_level(1, false)
	app.start_level(2, false)
	await settle(0.2)
	check(intro.visible and intro.title.text == app.levels[2].title, "Rapid level changes replace the previous title")
	app.show_screen("campaign")
	await settle(0.65)
	check(not intro.visible and not app.game.input_enabled and not app.game.intro_pending, "Leaving mid-fade cancels it without enabling a hidden board later")
	app.start_level(0, false)
	app.game._next()
	check(intro.visible and intro.number.text == "02", "Next level starts its own title card")
	app.game._restart()
	check(not intro.visible and app.game.session.steps == 0, "Restart clears an active introduction without replaying it")
	app.game.show_level_intro()
	app.settings.reduce_motion = true
	app.game.apply_settings()
	check(not intro.visible, "Enabling reduced motion cancels a running introduction immediately")
	app.start_level(3, false)
	check(not intro.visible and not app.game.intro_pending, "Reduced motion opens levels directly")
	app.settings.reduce_motion = false
	app.settings.language = "zh_CN"
	app.settings.apply_language()
	app.start_level(0, false)
	check(intro.visible and intro.title.text == tr(app.levels[0].title), "Campaign titles use the selected language")
	var custom: Dictionary = app.levels[0].duplicate(true)
	custom.title = "First Contact · 自制关卡"
	app._start_test(custom)
	check(app.test_game.level_intro.visible and app.test_game.level_intro.title.text == custom.title, "Custom playtests preserve the creator's literal title")
	check(app.test_game.level_intro.number.text == tr("Playtest"), "Custom titles have a translated playtest caption")
	custom.title = "A long custom level title with many portals and one-way fields"
	app._start_custom(custom, "my_levels")
	for dimensions in [Vector2i(960, 680), Vector2i(390, 844), Vector2i(3840, 2160)]:
		viewport.size = dimensions
		app.test_game.show_level_intro()
		await settle()
		var card = app.test_game.level_intro
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(screen.encloses(card.body.get_global_rect()) and screen.encloses(card.title.get_global_rect()), "Long titles fit %s" % dimensions)
	app.settings.language = "en"
	app.settings.apply_language()
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION level intro: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name_value in folder.get_files(): DirAccess.remove_absolute(path.path_join(name_value))
	for name_value in folder.get_directories(): remove_tree(path.path_join(name_value))
	DirAccess.remove_absolute(path)
