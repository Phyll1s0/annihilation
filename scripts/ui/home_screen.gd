extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
var levels: Array = []
var progress
var settings
var continue_button: Button
var resume_label: Label
var statistics: Label
var info_panel: Control
var play_hint: Label

func _ready() -> void:
	_setup_theme()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 390
	body.add_theme_constant_override("separation", 18)
	center.add_child(body)
	var title := _title("GRAY", 70, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 40)
	body.add_child(actions)
	for item in [["information-outline", "关于", _show_info],
		["play-outline", "开始", _play],
		["settings-outline", "设置", func(): navigation_requested.emit("settings")]]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		actions.add_child(column)
		var action: Callable = item[2]
		var button := _icon_button(item[0], item[1], action, 29)
		button.custom_minimum_size = Vector2(76, 46)
		column.add_child(button)
		var hint := _label(item[1], 12, PRIMARY)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.modulate.a = 0
		column.add_child(hint)
		button.mouse_entered.connect(func(): hint.modulate.a = 1)
		button.mouse_exited.connect(func(): hint.modulate.a = 0)
		button.focus_entered.connect(func(): hint.modulate.a = 1)
		button.focus_exited.connect(func(): hint.modulate.a = 0)
		if item[0] == "play-outline":
			continue_button = button
			play_hint = hint
	resume_label = _label("", 12, MUTED)
	resume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(resume_label)
	statistics = _label("", 11, MUTED)
	statistics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	statistics.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	statistics.offset_top = -45
	statistics.offset_bottom = -22
	add_child(statistics)
	var github := _icon_button("logo-github", "GitHub · GRAY", func(): OS.shell_open("https://github.com/Phyll1s0/gray"), 29)
	github.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	github.offset_left = -72
	github.offset_right = -24
	github.offset_top = 24
	github.offset_bottom = 72
	add_child(github)
	_build_info()
	refresh()

func _play() -> void:
	navigation_requested.emit("campaign" if progress.resume.is_empty() else "continue")

func _show_info() -> void:
	info_panel.show()

func _build_info() -> void:
	info_panel = Control.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(info_panel)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 440
	panel.add_theme_stylebox_override("panel", _style(Color("262626"), LINE, 4))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	heading.add_child(_title("GRAY", 24, 3))
	_spacer(heading)
	heading.add_child(_icon_button("close-outline", "关闭", func(): info_panel.hide(), 22, 32))
	box.add_child(_label("让黑白相遇，清空棋盘。", 17))
	box.add_child(_label("每次移动一颗棋子一格。同色阻挡，异色消融。\n相遇时，两颗棋子与脚下的地板一起消失。\n相同字母的传送门连接彼此。", 14, MUTED))
	box.add_child(HSeparator.new())
	box.add_child(_label("简单：完成即可。\n困难：用最少的步数完成。", 14))
	box.add_child(_label("方向键 / WASD 移动 · Tab 选择\nZ 撤销 · R 重来 · Esc 暂停", 12, MUTED))
	info_panel.hide()

func refresh() -> void:
	if continue_button == null:
		return
	var saved: Dictionary = progress.resume
	continue_button.tooltip_text = "开始游戏" if saved.is_empty() else "继续游戏"
	play_hint.text = "开始" if saved.is_empty() else "继续"
	resume_label.visible = not saved.is_empty()
	resume_label.text = "" if saved.is_empty() else "关卡 %s · %s · 已走 %d 步" % [saved.level_id,
		"困难" if saved.hard_mode else "简单", saved.actions.size()]
	statistics.text = "GRAY  /  %02d LEVELS" % levels.size()
	if progress.completed(false) > 0:
		statistics.text += "     简单 %02d  ·  困难 %02d" % [progress.completed(false), progress.completed(true)]

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and info_panel.visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		info_panel.hide()
		get_viewport().set_input_as_handled()
