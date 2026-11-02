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
var title_label: Label
var chapter_label: Label
var description_label: Label
var count_label: Label
var goal_label: Label
var status_label: Label
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
	if get_parent() == get_tree().root:
		var background := preload("res://scripts/ui/abstract_background.gd").new()
		background.settings = settings
		add_child(background)
	_back_button(func(): navigation_requested.emit("campaign"))
	var pause := _icon_button("pause-outline", "暂停 · Esc", func(): pause_requested.emit(), 28)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -72
	pause.offset_right = -24
	pause.offset_top = 24
	pause.offset_bottom = 72
	add_child(pause)
	chapter_label = _label("", 11, MUTED)
	chapter_label.position = Vector2(90, 38)
	add_child(chapter_label)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	modes.offset_left = -130
	modes.offset_right = 130
	modes.offset_top = 28
	modes.offset_bottom = 62
	add_child(modes)
	easy_button = _button("简单", func(): _change_mode(false), Vector2(96, 32))
	hard_button = _button("困难", func(): _change_mode(true), Vector2(96, 32))
	for button in [easy_button, hard_button]:
		button.add_theme_font_size_override("font_size", 12)
		modes.add_child(button)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.10
	panel.anchor_top = 0.10
	panel.anchor_right = 0.90
	panel.anchor_bottom = 0.90
	panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.015), Color(1, 1, 1, 0.32), 0))
	add_child(panel)
	var canvas := Control.new()
	panel.add_child(canvas)
	board = Board.new()
	board.font = regular
	board.padding = Vector2(40, 32)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.offset_top = 60
	board.offset_bottom = -64
	board.cell_pressed.connect(_click_cell)
	board.animation_finished.connect(_sync)
	canvas.add_child(board)
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 16)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toolbar.offset_left = -180
	toolbar.offset_right = 180
	toolbar.offset_top = 4
	toolbar.offset_bottom = 50
	canvas.add_child(toolbar)
	count_label = _label("0", 30, PRIMARY)
	count_label.add_theme_font_override("font", tech)
	toolbar.add_child(count_label)
	goal_label = _label("", 16, INK)
	goal_label.add_theme_font_override("font", tech)
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(goal_label)
	undo_button = _icon_button("arrow-undo-outline", "撤销 · Z", _undo, 23, 32)
	toolbar.add_child(undo_button)
	toolbar.add_child(_icon_button("refresh-outline", "重新开始 · R", _restart, 24, 32))
	description_label = _label("", 13, MUTED)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	description_label.offset_top = -40
	description_label.offset_bottom = -12
	canvas.add_child(description_label)
	title_label = _title("", 17, 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title_label.offset_top = -68
	title_label.offset_bottom = -40
	add_child(title_label)
	status_label = _label("", 11, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_top = -34
	status_label.offset_bottom = -12
	add_child(status_label)
	_build_result(canvas)

func _build_result(canvas: Control) -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -240
	result_panel.offset_right = 240
	result_panel.offset_top = -100
	result_panel.offset_bottom = 130
	result_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	canvas.add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	result_panel.add_child(box)
	result_title = _label("", 40, PRIMARY)
	result_title.add_theme_font_override("font", tech)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_description = _label("", 16, INK)
	result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_description)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	box.add_child(buttons)
	buttons.add_child(_icon_button("refresh-outline", "再试一次", _restart, 29))
	buttons.add_child(_icon_button("grid-outline", "关卡选择", func(): navigation_requested.emit("campaign"), 29))
	next_button = _icon_button("chevron-forward-outline", "下一关", _next, 31)
	buttons.add_child(next_button)
	result_panel.hide()

func _open_level(index: int, persist: bool = true) -> void:
	current = clampi(index, 0, levels.size() - 1)
	board.cancel_animation()
	session.start(levels[current], session.hard_mode)
	save_error = false
	if persist:
		_save_checkpoint()
	apply_settings()

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
	goal_label.text = "/ %d" % level.optimal_moves if session.hard_mode else "步"
	count_label.tooltip_text = "个人最佳：" + best
	_accent(easy_button, not session.hard_mode)
	_accent(hard_button, session.hard_mode)
	undo_button.disabled = session.history.is_empty()
	board.present(session.state, session.selected)
	board.visible = not Puzzle.won(session.state) or board.animating()
	var over: bool = session.hard_mode and session.steps > int(level.optimal_moves)
	status_label.text = "已超过最优步数，可撤销或重来；也可以继续探索。" if over else "选中棋子后，小圆点表示可以走入的相邻格。"
	if save_error:
		status_label.text = "未能写入存档；当前会话仍保留对局和记录。"
	var finished := Puzzle.won(session.state)
	result_panel.visible = finished and not board.animating()
	if finished:
		result_title.text = ("PERFECT" if session.hard_mode else "COMPLETE") if session.cleared() else "TRY AGAIN"
		if session.hard_mode:
			result_description.text = "%d 步完成 / 最优 %d 步 · %s" % [session.steps, level.optimal_moves,
				"困难通关" if session.cleared() else "困难尚未通关"]
		else:
			result_description.text = "%d 步完成 · 简单通关，试试困难模式？" % session.steps
		next_button.tooltip_text = "返回选关" if current == levels.size() - 1 else "下一关"

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
