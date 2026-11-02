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
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://builds/" + name_value + ".png")

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
	await capture("home-1280")
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
	app.campaign.chapter = "往复"
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
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".cfg")
	print("NULL application: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
