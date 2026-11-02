extends ColorRect
## Sparse orbital trails over true black, with an empty center.
const SILVER := Color("bcc8dc")
var settings
var field: Control
var clock := 0.0
var frame_time := 0.0
var page := "home"
var transition: Tween
var trails: Array[Dictionary] = []
var stars: Array[Vector4] = []
var detail := 1.0:
	set(value):
		detail = value
		if field != null:
			field.queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.BLACK
	field = Control.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.draw.connect(_draw_field)
	add_child(field)
	resized.connect(func(): field.queue_redraw())
	var random := RandomNumberGenerator.new()
	random.seed = 20261102
	for i in 36:
		trails.append({
			"radius": random.randf_range(0.56, 1.13),
			"angle": random.randf_range(0.0, TAU),
			"length": random.randf_range(0.12, 0.70),
			"alpha": random.randf_range(0.08, 0.26),
			"pin": i % 4 == 0,
		})
	for i in 74:
		stars.append(Vector4(random.randf(), random.randf(), random.randf_range(0.16, 0.52), random.randf_range(0.5, 1.1)))
	# A few composed arcs frame the title, especially on the quieter right side.
	for arc in [Vector4(0.57, 3.63, 0.36, 0.17), Vector4(0.63, 3.45, 0.24, 0.15),
		Vector4(0.43, -0.42, 0.40, 0.18), Vector4(0.35, 0.25, 0.48, 0.15),
		Vector4(0.36, 0.90, 0.38, 0.20), Vector4(0.48, 1.30, 0.40, 0.14)]:
		trails.append({"radius": arc.x, "angle": arc.y, "length": arc.z,
			"alpha": arc.w, "pin": false, "home_only": true})
	apply_settings()

func set_page(destination: String) -> void:
	page = destination
	if transition != null and transition.is_running():
		transition.kill()
	var target := 1.0 if page == "home" else 0.28 if page == "game" else 0.46
	if settings.reduce_motion:
		detail = target
	else:
		transition = create_tween()
		transition.tween_property(self, "detail", target, 0.6).set_trans(Tween.TRANS_SINE)

func apply_settings() -> void:
	set_process(not settings.reduce_motion)
	set_page(page)
	field.queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	frame_time += delta
	if frame_time >= 1.0 / 30.0:
		frame_time = fmod(frame_time, 1.0 / 30.0)
		field.queue_redraw()

func _orbit(angle: float, radius: float) -> Vector2:
	var point := Vector2(cos(angle) * 1.1, sin(angle) * 0.82).rotated(-0.34)
	return size * Vector2(0.65, 0.43) + point * radius * size.y

func _clear_center(point: Vector2) -> float:
	var distance := ((point - size * Vector2(0.5, 0.48)) / size.y).length()
	return smoothstep(0.17, 0.43, distance)

func _draw_field() -> void:
	for star in stars:
		var point := Vector2(star.x, star.y) * size
		var alpha := star.z * _clear_center(point) * detail
		field.draw_circle(point, star.w, Color(SILVER, alpha), true, -1, true)
	for trail in trails:
		if trail.get("home_only", false) and page != "home":
			continue
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in 37:
			var t := float(i) / 36.0
			var angle: float = trail.angle + clock * 0.002 - trail.length * (1.0 - t)
			var point := _orbit(angle, trail.radius)
			points.append(point)
			colors.append(Color(SILVER, trail.alpha * pow(t, 1.5) * _clear_center(point) * detail))
		field.draw_polyline_colors(points, colors, 0.8, true)
		if trail.pin:
			field.draw_circle(points[-1], 1.0, Color(SILVER, 0.5 * _clear_center(points[-1]) * detail), true, -1, true)
	if not settings.reduce_motion and page == "home":
		_draw_meteor()

func _draw_meteor() -> void:
	# One short, quiet pass every 19 seconds; never an opening-screen delay.
	var phase := fmod(clock + 3.0, 19.0)
	if phase > 2.4:
		return
	var t := phase / 2.4
	var head := size * Vector2(0.78, 0.10) + Vector2(-0.29, 0.23) * size.y * t
	var direction := Vector2(-0.29, 0.23).normalized()
	var envelope := sin(t * PI) * 0.55 * detail
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 17:
		var u := float(i) / 16.0
		points.append(head - direction * (1.0 - u) * size.y * 0.12)
		colors.append(Color(SILVER, envelope * u * u))
	field.draw_polyline_colors(points, colors, 1.0, true)
	field.draw_circle(head, 1.1, Color("e3eaf5", envelope), true, -1, true)
