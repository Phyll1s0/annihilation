extends Control

const Puzzle = preload("res://scripts/puzzle.gd")
const Session = preload("res://scripts/session.gd")
const Progress = preload("res://scripts/progress.gd")
const Board = preload("res://scripts/board_view.gd")
const INK := Color("272a26")
const MUTED := Color("777c72")
const PAPER := Color("f2f0ea")
const LINE := Color("d5d7cc")

var levels: Array = []
var session = Session.new()
var progress = Progress.new()
var current := 0
var regular: SystemFont
var heavy: SystemFont
var board
var level_buttons: Array[Button] = []
var level_scroll: ScrollContainer
var title_label: Label
var chapter_label: Label
var description_label: Label
var count_label: Label
var goal_label: Label
var status_label: Label
var collection_label: Label
var easy_button: Button
var hard_button: Button
var undo_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_description: Label
var next_button: Button
var save_error := false

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	if not parsed is Array or parsed.is_empty():
		push_error("GRAY: level catalog is missing or invalid.")
		return
	levels = parsed
	_setup_theme()
	_build_ui()
	_open_level(0)

func _style(fill: Color, border: Color = LINE, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _setup_theme() -> void:
	regular = SystemFont.new()
	regular.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	heavy = SystemFont.new()
	heavy.font_names = regular.font_names
	heavy.font_weight = 700
	var ui := Theme.new()
	ui.default_font = regular
	ui.default_font_size = 15
	ui.set_color("font_color", "Label", INK)
	ui.set_color("font_color", "Button", INK)
	ui.set_color("font_hover_color", "Button", INK)
	ui.set_color("font_pressed_color", "Button", PAPER)
	ui.set_color("font_disabled_color", "Button", Color("a4a89d"))
	ui.set_stylebox("normal", "Button", _style(Color("eeeee5")))
	ui.set_stylebox("hover", "Button", _style(Color("fffdf6"), Color("9b9f92")))
	ui.set_stylebox("pressed", "Button", _style(INK, INK))
	ui.set_stylebox("disabled", "Button", _style(Color("e9eae1"), Color("dedfd5")))
	ui.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), MUTED))
	ui.set_constant("separation", "VBoxContainer", 12)
	ui.set_constant("separation", "HBoxContainer", 12)
	theme = ui

func _label(text: String, font_size: int = 15, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", heavy)
	return label

func _button(text: String, action: Callable, minimum: Vector2 = Vector2(0, 42)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _spacer(parent: Container) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _margin(parent: Node, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, amount)
	parent.add_child(margin)
	return margin

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := _margin(self, 32)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 30)
	margin.add_child(layout)
	_build_sidebar(layout)
	var divider := VSeparator.new()
	layout.add_child(divider)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	layout.add_child(content)
	_build_header(content)
	_build_board(content)
	_build_controls(content)

func _build_sidebar(parent: Container) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 240
	sidebar.add_theme_constant_override("separation", 8)
	parent.add_child(sidebar)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 6)
	sidebar.add_child(brand)
	brand.add_child(_label("GRAY", 57, INK, true))
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(icon)
	sidebar.add_child(_label("黑与白，相遇之后。", 16, MUTED))
	var rule := HSeparator.new()
	rule.custom_minimum_size.y = 30
	sidebar.add_child(rule)
	sidebar.add_child(_label("THE COLLECTION   /   01", 11, MUTED, true))
	var scroll := ScrollContainer.new()
	level_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var previous_chapter := ""
	for i in levels.size():
		if levels[i].chapter != previous_chapter:
			previous_chapter = levels[i].chapter
			var chapter := _label(previous_chapter, 12, MUTED)
			chapter.custom_minimum_size.y = 30
			chapter.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			list.add_child(chapter)
		var index := i
		var button := _button("", func(): _open_level(index), Vector2(226, 40))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(button)
		level_buttons.append(button)
	sidebar.add_child(HSeparator.new())
	collection_label = _label("", 12, MUTED)
	sidebar.add_child(collection_label)
	sidebar.add_child(_label("○ 简单通关     ◇ 困难通关", 11, MUTED))

func _build_header(parent: Container) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	header.add_child(heading)
	chapter_label = _label("", 12, MUTED, true)
	heading.add_child(chapter_label)
	title_label = _label("", 34, INK, true)
	heading.add_child(title_label)
	_spacer(header)
	var count := VBoxContainer.new()
	count.add_theme_constant_override("separation", 0)
	header.add_child(count)
	count_label = _label("00", 42, INK, true)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_child(count_label)
	goal_label = _label("", 12, MUTED)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_child(goal_label)
	var modes := HBoxContainer.new()
	parent.add_child(modes)
	easy_button = _button("简单 · 自由完成", func(): _change_mode(false), Vector2(170, 42))
	hard_button = _button("困难 · 最少步数", func(): _change_mode(true), Vector2(170, 42))
	modes.add_child(easy_button)
	modes.add_child(hard_button)
	_spacer(modes)
	modes.add_child(_label("一格一步 · 相遇即消融", 12, MUTED))
	description_label = _label("")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 40
	parent.add_child(description_label)

func _build_board(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("f9f8f2"), LINE, 18))
	parent.add_child(panel)
	var canvas := Control.new()
	canvas.custom_minimum_size.y = 220
	panel.add_child(canvas)
	board = Board.new()
	board.font = regular
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.cell_pressed.connect(_click_cell)
	board.animation_finished.connect(_sync)
	canvas.add_child(board)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -210
	result_panel.offset_right = 210
	result_panel.offset_top = -110
	result_panel.offset_bottom = 110
	result_panel.add_theme_stylebox_override("panel", _style(Color("f2f0ea"), INK, 16))
	canvas.add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	result_panel.add_child(box)
	var eyebrow := _label("B L A C K   +   W H I T E", 11, MUTED)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	result_title = _label("", 28, INK, true)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_description = _label("", 14, MUTED)
	result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_description)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	buttons.add_child(_button("再试一次", _restart))
	next_button = _button("下一关 →", _next)
	buttons.add_child(next_button)
	result_panel.hide()

func _build_controls(parent: Container) -> void:
	var toolbar := HBoxContainer.new()
	parent.add_child(toolbar)
	undo_button = _button("↶  撤销  Z", _undo, Vector2(120, 44))
	toolbar.add_child(undo_button)
	toolbar.add_child(_button("↻  重来  R", _restart, Vector2(120, 44)))
	_spacer(toolbar)
	for entry in [["←", "left"], ["↑", "up"], ["↓", "down"], ["→", "right"]]:
		var direction: String = entry[1]
		var button := _button(entry[0], func(): _try_move(direction), Vector2(46, 44))
		button.tooltip_text = "移动选中的棋子"
		toolbar.add_child(button)
	status_label = _label("", 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 20
	parent.add_child(status_label)
	parent.add_child(_label("点选棋子 → 点相邻格 / 方向键 / WASD     ·     Tab 切换棋子     ·     Esc 取消选择", 11, MUTED))

func _accent(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override("normal", _style(INK if active else Color("eeeee5"), INK if active else LINE))
	button.add_theme_color_override("font_color", PAPER if active else INK)

func _open_level(index: int) -> void:
	current = clampi(index, 0, levels.size() - 1)
	board.cancel_animation()
	session.start(levels[current], session.hard_mode)
	save_error = false
	_sync()
	level_scroll.call_deferred("ensure_control_visible", level_buttons[current])

func _change_mode(hard: bool) -> void:
	if hard == session.hard_mode:
		return
	session.hard_mode = hard
	_restart()

func _restart() -> void:
	board.cancel_animation()
	session.restart()
	save_error = false
	_sync()

func _undo() -> void:
	board.cancel_animation()
	session.undo()
	_sync()

func _next() -> void:
	_open_level((current + 1) % levels.size())

func _sync() -> void:
	if levels.is_empty():
		return
	var level: Dictionary = levels[current]
	chapter_label.text = "LEVEL  %02d   /   %s" % [current + 1, level.chapter]
	title_label.text = level.title
	description_label.text = level.description
	count_label.text = "%02d" % session.steps
	var record: Dictionary = progress.records.get(level.id, {})
	var best := "—" if record.is_empty() else str(record.best)
	goal_label.text = "目标 %d 步   /   最佳 %s" % [level.optimal_moves, best] if session.hard_mode else "已走步数   /   最佳 %s" % best
	_accent(easy_button, not session.hard_mode)
	_accent(hard_button, session.hard_mode)
	for i in level_buttons.size():
		var completed: Dictionary = progress.records.get(levels[i].id, {})
		level_buttons[i].text = "%02d   %s%s%s" % [i + 1, levels[i].title,
			"  ○" if completed.get("easy", false) else "", " ◇" if completed.get("hard", false) else ""]
		_accent(level_buttons[i], i == current)
	collection_label.text = "简单  %02d / %02d      困难  %02d / %02d" % [progress.completed(false), levels.size(), progress.completed(true), levels.size()]
	undo_button.disabled = session.history.is_empty()
	board.present(session.state, session.selected)
	var over: bool = session.hard_mode and session.steps > int(level.optimal_moves)
	status_label.text = "已超过最优步数，可撤销或重来；也可以继续探索。" if over else "选中棋子后，小圆点表示可以走入的相邻格。"
	if save_error:
		status_label.text = "本次通关未能写入存档；当前会话仍保留记录。"
	var finished := Puzzle.won(session.state)
	result_panel.visible = finished and not board.animating()
	if finished:
		result_title.text = "恰到好处。" if session.cleared() else "相遇了，再少几步。"
		if session.hard_mode:
			result_description.text = "%d 步完成 / 最优 %d 步 · %s" % [session.steps, level.optimal_moves,
				"困难通关" if session.cleared() else "困难尚未通关"]
		else:
			result_description.text = "%d 步完成 · 简单通关，试试困难模式？" % session.steps
		next_button.text = "返回第一关" if current == levels.size() - 1 else "下一关 →"

func _click_cell(index: int) -> void:
	if board.animating() or Puzzle.won(session.state):
		return
	var selected: int = session.selected
	if index == selected:
		session.selected = -1
	elif selected >= 0 and _adjacent(selected, index) and session.state.pieces[index] != session.state.pieces[selected]:
		var dx: int = index % session.state.width - selected % session.state.width
		var dy: int = floori(float(index) / session.state.width) - floori(float(selected) / session.state.width)
		_try_move("right" if dx == 1 else ("left" if dx == -1 else ("down" if dy == 1 else "up")))
		return
	elif session.state.pieces[index] != 0:
		session.selected = index
	_sync()

func _adjacent(a: int, b: int) -> bool:
	var width: int = session.state.width
	return absi(a % width - b % width) + absi(floori(float(a) / width) - floori(float(b) / width)) == 1

func _try_move(direction: String) -> void:
	if board.animating() or Puzzle.won(session.state):
		return
	if session.selected < 0:
		status_label.text = "先点选一颗棋子，或按 Tab 选择。"
		return
	var before: Dictionary = session.state
	var result: Dictionary = session.play(direction)
	if result.is_empty():
		status_label.text = "这一步走不通：检查地板、同色棋子和传送门的另一端。"
		return
	board.animate(result, before)
	if Puzzle.won(session.state):
		save_error = progress.record_clear(session.level.id, session.steps,
			int(session.level.optimal_moves), session.hard_mode) != OK
	_sync()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or levels.is_empty():
		return
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return
	var handled := true
	match event.physical_keycode:
		KEY_UP, KEY_W: _try_move("up")
		KEY_RIGHT, KEY_D: _try_move("right")
		KEY_DOWN, KEY_S: _try_move("down")
		KEY_LEFT, KEY_A: _try_move("left")
		KEY_Z: _undo()
		KEY_R: _restart()
		KEY_TAB:
			if not board.animating():
				session.cycle_selection(event.shift_pressed)
				_sync()
		KEY_ESCAPE:
			session.selected = -1
			_sync()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()
