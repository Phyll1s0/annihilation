extends Control
## Vector-only rendering keeps the board sharp at every window size.

signal cell_pressed(index: int)
signal animation_finished

const Puzzle = preload("res://scripts/puzzle.gd")
const INK := Color("272a26")
const PAPER := Color("fffdf7")
const LINE := Color("d2d2c8")

var state: Dictionary = {}
var selected := -1
var hover := -1
var font: Font
var motion: Dictionary = {}
var previous: Dictionary = {}
var elapsed := 0.0
var clock := 0.0
var unit := 80.0
var origin := Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	mouse_exited.connect(func(): hover = -1; queue_redraw())

func present(next: Dictionary, selection: int) -> void:
	state = next
	selected = selection
	queue_redraw()

func animate(result: Dictionary, before: Dictionary) -> void:
	motion = result
	previous = before
	elapsed = 0.0

func cancel_animation() -> void:
	motion = {}
	queue_redraw()

func animating() -> bool:
	return not motion.is_empty()

func _process(delta: float) -> void:
	clock += delta
	if animating():
		elapsed += delta
		if elapsed >= 0.34:
			motion = {}
			animation_finished.emit()
	if selected >= 0 or animating():
		queue_redraw()

func _layout_board() -> void:
	if state.is_empty():
		return
	unit = minf(94.0, minf((size.x - 88.0) / state.width, (size.y - 80.0) / state.height))
	origin = (size - Vector2(state.width, state.height) * unit) / 2.0

func center_of(index: int) -> Vector2:
	return origin + Vector2(index % state.width + 0.5, floori(float(index) / state.width) + 0.5) * unit

func _cell_at(point: Vector2) -> int:
	_layout_board()
	var local := (point - origin) / unit
	var x := floori(local.x)
	var y := floori(local.y)
	if x < 0 or x >= state.width or y < 0 or y >= state.height:
		return -1
	return y * state.width + x

func _gui_input(event: InputEvent) -> void:
	if state.is_empty():
		return
	if event is InputEventMouseMotion:
		hover = _cell_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _cell_at(event.position)
		if index >= 0:
			cell_pressed.emit(index)
		accept_event()
	if event is InputEventScreenTouch and event.pressed:
		var index := _cell_at(event.position)
		if index >= 0:
			cell_pressed.emit(index)
		accept_event()

func _tile(index: int, portal: int, opacity: float = 1.0) -> void:
	var rect := Rect2(center_of(index) - Vector2.ONE * (unit - 8) / 2.0, Vector2.ONE * (unit - 8))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e6e6dc") if portal == 0 else Color("dadcd2")
	style.bg_color.a = opacity
	style.border_color = Color(LINE, opacity)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	draw_style_box(style, rect)
	if portal > 0:
		var tag := "A" if portal == 1 else "B"
		draw_string(font, rect.position + Vector2(8, 17), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, opacity * 0.60))
		draw_arc(center_of(index), unit * 0.31, 0, TAU, 48, Color(INK, opacity * 0.22), 1.0, true)
		draw_arc(center_of(index), unit * 0.26, 0, TAU, 48, Color(INK, opacity * 0.12), 1.0, true)

func _piece(point: Vector2, color: int, radius: float, opacity: float = 1.0, active: bool = false) -> void:
	if radius < 0.1:
		return
	draw_circle(point + Vector2(0, 3), radius + 1, Color(INK, opacity * 0.08), true, -1, true)
	draw_circle(point, radius, Color(INK if color == -1 else PAPER, opacity), true, -1, true)
	draw_arc(point, radius, 0, TAU, 64, Color(INK, opacity * (0.9 if color == 1 else 1.0)), 1.5, true)
	draw_circle(point - Vector2(radius * 0.25, radius * 0.30), radius * 0.14,
		Color(PAPER if color == -1 else INK, opacity * 0.35), true, -1, true)
	if active:
		var pulse := 1.0 + sin(clock * 3.0) * 0.025
		draw_arc(point, (radius + 7) * pulse, 0, TAU, 64, Color(INK, 0.65), 1.4, true)

func _draw() -> void:
	if state.is_empty() or font == null:
		return
	_layout_board()
	var t := clampf(elapsed / 0.34, 0, 1)
	for i in state.board.size():
		if state.board[i] < 0:
			draw_circle(center_of(i), 1.5, Color("d8d8cf"), true, -1, true)
		else:
			_tile(i, state.board[i])
	if animating() and motion.merged:
		_tile(motion.target, previous.board[motion.target], 1.0 - t)
	if selected >= 0 and not animating():
		for direction in Puzzle.DIRECTIONS:
			var result := Puzzle.move(state, selected, direction)
			if not result.is_empty():
				draw_circle(center_of(result.entry), unit * 0.065, Color(INK, 0.24), true, -1, true)
	for i in state.pieces.size():
		if state.pieces[i] == 0 or (animating() and i == int(motion.target)):
			continue
		_piece(center_of(i), state.pieces[i], unit * 0.245, 1.0, i == selected)
		if i == hover and i != selected and not animating():
			draw_arc(center_of(i), unit * 0.34, 0, TAU, 48, Color(INK, 0.28), 1, true)
	if animating():
		var point: Vector2
		var scale := 1.0
		if motion.teleported:
			if t < 0.45:
				point = center_of(motion.source).lerp(center_of(motion.entry), smoothstep(0, 0.45, t))
				scale = 1.0 - smoothstep(0.28, 0.45, t)
			else:
				point = center_of(motion.target)
				scale = smoothstep(0.45, 0.65, t)
		else:
			point = center_of(motion.source).lerp(center_of(motion.target), smoothstep(0, 0.7, t))
		if motion.merged:
			_piece(center_of(motion.target), -int(motion.color), unit * 0.245 * (1.0 - smoothstep(0.55, 1, t)), 1.0 - t * 0.5)
			scale *= 1.0 - smoothstep(0.65, 1, t)
		_piece(point, motion.color, unit * 0.245 * scale)
		if motion.merged and t > 0.55:
			var fade := sin((t - 0.55) / 0.45 * PI)
			draw_circle(center_of(motion.target), unit * 0.27 * fade, Color("969990", fade), true, -1, true)
			draw_arc(center_of(motion.target), unit * (0.25 + t * 0.3), 0, TAU, 64, Color(INK, (1 - t) * 0.45), 1, true)
