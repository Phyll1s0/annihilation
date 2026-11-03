extends Node
## Keep input/layout in CSS pixels and resize the GPU buffer through Godot only.
var viewport: JavaScriptObject
var revision := -1

func _ready() -> void:
	viewport = JavaScriptBridge.get_interface("window").annihilationViewport
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().disable_3d = true
	_sync_size()

func _process(_delta: float) -> void:
	_sync_size()

func _sync_size() -> void:
	if viewport == null or int(viewport.revision) == revision: return
	revision = int(viewport.revision)
	get_window().content_scale_size = Vector2i(int(viewport.width), int(viewport.height))
	get_window().size = Vector2i(int(viewport.renderWidth), int(viewport.renderHeight))
