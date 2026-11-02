extends Control
## An empty orbital zero: the space inside is the mark.
var blend := 0.0:
	set(value):
		blend = value
		queue_redraw()
var transition: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func respond(active: bool, reduced: bool) -> void:
	if transition != null and transition.is_running():
		transition.kill()
	if reduced:
		blend = 1.0 if active else 0.0
	else:
		transition = create_tween()
		transition.tween_property(self, "blend", 1.0 if active else 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 129:
		var angle := float(i) / 128.0 * TAU
		var oval := Vector2(cos(angle) * 19.0, sin(angle) * 28.0).rotated(0.24 - blend * 0.1)
		points.append(size / 2.0 + oval * (1.0 + blend * 0.045))
		var light := 0.24 + pow((sin(angle - 0.8) + 1.0) * 0.5, 2.0) * 0.62
		colors.append(Color("d8e1ee", light + blend * 0.12))
	draw_polyline_colors(points, colors, 1.25, true)
