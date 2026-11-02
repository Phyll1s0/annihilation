extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
const Board = preload("res://scripts/board_view.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var levels: Array = []
var progress
var settings
var continue_button: Button
var resume_label: Label
var statistics: Label

func _ready() -> void:
	_setup_theme()
	var margin := _margin(self, 56)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 30)
	margin.add_child(page)
	var nav := HBoxContainer.new()
	page.add_child(nav)
	nav.add_child(_label("GRAY  /  灰", 23, INK, true))
	_spacer(nav)
	nav.add_child(_label("A PUZZLE ABOUT WHAT REMAINS", 11, MUTED))
	var hero := HBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", 64)
	page.add_child(hero)
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 470
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 20)
	hero.add_child(copy)
	copy.add_child(_label("B L A C K   +   W H I T E", 12, MUTED))
	copy.add_child(_label("两种颜色。\n一场相遇。", 54, INK, true))
	copy.add_child(_label("让黑白彼此消融，也为下一次相遇留一条路。", 17, MUTED))
	continue_button = _button("继续游戏 →", func(): navigation_requested.emit("continue"), Vector2(270, 52))
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_accent(continue_button, true)
	copy.add_child(continue_button)
	resume_label = _label("", 12, MUTED)
	copy.add_child(resume_label)
	var actions := HBoxContainer.new()
	copy.add_child(actions)
	actions.add_child(_button("选择关卡", func(): navigation_requested.emit("campaign"), Vector2(130, 44)))
	actions.add_child(_button("游戏设置", func(): navigation_requested.emit("settings"), Vector2(130, 44)))
	var artwork := PanelContainer.new()
	artwork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	artwork.add_theme_stylebox_override("panel", _style(Color("e7e8df"), LINE, 28))
	hero.add_child(artwork)
	var art_box := VBoxContainer.new()
	artwork.add_child(art_box)
	var board := Board.new()
	board.font = regular
	board.padding = Vector2(36, 36)
	board.maximum_unit = 110
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.present(Puzzle.from_level({"layout": ["w.b", "...", "b.w"]}), -1)
	art_box.add_child(board)
	var caption := _label("每一次消融，都改变下一步。", 14, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y = 44
	art_box.add_child(caption)
	page.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	page.add_child(footer)
	statistics = _label("", 13, MUTED)
	footer.add_child(statistics)
	_spacer(footer)
	footer.add_child(_label("GRAY  0.2   ·   GODOT", 11, MUTED))
	refresh()

func refresh() -> void:
	if continue_button == null:
		return
	var saved: Dictionary = progress.resume
	continue_button.text = "继续游戏 →" if not saved.is_empty() else "开始游戏 →"
	resume_label.text = "从尚未完成的关卡开始" if saved.is_empty() else "关卡 %s · %s · 已走 %d 步" % [saved.level_id,
		"困难" if saved.hard_mode else "简单", saved.actions.size()]
	statistics.text = "%d 个关卡   /   简单 %02d   /   困难 %02d" % [levels.size(), progress.completed(false), progress.completed(true)]
