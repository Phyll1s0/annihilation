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
var chapter_label: Label
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
var standalone_background
var back_button: Button
var pause_button: Button
var modes: HBoxContainer
var toolbar: HBoxContainer
var notice: Tween

func _ready() -> void:
	settings.apply_language()
	if levels.is_empty():
		levels = Catalog.load_campaign().levels
	if levels.is_empty():
		return
	progress.bind_catalog(levels)
	_setup_theme()
	_build_ui()
	resized.connect(_layout_ui)
	_layout_ui()
	session.hard_mode = settings.hard_mode
	_open_level(0, false)

func apply_settings() -> void:
	if standalone_background != null:
		standalone_background.apply_settings()
	board.reduce_motion = settings.reduce_motion
	board.show_hints = settings.show_hints
	if settings.reduce_motion:
		board.cancel_animation()
	_sync()

func _build_ui() -> void:
	if get_parent() == get_tree().root:
		standalone_background = preload("res://scripts/ui/void_background.gd").new()
		standalone_background.settings = settings
		add_child(standalone_background)
		standalone_background.set_page("game")
	back_button = _back_button(func(): navigation_requested.emit("campaign"))
	pause_button = _icon_button("pause-outline", "Pause · Esc", func(): pause_requested.emit(), 28)
	add_child(pause_button)
	chapter_label = _label("", 11, MUTED)
	add_child(chapter_label)
	modes = HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	modes.offset_left = -130
	modes.offset_right = 130
	modes.offset_top = 28
	modes.offset_bottom = 62
	add_child(modes)
	easy_button = _button("Easy", func(): _change_mode(false), Vector2(96, 32))
	hard_button = _button("Hard", func(): _change_mode(true), Vector2(96, 32))
	for button in [easy_button, hard_button]:
		button.add_theme_font_size_override("font_size", 12)
		modes.add_child(button)
	board = Board.new()
	board.font = regular
	board.cell_pressed.connect(_click_cell)
	board.animation_finished.connect(_sync)
	add_child(board)
	toolbar = HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 16)
	add_child(toolbar)
	count_label = _label("0", 30, PRIMARY)
	count_label.add_theme_font_override("font", regular)
	toolbar.add_child(count_label)
	goal_label = _label("", 16, INK)
	goal_label.add_theme_font_override("font", regular)
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(goal_label)
	undo_button = _icon_button("arrow-undo-outline", "Undo · Z", _undo, 23, 32)
	toolbar.add_child(undo_button)
	toolbar.add_child(_icon_button("refresh-outline", "Restart · R", _restart, 24, 32))
	status_label = _label("", 11, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	_build_result(self)

func _layout_ui() -> void:
	if board == null:
		return
	var edge := clampf(size.x * 0.025, 16.0, 40.0)
	var compact := size.x < 600.0
	back_button.position = Vector2(edge, 20)
	chapter_label.position = Vector2(edge + 64, 34)
	pause_button.position = Vector2(size.x - edge - 48, 20)
	modes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	modes.offset_left = -110
	modes.offset_right = 110
	modes.offset_top = 76 if compact else 24
	modes.offset_bottom = modes.offset_top + 38
	var toolbar_top := 120.0 if compact else 78.0
	toolbar.position = Vector2((size.x - 320) / 2.0, toolbar_top)
	toolbar.size = Vector2(320, 46)
	var clearance := minf(toolbar_top + 68.0, size.y * 0.30)
	board.position = Vector2(edge, clearance)
	board.size = Vector2(maxf(1.0, size.x - edge * 2.0), maxf(1.0, size.y - clearance * 2.0))
	board.maximum_unit = clampf(minf(size.x, size.y) * 0.14, 56.0, 144.0)
	board._layout_board()
	board.queue_redraw()
	status_label.position = Vector2(edge, size.y - 48)
	status_label.size = Vector2(size.x - edge * 2.0, 32)
	var result_width := minf(480, size.x - edge * 2.0)
	result_panel.offset_left = -result_width / 2.0
	result_panel.offset_right = result_width / 2.0

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
	result_title = _label("", 30, PRIMARY)
	result_title.add_theme_font_override("font", regular)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_description = _label("", 16, INK)
	result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_description)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	box.add_child(buttons)
	buttons.add_child(_icon_button("refresh-outline", "Try again", _restart, 29))
	buttons.add_child(_icon_button("grid-outline", "Levels", func(): navigation_requested.emit("campaign"), 29))
	next_button = _icon_button("chevron-forward-outline", "Next level", _next, 31)
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
	chapter_label.text = "%02d" % [current + 1]
	chapter_label.tooltip_text = "%s / %s" % [tr(level.chapter), tr(level.title)]
	count_label.text = str(session.steps)
	var record: Dictionary = progress.records.get(level.id, {})
	var best := "—" if record.is_empty() else str(record.best)
	goal_label.text = "/ %d" % level.optimal_moves if session.hard_mode else tr_n("move", "moves", session.steps)
	count_label.tooltip_text = tr("Moves · Personal best: %s") % best
	_accent(easy_button, not session.hard_mode)
	_accent(hard_button, session.hard_mode)
	undo_button.disabled = session.history.is_empty()
	board.present(session.state, session.selected)
	board.visible = not Puzzle.won(session.state) or board.animating()
	if notice != null and notice.is_running():
		notice.kill()
	status_label.modulate.a = 1.0
	status_label.text = ""
	status_label.tooltip_text = ""
	if save_error:
		status_label.text = tr("Save failed")
		status_label.tooltip_text = tr("Your current game and records are still available in this session.")
	var finished := Puzzle.won(session.state)
	result_panel.visible = finished and not board.animating()
	if finished:
		result_title.text = (tr("Optimal") if session.hard_mode else tr("Complete")) if session.cleared() else tr("Try fewer moves")
		if session.hard_mode:
			result_description.text = tr("Moves: %d / %d") % [session.steps, level.optimal_moves]
		else:
			result_description.text = tr("Moves: %d") % session.steps
		next_button.tooltip_text = tr("Back to levels") if current == levels.size() - 1 else tr("Next level")

func _refresh_language() -> void:
	_sync()

func _show_notice(message: String) -> void:
	if save_error:
		return
	if notice != null and notice.is_running():
		notice.kill()
	status_label.text = tr(message)
	status_label.tooltip_text = ""
	status_label.modulate.a = 1.0
	notice = create_tween()
	notice.tween_interval(1.4)
	if not settings.reduce_motion:
		notice.tween_property(status_label, "modulate:a", 0.0, 0.25)
	notice.tween_callback(func(): status_label.text = "")

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
		_show_notice("Select a particle")
		return
	var before: Dictionary = session.state
	var result: Dictionary = session.play(direction)
	if result.is_empty():
		_show_notice("Cannot move")
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
