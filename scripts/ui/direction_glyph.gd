extends Control
## A single vector arrow shared by field tiles and editor tools.
var direction := "right"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var axis := Vector2({"up": Vector2.UP, "right": Vector2.RIGHT,
		"down": Vector2.DOWN, "left": Vector2.LEFT}[direction])
	draw_mark(self, size / 2.0, axis, minf(size.x, size.y) * 0.75,
		Color("dce1e5"), maxf(1.5, minf(size.x, size.y) * 0.035))

static func draw_mark(canvas: CanvasItem, center: Vector2, axis: Vector2,
		span: float, tint: Color, stroke: float) -> void:
	var side := axis.orthogonal()
	var tip := center + axis * span * 0.45
	var base := center + axis * span * 0.04
	canvas.draw_line(center - axis * span * 0.45, tip, tint, stroke, true)
	canvas.draw_polyline(PackedVector2Array([base + side * span * 0.33,
		tip, base - side * span * 0.33]), tint, stroke, true)
