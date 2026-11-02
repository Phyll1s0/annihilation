extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal settings_changed
var settings
var switches: Dictionary = {}
var status: Label
var heading: Label
var general: VBoxContainer
var controls: VBoxContainer
var general_button: Button
var controls_button: Button

func _ready() -> void:
	_setup_theme()
	_back_button(func(): navigation_requested.emit("back"))
	var margin := _margin(self, 82)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 128)
	margin.add_theme_constant_override("margin_right", 128)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 160
	layout.add_child(navigation)
	var gap := Control.new()
	gap.custom_minimum_size.y = 150
	navigation.add_child(gap)
	general_button = _button("常规", func(): _tab(false), Vector2(160, 48))
	controls_button = _button("操作", func(): _tab(true), Vector2(160, 48))
	navigation.add_child(general_button)
	navigation.add_child(controls_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	navigation.add_child(_button("返回", func(): navigation_requested.emit("back"), Vector2(160, 48)))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.06), Color(1, 1, 1, 0.40), 3))
	layout.add_child(panel)
	var inside := _margin(panel, 22)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 30)
	inside.add_child(page)
	heading = _title("设置", 28, 1)
	page.add_child(heading)
	general = VBoxContainer.new()
	general.add_theme_constant_override("separation", 26)
	page.add_child(general)
	for entry in [["show_hints", "显示可走邻格", "选中棋子时，显示可以进入的相邻格。"],
		["reduce_motion", "减少动态效果", "关闭界面过渡，并立即显示行动结果。"],
		["fullscreen", "全屏显示", "F11 可以随时切换全屏。"]]:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		general.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 6)
		row.add_child(copy)
		copy.add_child(_label(entry[1], 18))
		var description := _label(entry[2], 12, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(description)
		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(56, 40)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.toggled.connect(func(enabled: bool): _set_option(key, enabled))
		row.add_child(toggle)
		switches[key] = toggle
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 20)
	page.add_child(controls)
	for entry in [["移动", "↑ ↓ ← →  /  WASD"], ["选择棋子", "Tab  /  Shift Tab"],
		["撤销", "Z"], ["重新开始", "R"], ["取消选择 / 暂停", "Esc"]]:
		var row := HBoxContainer.new()
		controls.add_child(row)
		row.add_child(_label(entry[0], 16))
		_spacer(row)
		row.add_child(_label(entry[1], 14, MUTED))
	var remaining := Control.new()
	remaining.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(remaining)
	status = _label("设置会自动保存。", 11, MUTED)
	page.add_child(status)
	_tab(false)
	refresh()

func _tab(show_controls: bool) -> void:
	general.visible = not show_controls
	controls.visible = show_controls
	heading.text = "操作" if show_controls else "设置"
	_accent(general_button, not show_controls)
	_accent(controls_button, show_controls)
	var active := controls_button if show_controls else general_button
	var marker: StyleBoxFlat = active.get_theme_stylebox("normal").duplicate()
	marker.set_border_width_all(0)
	marker.border_width_left = 2
	active.add_theme_stylebox_override("normal", marker)

func _set_option(key: String, enabled: bool) -> void:
	settings.set(key, enabled)
	status.text = "设置已保存。" if settings.save() == OK else "设置未能写入磁盘，当前会话仍然生效。"
	if key == "fullscreen":
		settings.apply_window()
	settings_changed.emit()

func refresh() -> void:
	for key in switches:
		switches[key].set_pressed_no_signal(settings.get(key))
