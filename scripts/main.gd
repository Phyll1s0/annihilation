extends "res://scripts/ui/screen_base.gd"
## Application shell: navigation and shared services; puzzle input stays in GameScreen.
const Catalog = preload("res://scripts/catalog.gd")
const Progress = preload("res://scripts/progress.gd")
const Settings = preload("res://scripts/settings.gd")
const Home = preload("res://scenes/home_screen.tscn")
const Campaign = preload("res://scenes/campaign_screen.tscn")
const Preferences = preload("res://scenes/settings_screen.tscn")
const Background = preload("res://scripts/ui/void_background.gd")
var progress = Progress.new()
var settings = Settings.new()
var levels: Array = []
var game
var home
var campaign
var preferences
var background
var music
var pages: Dictionary = {}
var screen := "home"
var settings_return := "home"
var settings_return_paused := false
var pause_layer: Control
var paused := false
var pause_panel: PanelContainer
var pause_center: CenterContainer
var pause_actions: Dictionary = {}
var editor
var test_game
var my_levels
var custom_library
var custom_records
var editor_directory := ""
var editor_return := "home"
var editor_origin_screen := "home"
var editor_origin_paused := false
var developer_access := false

func _ready() -> void:
	settings.apply_language()
	developer_access = settings.developer_mode
	_setup_theme()
	background = Background.new()
	background.settings = settings
	add_child(background)
	var catalog := Catalog.load_campaign()
	if not catalog.errors.is_empty():
		var error := _label(tr("Unable to load levels.") + "\n\n" + "\n".join(catalog.errors), 20)
		add_child(error)
		return
	levels = catalog.levels
	progress.bind_catalog(levels)
	music = preload("res://scripts/music.gd").new()
	music.settings = settings
	add_child(music)
	home = Home.instantiate()
	home.levels = levels
	home.progress = progress
	home.settings = settings
	campaign = Campaign.instantiate()
	campaign.levels = levels
	campaign.progress = progress
	campaign.settings = settings
	preferences = Preferences.instantiate()
	preferences.settings = settings
	game = preload("res://scenes/game_screen.tscn").instantiate()
	game.levels = levels
	game.progress = progress
	game.settings = settings
	pages = {"home": home, "campaign": campaign, "settings": preferences, "game": game}
	for page in pages.values():
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.navigation_requested.connect(_navigate)
		add_child(page)
	campaign.level_requested.connect(start_level)
	preferences.settings_changed.connect(func():
		game.apply_settings()
		if test_game != null: test_game.apply_settings()
		background.apply_settings()
		music.apply_settings()
		_refresh_access())
	game.pause_requested.connect(pause_game)
	game.state_changed.connect(func(): home.refresh())
	_build_pause()
	resized.connect(_layout_pause)
	_layout_pause()
	if not progress.resume.is_empty() and not game.restore_checkpoint():
		progress.resume = {}
		progress.save()
	settings.apply_window()
	show_screen("home")
	if "--create" in OS.get_cmdline_user_args(): _navigate("editor")

func _navigate(destination: String) -> void:
	if music != null: music.unlock()
	match destination:
		"continue":
			if not progress.resume.is_empty() and progress.level_unlocked(levels, game.current, settings.developer_mode):
				game.show_level_intro()
				show_screen("game")
			else:
				show_screen("campaign")
		"my_levels":
			_ensure_library()
			show_screen("my_levels")
		"settings":
			settings_return = screen
			settings_return_paused = paused
			show_screen("settings")
		"back":
			show_screen(settings_return)
			if settings_return_paused:
				pause_game()
		"editor":
			if not settings.developer_mode: return
			if screen in ["home", "my_levels"]:
				editor_return = screen
			elif screen == "settings" and settings_return not in ["editor", "editor_test"]:
				editor_return = "settings"
				editor_origin_screen = settings_return
				editor_origin_paused = settings_return_paused
			_ensure_editor()
			show_screen("editor")
		"editor_back":
			settings_return = editor_origin_screen
			settings_return_paused = editor_origin_paused
			show_screen(editor_return)
			if editor_return == "settings": preferences._developer_tab()
		_: show_screen(destination)

func show_screen(destination: String) -> void:
	if destination == "editor" and not settings.developer_mode: return
	if destination == "game" and not progress.level_unlocked(levels, game.current, settings.developer_mode): destination = "campaign"
	if not pages.has(destination):
		return
	screen = destination
	music.set_page(destination)
	background.set_page("game" if destination == "editor_test" else destination)
	paused = false
	pause_layer.hide()
	for key in pages:
		pages[key].visible = key == destination
	game.input_enabled = destination == "game"
	if test_game != null: test_game.input_enabled = destination == "editor_test"
	match destination:
		"home": home.refresh()
		"campaign": campaign.refresh()
		"settings": preferences.refresh()
		"game": game.apply_settings()
		"editor_test": test_game.apply_settings()
		"editor": editor.refresh()
		"my_levels": my_levels.refresh()
	pages[destination].enter(settings.reduce_motion)

func start_level(index: int, hard: bool) -> bool:
	if not progress.level_unlocked(levels, index, settings.developer_mode): return false
	settings.hard_mode = hard
	settings.save()
	game.session.hard_mode = hard
	game._open_level(index)
	show_screen("game")
	return true

func _refresh_access() -> void:
	if developer_access != settings.developer_mode:
		developer_access = settings.developer_mode
		campaign.refresh()
		if my_levels != null: my_levels.refresh()
	if settings.developer_mode: return
	if screen == "settings":
		if settings_return == "game" and not progress.level_unlocked(levels, game.current):
			settings_return = "campaign"
			settings_return_paused = false
		elif settings_return == "editor" or (settings_return == "editor_test" and test_game.custom_return == "editor"):
			if editor != null: editor._persist()
			_ensure_library()
			settings_return = "my_levels"
			settings_return_paused = false
	elif screen == "game" and not progress.level_unlocked(levels, game.current):
		show_screen("campaign")
	elif screen == "editor" or (screen == "editor_test" and test_game.custom_return == "editor"):
		if editor != null: editor._persist()
		_navigate("my_levels")

func _ensure_custom_content() -> void:
	if custom_library != null: return
	if editor_directory.is_empty():
		editor_directory = "user://editor" if settings.path == "user://settings.cfg" else settings.path + ".editor"
	custom_library = preload("res://scripts/editor_library.gd").new(editor_directory)
	custom_records = preload("res://scripts/custom_records.gd").new(editor_directory)

func _ensure_library() -> void:
	if my_levels != null: return
	_ensure_custom_content()
	my_levels = preload("res://scripts/ui/library_screen.gd").new()
	my_levels.library = custom_library
	my_levels.records = custom_records
	my_levels.settings = settings
	my_levels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	my_levels.navigation_requested.connect(_navigate)
	my_levels.level_requested.connect(func(level: Dictionary): _start_custom(level, "my_levels"))
	my_levels.edit_requested.connect(func(path: String):
		if not settings.developer_mode: return
		_navigate("editor")
		editor.open_saved(path))
	pages.my_levels = my_levels
	add_child(my_levels)
	move_child(pause_layer, get_child_count() - 1)

func _ensure_editor() -> void:
	if editor != null: return
	_ensure_custom_content()
	editor = preload("res://scripts/ui/editor_screen.gd").new()
	editor.directory = editor_directory
	editor.levels = levels
	editor.library = custom_library
	editor.records = custom_records
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.navigation_requested.connect(_navigate)
	editor.playtest_requested.connect(_start_test)
	pages.editor = editor
	add_child(editor)
	move_child(pause_layer, get_child_count() - 1)

func _start_test(definition: Dictionary) -> void:
	_start_custom(definition, "editor")

func _start_custom(definition: Dictionary, origin: String) -> void:
	if origin == "editor" and not settings.developer_mode: return
	_ensure_custom_content()
	if test_game == null:
		test_game = preload("res://scenes/game_screen.tscn").instantiate()
		test_game.custom_run = true
		test_game.levels = [definition]
		test_game.progress = Progress.new(editor_directory.path_join("playtest.json"))
		test_game.settings = settings
		test_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		test_game.navigation_requested.connect(_navigate)
		test_game.pause_requested.connect(pause_game)
		test_game.custom_completed.connect(func(level: Dictionary, actions: Array):
			var outcome: Dictionary = custom_records.submit(level, test_game.custom_player, actions)
			test_game.custom_best = custom_records.best(level)
			test_game.custom_new_record = outcome.get("improved", false)
			if not outcome.get("saved", false): test_game.save_error = true)
		pages.editor_test = test_game
		add_child(test_game)
		move_child(pause_layer, get_child_count() - 1)
	test_game.levels = [definition]
	test_game.progress.bind_catalog(test_game.levels)
	test_game.custom_return = origin
	test_game.custom_best = custom_records.best(definition)
	test_game.custom_player = custom_records.player
	test_game.custom_new_record = false
	test_game.session.hard_mode = false
	test_game._open_level(0)
	show_screen("editor_test")

func _active_game():
	return test_game if screen == "editor_test" else game

func _build_pause() -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_layer)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.64)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(scrim)
	var center := CenterContainer.new()
	pause_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(center)
	var panel := PanelContainer.new()
	pause_panel = panel
	panel.custom_minimum_size.x = 360
	panel.add_theme_stylebox_override("panel", _style(Color("080808"), LINE, 4))
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := _title("Paused", 26, 1)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var entries := [
		["resume", "Resume", resume_game],
		["restart", "Restart level", func(): resume_game(); _active_game()._restart()],
		["settings", "Settings", func(): _navigate("settings")],
		["levels", "Back to levels", func(): _navigate(test_game._return_page()) if screen == "editor_test" else show_screen("campaign")],
		["home", "Home", func(): show_screen("home")],
	]
	for entry in entries:
		var button := _button(entry[1], entry[2], Vector2(0, 48))
		button.add_theme_font_size_override("font_size", 18)
		box.add_child(button)
		pause_actions[entry[0]] = button
	_remember_layout(pause_panel)
	pause_center.minimum_size_changed.connect(_fit_pause_center)
	pause_layer.hide()

func _layout_pause() -> void:
	if pause_panel == null:
		return
	var factor := _screen_scale()
	_apply_layout(pause_panel, factor)
	var plate := _style(Color("080808"), LINE, roundi(4 * factor))
	plate.content_margin_left *= factor
	plate.content_margin_right *= factor
	plate.content_margin_top *= factor
	plate.content_margin_bottom *= factor
	pause_panel.add_theme_stylebox_override("panel", plate)
	_fit_pause_center()

func _fit_pause_center() -> void:
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func pause_game() -> void:
	if screen not in ["game", "editor_test"]:
		return
	paused = true
	var active = _active_game()
	active._cancel_level_intro()
	active.input_enabled = false
	active.board.cancel_animation()
	active._sync()
	var return_message := "Back to levels"
	if screen == "editor_test": return_message = "Back to editor" if test_game.custom_return == "editor" else "Back to my levels"
	pause_actions.levels.set_meta("message", return_message)
	pause_actions.levels.text = tr(return_message)
	pause_layer.show()
	pause_actions.resume.grab_focus()

func resume_game() -> void:
	paused = false
	pause_layer.hide()
	_active_game().input_enabled = true

func _input(event: InputEvent) -> void:
	if pages.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F11:
		settings.fullscreen = not settings.fullscreen
		settings.save()
		settings.apply_window()
		preferences.refresh()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE:
		if paused:
			resume_game()
		elif screen == "settings":
			_navigate("back")
		elif screen == "campaign":
			show_screen("home")
		elif screen == "editor" and not editor.exchange_layer.visible and not editor.records_layer.visible:
			editor._persist()
			_navigate("editor_back")
		else:
			return
		get_viewport().set_input_as_handled()
