extends "res://scripts/ui/screen_base.gd"

const Puzzle = preload("res://scripts/puzzle.gd")
const Session = preload("res://scripts/session.gd")
const Progress = preload("res://scripts/progress.gd")
const Board = preload("res://scripts/board_view.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Settings = preload("res://scripts/settings.gd")

signal navigation_requested(destination: String)
signal pause_requested
signal state_changed

var levels: Array = []
var session = Session.new()
var progress = Progress.new()
var settings = Settings.new()
var input_enabled := true
var current := 0
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
	if levels.is_empty():
		levels = Catalog.load_campaign().levels
	if levels.is_empty():
		return
	progress.bind_catalog(levels)
	_setup_theme()
	_build_ui()
	session.hard_mode = settings.hard_mode
	_open_level(0, false)

func apply_settings() -> void:
	board.reduce_motion = settings.reduce_motion
	board.show_hints = settings.show_hints
	if settings.reduce_motion:
		board.cancel_animation()
	_sync()

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
	var navigation := HBoxContainer.new()
	sidebar.add_child(navigation)
	navigation.add_child(_button("← 选关", func(): navigation_requested.emit("campaign"), Vector2(110, 34)))
	navigation.add_child(_button("暂停  Esc", func(): pause_requested.emit(), Vector2(110, 34)))
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
	parent.add_child(_label("点选棋子 → 点相邻格 / 方向键 / WASD   ·   Tab 切换棋子   ·   Esc 取消选择／暂停", 11, MUTED))

func _open_level(index: int, persist: bool = true) -> void:
	current = clampi(index, 0, levels.size() - 1)
	board.cancel_animation()
	session.start(levels[current], session.hard_mode)
	save_error = false
	if persist:
		_save_checkpoint()
	apply_settings()
	level_scroll.call_deferred("ensure_control_visible", level_buttons[current])

func _change_mode(hard: bool) -> void:
	if hard == session.hard_mode:
		return
	session.hard_mode = hard
	settings.hard_mode = hard
	settings.save()
	_restart()

func _restart() -> void:
	board.cancel_animation()
	session.restart()
	save_error = false
	_save_checkpoint()
	_sync()

func _undo() -> void:
	board.cancel_animation()
	session.undo()
	_save_checkpoint()
	_sync()

func _next() -> void:
	if current == levels.size() - 1:
		navigation_requested.emit("campaign")
	else:
		_open_level(current + 1)

func _save_checkpoint() -> void:
	save_error = progress.checkpoint(session) != OK
	state_changed.emit()

func restore_checkpoint() -> bool:
	var saved: Dictionary = progress.resume
	var index := Catalog.index_of(levels, str(saved.get("level_id", "")))
	if index < 0 or saved.get("content_hash") != Catalog.fingerprint(levels[index]) or not saved.get("actions") is Array or not saved.get("hard_mode") is bool:
		return false
	if not session.restore(levels[index], saved.hard_mode, saved.actions) or Puzzle.won(session.state):
		return false
	current = index
	apply_settings()
	level_scroll.call_deferred("ensure_control_visible", level_buttons[current])
	return true

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
		status_label.text = "未能写入存档；当前会话仍保留对局和记录。"
	var finished := Puzzle.won(session.state)
	result_panel.visible = finished and not board.animating()
	if finished:
		result_title.text = "恰到好处。" if session.cleared() else "相遇了，再少几步。"
		if session.hard_mode:
			result_description.text = "%d 步完成 / 最优 %d 步 · %s" % [session.steps, level.optimal_moves,
				"困难通关" if session.cleared() else "困难尚未通关"]
		else:
			result_description.text = "%d 步完成 · 简单通关，试试困难模式？" % session.steps
		next_button.text = "返回选关" if current == levels.size() - 1 else "下一关 →"

func _click_cell(index: int) -> void:
	if not input_enabled or board.animating() or Puzzle.won(session.state):
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
	if not input_enabled or board.animating() or Puzzle.won(session.state):
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
		save_error = progress.record_clear(session.level, session.steps, session.hard_mode) != OK
		state_changed.emit()
	else:
		_save_checkpoint()
	_sync()

func _input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or levels.is_empty():
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
			if session.selected >= 0:
				session.selected = -1
				_sync()
			else:
				pause_requested.emit()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()
