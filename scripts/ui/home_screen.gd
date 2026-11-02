extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
const Mark = preload("res://scripts/ui/merge_mark.gd")
var levels: Array = []
var progress
var settings
var continue_button: Button
var settings_button: Button
var mark

func _ready() -> void:
	_setup_theme()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 220
	body.add_theme_constant_override("separation", 18)
	center.add_child(body)
	mark = Mark.new()
	mark.custom_minimum_size = Vector2(96, 42)
	body.add_child(mark)
	var title := _label("gray", 52, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var button_center := CenterContainer.new()
	body.add_child(button_center)
	continue_button = _button("开始", _play, Vector2(112, 42))
	continue_button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed"]:
		continue_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	continue_button.add_theme_color_override("font_color", MUTED)
	continue_button.add_theme_color_override("font_hover_color", INK)
	continue_button.add_theme_color_override("font_pressed_color", INK)
	continue_button.mouse_entered.connect(func(): mark.respond(true, settings.reduce_motion))
	continue_button.mouse_exited.connect(func(): mark.respond(false, settings.reduce_motion))
	continue_button.focus_entered.connect(func(): mark.respond(true, settings.reduce_motion))
	continue_button.focus_exited.connect(func(): mark.respond(false, settings.reduce_motion))
	button_center.add_child(continue_button)
	settings_button = _icon_button("settings-outline", "设置", func(): navigation_requested.emit("settings"), 21, 44)
	settings_button.add_theme_color_override("icon_normal_color", Color("68717b"))
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	settings_button.offset_left = -68
	settings_button.offset_right = -24
	settings_button.offset_top = -68
	settings_button.offset_bottom = -24
	add_child(settings_button)
	refresh()

func _play() -> void:
	navigation_requested.emit("continue")

func refresh() -> void:
	if continue_button == null:
		return
	var saved: Dictionary = progress.resume
	continue_button.text = "开始" if saved.is_empty() else "继续"
	continue_button.tooltip_text = "进入下一关 · Enter" if saved.is_empty() else "关卡 %s · %s · 已走 %d 步" % [
		saved.level_id, "困难" if saved.hard_mode else "简单", saved.actions.size()]
	mark.respond(false, true)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if get_viewport().gui_get_focus_owner() == settings_button:
			navigation_requested.emit("settings")
		else:
			_play()
		get_viewport().set_input_as_handled()
