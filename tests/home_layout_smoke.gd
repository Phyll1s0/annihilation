extends SceneTree
## Keep the title and start action readable from small windows through Retina/4K.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Background = preload("res://scripts/ui/void_background.gd")
const SIZES := [Vector2i(1280, 820), Vector2i(960, 680), Vector2i(1512, 982),
	Vector2i(1920, 1080), Vector2i(2560, 1600), Vector2i(3840, 2160),
	Vector2i(5120, 2880), Vector2i(2560, 1080), Vector2i(390, 844),
	Vector2i(320, 480), Vector2i(1280, 820)]
var failures := 0
var navigation := [""]

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for i in 3:
		await process_frame

func redraw(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		redraw(child)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var settings = Settings.new("user://home_layout_%d.cfg" % OS.get_process_id())
	settings.reduce_motion = true
	settings.apply_language()
	var background = Background.new()
	background.settings = settings
	viewport.add_child(background)
	var home = load("res://scenes/home_screen.tscn").instantiate()
	home.settings = settings
	home.progress = Progress.new("user://home_layout_%d.json" % OS.get_process_id())
	home.navigation_requested.connect(func(destination: String): navigation[0] = destination)
	viewport.add_child(home)
	await settle()
	var reference_title: int = home.title.get_theme_font_size("font_size")
	var reference_action: int = home.continue_button.get_theme_font_size("font_size")
	for dimensions in SIZES:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		var tag := "%dx%d" % [dimensions.x, dimensions.y]
		for control in [home.body, home.mark, home.title, home.continue_button, home.create_button, home.settings_button]:
			check(screen.encloses(control.get_global_rect()), tag + ": home controls fit the viewport")
		check(home.continue_button.size.y >= 44, tag + ": the start action has a usable hit target")
		check(not home.body.get_global_rect().intersects(home.settings_button.get_global_rect()), tag + ": settings do not overlap the title group")
		if dimensions.x >= 1920 and dimensions.y >= 1080:
			check(float(home.title.get_theme_font_size("font_size")) / dimensions.y >= float(reference_title) / 820.0 * 0.95,
				tag + ": the title keeps its visual proportion on large screens")
			check(float(home.continue_button.get_theme_font_size("font_size")) / dimensions.y >= float(reference_action) / 820.0 * 0.95,
				tag + ": the start label keeps its visual proportion on large screens")
		navigation[0] = ""
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = home.continue_button.get_global_rect().get_center()
			viewport.push_input(event, true)
		check(navigation[0] == "continue", tag + ": the resized start action accepts pointer input")
		if DisplayServer.get_name() != "headless" and dimensions in [SIZES[0], SIZES[3], SIZES[5]]:
			redraw(viewport)
			await process_frame
			RenderingServer.force_draw()
			viewport.get_texture().get_image().save_png("res://builds/home-layout-" + tag + ".png")
	check(home.title.get_theme_font_size("font_size") == reference_title and home.continue_button.get_theme_font_size("font_size") == reference_action,
		"Returning to the original window restores its original typography")
	viewport.queue_free()
	await settle()
	print("NULL home layout: %d resize cases, %d failures" % [SIZES.size(), failures])
	quit(1 if failures else 0)
