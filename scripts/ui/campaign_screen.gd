extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal level_requested(index: int, hard: bool)
const Catalog = preload("res://scripts/catalog.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const Board = preload("res://scripts/board_view.gd")
var levels: Array = []
var progress
var settings
var chapter := ""
var chapter_buttons: Array[Button] = []
var chapter_names: Array[String] = []
var cards: Array[Button] = []
var grid: GridContainer
var summary: Label
var easy_button: Button
var hard_button: Button

func _ready() -> void:
	_setup_theme()
	var margin := _margin(self, 40)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	margin.add_child(page)
	var nav := HBoxContainer.new()
	page.add_child(nav)
	nav.add_child(_button("← 首页", func(): navigation_requested.emit("home")))
	_spacer(nav)
	nav.add_child(_label("THE COLLECTION", 12, MUTED))
	nav.add_child(_button("设置", func(): navigation_requested.emit("settings")))
	page.add_child(_label("选择一次相遇", 38, INK, true))
	page.add_child(_label("简单模式找到一种解法，困难模式找到最短的那一种。", 16, MUTED))
	var modes := HBoxContainer.new()
	page.add_child(modes)
	easy_button = _button("简单 · 自由完成", func(): _mode(false), Vector2(180, 44))
	hard_button = _button("困难 · 最少步数", func(): _mode(true), Vector2(180, 44))
	modes.add_child(easy_button)
	modes.add_child(hard_button)
	_spacer(modes)
	summary = _label("", 13, MUTED)
	modes.add_child(summary)
	var chapters_row := HBoxContainer.new()
	page.add_child(chapters_row)
	chapter_names = Catalog.chapters(levels)
	chapter = chapter_names[0]
	for name_value in chapter_names:
		var name_copy := name_value
		var button := _button(name_copy, func(): chapter = name_copy; refresh(), Vector2(110, 40))
		chapters_row.add_child(button)
		chapter_buttons.append(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	page.add_child(_label("○ 简单通关   ◇ 困难通关   ·   所有关卡均可自由尝试", 12, MUTED))
	refresh()

func _mode(hard: bool) -> void:
	settings.hard_mode = hard
	settings.save()
	refresh()

func refresh() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	_accent(easy_button, not settings.hard_mode)
	_accent(hard_button, settings.hard_mode)
	for i in chapter_buttons.size():
		_accent(chapter_buttons[i], chapter_names[i] == chapter)
	var completed := 0
	var total := 0
	for i in levels.size():
		var definition: Dictionary = levels[i]
		if definition.chapter != chapter:
			continue
		total += 1
		var record: Dictionary = progress.records.get(definition.id, {})
		if record.get("hard" if settings.hard_mode else "easy", false):
			completed += 1
		var index := i
		var card := _button("", func(): level_requested.emit(index, settings.hard_mode), Vector2(280, 152))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		cards.append(card)
		var inset := _margin(card, 18)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(copy)
		copy.add_child(_label("LEVEL " + definition.id, 11, MUTED))
		copy.add_child(_label(definition.title, 23, INK, true))
		var note := "目标 %d 步" % definition.optimal_moves if settings.hard_mode else "自由完成"
		copy.add_child(_label(note + ("  ○" if record.get("easy", false) else "") + (" ◇" if record.get("hard", false) else ""), 12, MUTED))
		var preview := Board.new()
		preview.font = regular
		preview.padding = Vector2(12, 12)
		preview.maximum_unit = 24
		preview.custom_minimum_size = Vector2(118, 100)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.present(Puzzle.from_level(definition), -1)
		row.add_child(preview)
		for label in copy.get_children():
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.text = "本章完成 %02d / %02d" % [completed, total]
