extends Control
## Vector-only rendering keeps the board sharp at every window size.

signal cell_pressed(index: int)
signal animation_finished
signal paint_started
signal paint_finished
signal cell_painted(index: int, erase: bool)

const Puzzle = preload("res://scripts/puzzle.gd")
const INK := Color("090a0c")
const PAPER := Color("eef1f4")
const LINE := Color(1, 1, 1, 0.25)
const PRIMARY := Color("dce1e5")
const PORTAL_COLORS := [Color("7bbce5"), Color("cea2df"), Color("8bcbb7"), Color("d9bd83")]

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
var reduce_motion := false
var show_hints := true
var padding := Vector2(40, 40)
var maximum_unit := 112.0
var visual_scale := 1.0
var edit_mode := false
var paint_button := 0
var last_painted := -1

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS if edit_mode else Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(func(): _layout_board(); queue_redraw())
	mouse_exited.connect(func(): hover = -1; queue_redraw())

func present(next: Dictionary, selection: int) -> void:
	state = next
	selected = selection
	_layout_board()
	queue_redraw()

func animate(result: Dictionary, before: Dictionary) -> void:
	if reduce_motion:
		motion = {}
		queue_redraw()
		return
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
	if (selected >= 0 and not reduce_motion) or animating():
		queue_redraw()

func _layout_board() -> void:
	if state.is_empty():
		return
	var available := (size - padding).max(Vector2.ONE)
	unit = maxf(1.0, minf(maximum_unit, minf(available.x / state.width, available.y / state.height)))
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

func _get_tooltip(at_position: Vector2) -> String:
	if state.is_empty(): return ""
	var cell := _cell_at(at_position)
	if cell < 0: return ""
	var direction := Puzzle.field_direction(state.board[cell])
	return tr({"up": "Leave this tile only upward.", "right": "Leave this tile only to the right.",
		"down": "Leave this tile only downward.", "left": "Leave this tile only to the left."}.get(direction, ""))

func _gui_input(event: InputEvent) -> void:
	if state.is_empty():
		return
	if edit_mode:
		_edit_input(event)
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

func _edit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			paint_button = event.button_index
			last_painted = -1
			paint_started.emit()
			_paint_at(event.position)
		else:
			paint_button = 0
			paint_finished.emit()
		accept_event()
	elif event is InputEventMouseMotion and paint_button != 0:
		var mask := MOUSE_BUTTON_MASK_LEFT if paint_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
		if (event.button_mask & mask) == 0:
			paint_button = 0
			paint_finished.emit()
			return
		_paint_at(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			paint_button = MOUSE_BUTTON_LEFT
			last_painted = -1
			paint_started.emit()
			_paint_at(event.position)
		else:
			paint_button = 0
			paint_finished.emit()
		accept_event()
	elif event is InputEventScreenDrag:
		_paint_at(event.position)
		accept_event()

func _paint_at(point: Vector2) -> void:
	var cell := _cell_at(point)
	if cell >= 0 and cell != last_painted:
		last_painted = cell
		cell_painted.emit(cell, paint_button == MOUSE_BUTTON_RIGHT)

func _portal_color(group: int) -> Color:
	if group >= 1 and group <= PORTAL_COLORS.size():
		return PORTAL_COLORS[group - 1]
	return Color.from_hsv(fposmod(0.57 + (group - 1) * 0.61803398875, 1.0), 0.36, 0.88)

func _tile(index: int, terrain: int, opacity: float = 1.0) -> void:
	var portal := terrain if Puzzle.is_portal(terrain) else 0
	var tile_size := unit - 2.0 * visual_scale
	var top_left := (center_of(index) - Vector2.ONE * tile_size / 2.0).round()
	var bottom_right := (center_of(index) + Vector2.ONE * tile_size / 2.0).round()
	var rect := Rect2(top_left, bottom_right - top_left)
	var style := StyleBoxFlat.new()
	var portal_color := _portal_color(portal)
	style.bg_color = Color(1, 1, 1, 0.035 * opacity) if portal == 0 else Color(portal_color, 0.12 * opacity)
	style.border_color = Color(1, 1, 1, 0.25 * opacity) if portal == 0 else Color(portal_color, 0.70 * opacity)
	style.set_border_width_all(maxi(1, roundi(visual_scale)))
	var corner := roundi((3.0 if portal == 0 else 10.0) * visual_scale)
	style.set_corner_radius_all(corner)
	style.corner_detail = clampi(ceili(corner / 2.0), 8, 32)
	style.anti_aliasing_size = 1.0
	if portal == 0:
		var up: bool = index >= state.width and state.board[index - state.width] == 0
		var down: bool = index + state.width < state.board.size() and state.board[index + state.width] == 0
		var left: bool = index % state.width > 0 and state.board[index - 1] == 0
		var right: bool = index % state.width < state.width - 1 and state.board[index + 1] == 0
		style.corner_radius_top_left = 0 if up or left else corner
		style.corner_radius_top_right = 0 if up or right else corner
		style.corner_radius_bottom_left = 0 if down or left else corner
		style.corner_radius_bottom_right = 0 if down or right else corner
	draw_style_box(style, rect)
	if portal > 0:
		var tag := String.chr(64 + portal)
		var tag_size := maxi(8, roundi(unit * 0.16))
		draw_string(font, rect.position + Vector2(maxf(2, unit * 0.09), tag_size + 2 * visual_scale), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(portal_color, opacity * 0.95))
	var direction := Puzzle.field_direction(terrain)
	if not direction.is_empty():
		# The small corner arrow stays visible beneath either particle color.
		var axis := Vector2(Puzzle.DIRECTIONS[direction])
		var side := axis.orthogonal()
		var arrow_center := rect.position + Vector2.ONE * unit * 0.17
		var tip := arrow_center + axis * unit * 0.07
		var tint := Color(PRIMARY, opacity * 0.85)
		var stroke := maxf(1.0, unit * 0.018)
		draw_line(arrow_center - axis * unit * 0.07, tip, tint, stroke, true)
		draw_polyline(PackedVector2Array([tip - axis * unit * 0.045 + side * unit * 0.045, tip,
			tip - axis * unit * 0.045 - side * unit * 0.045]), tint, stroke, true)

func _piece(point: Vector2, color: int, radius: float, opacity: float = 1.0, active: bool = false) -> void:
	if radius < 0.1:
		return
	draw_circle(point, radius, Color(INK if color == -1 else PAPER, opacity), true, -1, true)
	draw_arc(point, radius, 0, TAU, _arc_segments(radius), Color(PAPER, opacity * 0.85) if color == 1 else Color(Color("8d949b"), opacity), visual_scale, true)
	if active:
		var pulse := 1.0 if reduce_motion else 1.0 + sin(clock * 3.0) * 0.025
		var ring := (radius + unit * 0.07) * pulse
		draw_arc(point, ring, 0, TAU, _arc_segments(ring), PRIMARY, 2.0 * visual_scale, true)

func _arc_segments(radius: float) -> int:
	return clampi(ceili(TAU * radius / 3.0), 64, 512)

func _draw() -> void:
	if state.is_empty() or font == null:
		return
	_layout_board()
	var t := clampf(elapsed / 0.34, 0, 1)
	for i in state.board.size():
		if state.board[i] < 0:
			if edit_mode: _tile(i, 0, 0.22)
			continue
		else:
			_tile(i, state.board[i])
	if animating() and motion.merged:
		_tile(motion.target, previous.board[motion.target], 1.0 - t)
	if show_hints and selected >= 0 and not animating():
		for direction in Puzzle.DIRECTIONS:
			var result := Puzzle.move(state, selected, direction)
			if not result.is_empty():
				draw_circle(center_of(result.entry), unit * 0.045, Color(PRIMARY, 0.45), true, -1, true)
	for i in state.pieces.size():
		if state.pieces[i] == 0 or (animating() and i == int(motion.target)):
			continue
		_piece(center_of(i), state.pieces[i], unit * 0.225, 1.0, i == selected)
		if i == hover and i != selected and not animating():
			draw_arc(center_of(i), unit * 0.31, 0, TAU, _arc_segments(unit * 0.31), Color(PAPER, 0.40), visual_scale, true)
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
			_piece(center_of(motion.target), -int(motion.color), unit * 0.225 * (1.0 - smoothstep(0.55, 1, t)), 1.0 - t * 0.5)
			scale *= 1.0 - smoothstep(0.65, 1, t)
		_piece(point, motion.color, unit * 0.225 * scale)
		if motion.merged and t > 0.55:
			var fade := sin((t - 0.55) / 0.45 * PI)
			draw_circle(center_of(motion.target), unit * 0.27 * fade, Color("92989f", fade), true, -1, true)
			var ring := unit * (0.25 + t * 0.3)
			draw_arc(center_of(motion.target), ring, 0, TAU, _arc_segments(ring), Color(PAPER, (1 - t) * 0.45), visual_scale, true)
