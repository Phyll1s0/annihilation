extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal settings_changed
var settings
var switches: Dictionary = {}
var status: Label

func _ready() -> void:
	_setup_theme()
	var margin := _margin(self, 40)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var back := _button("← 返回", func(): navigation_requested.emit("back"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(back)
	page.add_child(_label("按自己的节奏。", 42, INK, true))
	page.add_child(_label("游戏设置", 15, MUTED))
	for entry in [["show_hints", "显示可走邻格", "只显示合法相邻格，不提供解法。"],
		["reduce_motion", "减少动态效果", "立即显示行动结果，并关闭选中光环的呼吸动画。"],
		["fullscreen", "全屏显示", "也可以随时按 F11 切换。"]]:
		var key: String = entry[0]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("f9f8f2")))
		page.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var toggle := CheckButton.new()
		toggle.text = entry[1]
		toggle.custom_minimum_size.y = 36
		toggle.toggled.connect(func(enabled: bool): _set_option(key, enabled))
		box.add_child(toggle)
		box.add_child(_label(entry[2], 13, MUTED))
		switches[key] = toggle
	page.add_child(_label("操作\n\n点选棋子，再点相邻格；方向键或 WASD 移动。\nTab / Shift Tab 切换棋子，Z 撤销，R 重开。\nEsc 先取消选择，再打开暂停菜单。", 15, MUTED))
	status = _label("设置会自动保存。", 12, MUTED)
	page.add_child(status)
	refresh()

func _set_option(key: String, enabled: bool) -> void:
	settings.set(key, enabled)
	status.text = "设置已保存。" if settings.save() == OK else "设置未能写入磁盘，当前会话仍然生效。"
	if key == "fullscreen":
		settings.apply_window()
	settings_changed.emit()

func refresh() -> void:
	for key in switches:
		switches[key].set_pressed_no_signal(settings.get(key))
