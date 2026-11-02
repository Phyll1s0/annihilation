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
var pages: Dictionary = {}
var screen := "home"
var settings_return := "home"
var settings_return_paused := false
var pause_layer: Control
var paused := false
var pause_panel: PanelContainer
var pause_center: CenterContainer
var pause_actions: Dictionary = {}

func _ready() -> void:
	settings.apply_language()
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
		background.apply_settings())
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

func _navigate(destination: String) -> void:
	match destination:
		"continue":
			if not progress.resume.is_empty():
				show_screen("game")
			else:
				start_level(Catalog.recommended(levels, progress.records, settings.hard_mode), settings.hard_mode)
		"settings":
			settings_return = screen
			settings_return_paused = paused
			show_screen("settings")
		"back":
			show_screen(settings_return)
			if settings_return_paused:
				pause_game()
		_: show_screen(destination)

func show_screen(destination: String) -> void:
	if not pages.has(destination):
		return
	screen = destination
	background.set_page(destination)
	paused = false
	pause_layer.hide()
	for key in pages:
		pages[key].visible = key == destination
	game.input_enabled = destination == "game"
	match destination:
		"home": home.refresh()
		"campaign": campaign.refresh()
		"settings": preferences.refresh()
		"game": game.apply_settings()
	pages[destination].enter(settings.reduce_motion)

func start_level(index: int, hard: bool) -> void:
	settings.hard_mode = hard
	settings.save()
	game.session.hard_mode = hard
	game._open_level(index)
	show_screen("game")

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
		["restart", "Restart level", func(): resume_game(); game._restart()],
		["settings", "Settings", func(): _navigate("settings")],
		["levels", "Back to levels", func(): show_screen("campaign")],
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
	if screen != "game":
		return
	paused = true
	game.input_enabled = false
	game.board.cancel_animation()
	game._sync()
	pause_layer.show()
	pause_actions.resume.grab_focus()

func resume_game() -> void:
	paused = false
	pause_layer.hide()
	game.input_enabled = true

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
		else:
			return
		get_viewport().set_input_as_handled()
