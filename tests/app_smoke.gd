extends SceneTree

const Progress = preload("res://scripts/progress.gd")
const Settings = preload("res://scripts/settings.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var app
var checks := 0
var failures := 0
var save_path := "user://app_test_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	await process_frame
	await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.get_global_rect().get_center()
		Input.parse_input_event(event)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var page: Control = app.pages[app.screen]
	if page.entrance != null and page.entrance.is_running():
		await create_timer(0.35).timeout
	if app.background.transition != null and app.background.transition.is_running():
		await create_timer(0.65).timeout
	redraw(app)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://builds/" + name_value + ".png")

func redraw(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		redraw(child)

func make_app() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.progress = Progress.new(save_path)
	app.settings = Settings.new(save_path + ".cfg")
	root.add_child(app)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	root.size = Vector2i(1280, 820)
	make_app()
	await settle()
	check(app.screen == "home" and app.home.visible and not app.game.visible, "Startup opens the home screen")
	check(app.home.continue_button.text == "Start" and app.game.easy_button.text == "Easy", "The default UI is English regardless of system language")
	await capture("home-1280")
	if DisplayServer.get_name() != "headless":
		key(KEY_F11)
		await create_timer(0.8).timeout
		await settle()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11 enters native fullscreen")
		print("Fullscreen home: %s, title %d, start %d" % [app.home.size,
			app.home.title.get_theme_font_size("font_size"), app.home.continue_button.get_theme_font_size("font_size")])
		await capture("home-fullscreen")
		key(KEY_F11)
		await create_timer(0.8).timeout
		root.size = Vector2i(1280, 820)
		await settle()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11 returns to the ordinary window")
	app.home.settings_button.grab_focus()
	await settle()
	key(KEY_ENTER)
	await settle()
	check(app.screen == "settings", "Enter activates focused settings instead of starting a level (route: %s)" % app.screen)
	app._navigate("back")
	await settle()
	app.home.continue_button.grab_focus()
	await settle()
	key(KEY_ENTER)
	await settle()
	check(app.screen == "game" and app.game.current == 0, "Enter on the minimal title screen starts the first unfinished level directly")
	app.game.session.selected = 0
	key(KEY_RIGHT)
	await create_timer(0.4).timeout
	check(app.game.session.cleared(), "The direct-start level can be completed normally")
	app.show_screen("home")
	click(app.home.continue_button)
	await settle()
	check(app.screen == "game" and app.game.current == 1, "Start advances to the next unfinished level after a clear")
	app._navigate("campaign")
	await settle()
	check(app.campaign.cards.size() == 3, "First chapter renders three original level cards")
	app.campaign.hard_button.pressed.emit()
	await settle()
	check(app.settings.hard_mode, "Campaign difficulty selector updates shared preferences")
	click(app.campaign.cards[1])
	await settle()
	check(app.screen == "game" and app.game.current == 1 and app.game.session.hard_mode, "Clicking a level card opens the correct level and difficulty")
	key(KEY_TAB)
	key(KEY_RIGHT)
	await create_timer(0.4).timeout
	check(app.game.session.steps == 1, "Gameplay accepts keyboard input after navigation")
	var saved_state := Puzzle.key(app.game.session.state)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	await settle()
	check(app.paused and app.pause_layer.visible and not app.game.input_enabled, "Escape deselects first, then pauses")
	key(KEY_Z)
	check(app.game.session.steps == 1, "Paused game cannot receive undo input")
	app._navigate("settings")
	await settle()
	app.preferences.switches.show_hints.button_pressed = false
	app.preferences.switches.reduce_motion.button_pressed = true
	await settle()
	check(not app.game.board.show_hints and app.game.board.reduce_motion, "Settings apply to the live board")
	check(not app.background.is_processing(), "Reduced motion stops orbital drift and meteors immediately")
	var frozen_clock: float = app.background.clock
	await settle()
	check(app.background.clock == frozen_clock, "The background stays still with reduced motion enabled")
	await capture("settings-1280")
	var before_language := Puzzle.key(app.game.session.state)
	var before_history: int = app.game.session.history.size()
	app.preferences.language_selector.select(1)
	app.preferences.language_selector.item_selected.emit(1)
	await settle()
	check(app.preferences.heading.text == "设置" and app.game.easy_button.text == "简单", "The language selector updates visible and hidden screens immediately")
	check(app.home.continue_button.text == "继续" and app.campaign.chapter_title.text == "相遇", "Dynamic home and chapter text also updates")
	check(app.game.session.steps == 1 and Puzzle.key(app.game.session.state) == before_language and app.game.session.history.size() == before_history,
		"Changing language preserves the board, move count, and undo history")
	check(app.game.count_label.text == "1", "Language changes preserve the displayed move counter")
	check(Settings.new(save_path + ".cfg").language == "zh_CN", "The language selector saves the preference")
	await capture("settings-zh-1280")
	app._navigate("back")
	check(app.paused and app.screen == "game", "Returning from pause settings restores the pause menu")
	key(KEY_ESCAPE)
	await settle()
	check(not app.paused and app.game.session.steps == 1, "Resume preserves the current run")
	app.show_screen("home")
	check(app.home.continue_button.text == "继续" and app.home.continue_button.tooltip_text.contains("已走 1 步"), "Continue retains run details in a tooltip instead of opening-screen text")
	root.remove_child(app)
	app.queue_free()
	await settle()
	make_app()
	await settle()
	check(app.screen == "home" and not app.progress.resume.is_empty(), "A fresh application finds the saved run")
	check(app.settings.language == "zh_CN" and app.home.continue_button.text == "继续", "Restart restores the chosen Chinese language")
	app._navigate("settings")
	app.preferences.language_selector.select(0)
	app.preferences.language_selector.item_selected.emit(0)
	await settle()
	check(app.home.continue_button.text == "Continue" and app.game.hard_button.text == "Hard", "Switching back restores English text")
	check(app.campaign.chapter_title.text == "Encounter", "Chapter names return to English")
	app._navigate("back")
	click(app.home.continue_button)
	await settle()
	check(app.screen == "game" and app.game.session.steps == 1 and Puzzle.key(app.game.session.state) == saved_state, "Continue restores the exact board after restart")
	check(app.game.session.history.size() == 1, "Continue restores undo history")
	key(KEY_Z)
	await settle()
	check(app.game.session.steps == 0 and app.progress.resume.actions.is_empty(), "Undo updates the persistent checkpoint")
	app.start_level(16, true)
	await settle()
	await capture("new-level-17")
	app.start_level(19, true)
	await settle()
	for action in app.levels[19].solution:
		app.game.session.selected = int(action.source)
		app.game._try_move(action.direction)
	check(app.game.session.cleared() and app.progress.records["20"].hard, "New original finale completes in hard mode")
	check(app.progress.resume.is_empty(), "Final completion clears the checkpoint")
	app.game.next_button.pressed.emit()
	check(app.screen == "campaign", "Final level returns to chapter selection")
	app.campaign.chapter = app.campaign.chapter_names[-1]
	app.progress.records.clear()
	app.campaign.refresh()
	await settle()
	check(app.campaign.cards.size() == 4, "New chapter renders four authored puzzles")
	await capture("campaign-1280")
	root.size = Vector2i(960, 680)
	app.show_screen("home")
	await settle()
	check(app.home.continue_button.get_global_rect().end.x <= app.size.x, "Home controls fit the logical canvas at minimum window width")
	await capture("home-960")
	app.show_screen("campaign")
	await settle()
	await capture("campaign-960")
	app.show_screen("settings")
	await settle()
	check(app.preferences.status.get_global_rect().end.y <= app.size.y, "Settings fit the logical canvas at minimum window height")
	await capture("settings-960")
	app.preferences._tab(true)
	await settle()
	check(app.preferences.controls.get_global_rect().end.y <= app.preferences.status.global_position.y,
		"Optional controls and rules fit above the status at minimum window height")
	check(app.preferences.status.get_global_rect().end.y <= app.size.y, "Optional instructions do not overflow the window")
	await capture("controls-960")
	app.preferences._tab(false)
	app.preferences.language_selector.select(1)
	app.preferences.language_selector.item_selected.emit(1)
	await settle()
	check(app.preferences.status.get_global_rect().end.y <= app.size.y, "Chinese language settings fit the minimum window height")
	await capture("settings-zh-960")
	app.preferences._tab(true)
	await settle()
	check(app.preferences.controls.get_global_rect().end.y <= app.preferences.status.global_position.y, "Chinese instructions fit after a live language switch")
	await capture("controls-zh-960")
	app.show_screen("campaign")
	await settle()
	await capture("campaign-zh-960")
	app.start_level(0, false)
	app.game.session.selected = 0
	app.game._try_move("right")
	await settle()
	check(app.game.result_title.text == "完成", "Completion text follows the chosen language")
	app.preferences.language_selector.select(0)
	app.preferences.language_selector.item_selected.emit(0)
	await settle()
	check(app.game.result_title.text == "Complete" and app.game.result_description.text == "Moves: 1", "Completed games also refresh when language changes")
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".cfg")
	print("NULL application: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
