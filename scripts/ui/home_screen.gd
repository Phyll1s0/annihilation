extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
const Mark = preload("res://scripts/ui/zero_mark.gd")
var levels: Array = []
var progress
var settings
var continue_button: Button
var settings_button: Button
var mark
var body: VBoxContainer
var title: Label
var title_font: FontVariation

func _ready() -> void:
	_setup_theme()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	body = VBoxContainer.new()
	center.add_child(body)
	mark = Mark.new()
	body.add_child(mark)
	title = _title("NULL", 88, 5)
	title_font = title.get_theme_font("font")
	title_font.base_font = preload("res://assets/fonts/Poppins-Thin.ttf")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var button_center := CenterContainer.new()
	body.add_child(button_center)
	continue_button = _button("Start", _play, Vector2(176, 58))
	for state in ["normal", "hover", "pressed"]:
		continue_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	continue_button.add_theme_color_override("font_color", Color("acb6c0"))
	continue_button.add_theme_color_override("font_hover_color", INK)
	continue_button.add_theme_color_override("font_pressed_color", INK)
	continue_button.mouse_entered.connect(func(): mark.respond(true, settings.reduce_motion))
	continue_button.mouse_exited.connect(func(): mark.respond(false, settings.reduce_motion))
	continue_button.focus_entered.connect(func(): mark.respond(true, settings.reduce_motion))
	continue_button.focus_exited.connect(func(): mark.respond(false, settings.reduce_motion))
	button_center.add_child(continue_button)
	settings_button = _icon_button("settings-outline", "Settings", func(): navigation_requested.emit("settings"), 21, 44)
	settings_button.add_theme_color_override("icon_normal_color", Color("68717b"))
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	settings_button.offset_left = -68
	settings_button.offset_right = -24
	settings_button.offset_top = -68
	settings_button.offset_bottom = -24
	add_child(settings_button)
	resized.connect(_layout_home)
	_layout_home()
	refresh()

func _layout_home() -> void:
	if continue_button == null:
		return
	# Grow with the window's shorter scale, without shrinking ordinary windows.
	var factor := maxf(1.0, minf(size.x / 1280.0, size.y / 820.0))
	var fit := minf((size.x - 40.0) / 320.0, (size.y - 48.0) / 310.0)
	factor = maxf(0.5, minf(factor, fit))
	body.custom_minimum_size.x = 320.0 * factor
	body.add_theme_constant_override("separation", roundi(24.0 * factor))
	title.add_theme_font_size_override("font_size", roundi(88.0 * factor))
	title_font.spacing_glyph = roundi(5.0 * factor)
	mark.custom_minimum_size = Vector2(96, 90) * factor
	mark.visual_scale = factor
	continue_button.add_theme_font_size_override("font_size", roundi(22.0 * factor))
	continue_button.custom_minimum_size = Vector2(176, 58) * factor
	var edge := 24.0 * factor
	var hit := 52.0 * factor
	settings_button.custom_minimum_size = Vector2.ONE * hit
	settings_button.add_theme_constant_override("icon_max_width", roundi(24.0 * factor))
	settings_button.offset_left = -edge - hit
	settings_button.offset_right = -edge
	settings_button.offset_top = -edge - hit
	settings_button.offset_bottom = -edge

func _play() -> void:
	navigation_requested.emit("campaign")

func refresh() -> void:
	if continue_button == null:
		return
	continue_button.text = tr("Start")
	continue_button.tooltip_text = tr("Choose a level · Enter")
	mark.respond(false, settings.reduce_motion)

func _refresh_language() -> void:
	refresh()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if get_viewport().gui_get_focus_owner() == settings_button:
			navigation_requested.emit("settings")
		else:
			_play()
		get_viewport().set_input_as_handled()
