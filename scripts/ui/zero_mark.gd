extends Control
## An empty orbital zero: the space inside is the mark.
var blend := 0.0:
	set(value):
		blend = value
		queue_redraw()
var transition: Tween
var elapsed := 0.0
var frame_time := 0.0
var reduced_motion := false
var visual_scale := 1.0:
	set(value):
		visual_scale = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(_update_processing)
	_update_processing()

func _update_processing() -> void:
	set_process(is_visible_in_tree() and not reduced_motion)

func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 60.0)
	frame_time += delta
	if frame_time >= 1.0 / 30.0:
		frame_time = fmod(frame_time, 1.0 / 30.0)
		queue_redraw()

func respond(active: bool, reduced: bool) -> void:
	reduced_motion = reduced
	_update_processing()
	if transition != null and transition.is_running():
		transition.kill()
	if reduced:
		blend = 1.0 if active else 0.0
	else:
		transition = create_tween()
		transition.tween_property(self, "blend", 1.0 if active else 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	# A slow turn of the oval, with a faster silver highlight following its edge.
	var turn := elapsed * TAU / 60.0
	var highlight := 0.8 + elapsed * TAU / 10.0
	var tilt := 0.24 + turn - blend * 0.1
	var scale_factor := visual_scale * (1.0 + blend * 0.045)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 129:
		var angle := float(i) / 128.0 * TAU
		var oval := Vector2(cos(angle) * 19.0, sin(angle) * 28.0).rotated(tilt)
		points.append(size / 2.0 + oval * scale_factor)
		var wave := (cos(angle - highlight) + 1.0) * 0.5
		var light := 0.22 + pow(wave, 2.0) * 0.38 + pow(wave, 12.0) * 0.28
		colors.append(Color("d8e1ee", light + blend * 0.12))
	draw_polyline_colors(points, colors, 1.25 * visual_scale, true)
	var head := Vector2(cos(highlight) * 19.0, sin(highlight) * 28.0).rotated(tilt)
	draw_circle(size / 2.0 + head * scale_factor, 1.1 * visual_scale, Color("e4ebf5", 0.78 + blend * 0.12), true, -1, true)
