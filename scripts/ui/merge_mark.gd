extends Control
## Two particles share a gray intersection: the game's rule becomes its mark.
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
		transition.tween_property(self, "blend", 1.0 if active else 0.0, 0.22).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	var radius := 13.0
	var offset := 10.0 - 5.0 * blend
	var center := size / 2.0
	var left := center - Vector2(offset, 0)
	var right := center + Vector2(offset, 0)
	draw_circle(left, radius, Color("090b0d"), true, -1, true)
	draw_arc(left, radius, 0, TAU, 64, Color("7c858e"), 1.0, true)
	draw_circle(right, radius, Color("e6e9ec"), true, -1, true)
	var angle := acos(offset / radius)
	var lens := PackedVector2Array()
	for i in 33:
		var a := lerpf(-angle, angle, float(i) / 32.0)
		lens.append(left + Vector2(cos(a), sin(a)) * radius)
	for i in range(1, 32):
		var a := lerpf(PI - angle, PI + angle, float(i) / 32.0)
		lens.append(right + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(lens, Color("828b94"))
