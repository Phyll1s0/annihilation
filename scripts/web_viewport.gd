extends Node
## Lay out in CSS pixels while the canvas keeps its high-DPI rendering resolution.
var canvas: JavaScriptObject
var logical_size := Vector2i.ZERO

func _ready() -> void:
	canvas = JavaScriptBridge.get_interface("document").getElementById("canvas")
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_sync_size()

func _process(_delta: float) -> void:
	_sync_size()

func _sync_size() -> void:
	var next := Vector2i(int(canvas.clientWidth), int(canvas.clientHeight))
	if next.x <= 0 or next.y <= 0 or next == logical_size: return
	logical_size = next
	get_window().content_scale_size = logical_size
