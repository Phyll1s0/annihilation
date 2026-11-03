extends SceneTree
const Settings = preload("res://scripts/settings.gd")
const Background = preload("res://scripts/ui/void_background.gd")
const SIZES := [Vector2i(1280, 820), Vector2i(960, 680), Vector2i(1920, 1080),
	Vector2i(2940, 1846), Vector2i(3840, 2160), Vector2i(5120, 2880),
	Vector2i(960, 1280), Vector2i(960, 680), Vector2i(1280, 820)]
var failures := 0
var save_path := "user://settings_layout_%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for i in 3:
		await process_frame

func check_controls(node: Node, screen: Rect2, tag: String) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		check(screen.grow(1).encloses(node.get_global_rect()), tag + ": visible settings controls stay on screen")
	for child in node.get_children():
		check_controls(child, screen, tag)

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
	var settings = Settings.new(save_path)
	settings.reduce_motion = true
	settings.apply_language()
	var background = Background.new()
	background.settings = settings
	viewport.add_child(background)
	background.set_page("settings")
	var ui = load("res://scenes/settings_screen.tscn").instantiate()
	ui.settings = settings
	viewport.add_child(ui)
	await settle()
	var reference_font: int = ui.heading.get_theme_font_size("font_size")
	var reference_toggle: float = ui.toggle_on.get_width()
	for dimensions in SIZES:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for language in Settings.LANGUAGES:
			settings.language = language
			settings.apply_language()
			await settle()
			for page in ["general", "audio", "controls", "developer"]:
				if page == "developer": ui._developer_tab()
				elif page == "audio": ui._audio_tab()
				else: ui._tab(page == "controls")
				await settle()
				var tag := "%s %dx%d tab %s" % [language, dimensions.x, dimensions.y, page]
				check_controls(ui, screen, tag)
				check(ui.frame.size.distance_to(Vector2(dimensions)) < 1.0, tag + ": the settings frame restores its viewport size")
				if dimensions.x >= 1920 and dimensions.y >= 1080:
					check(float(ui.heading.get_theme_font_size("font_size")) / dimensions.y >= float(reference_font) / 820.0 * 0.95, tag + ": settings text grows with fullscreen")
					check(float(ui.toggle_on.get_width()) / dimensions.y >= reference_toggle / 820.0 * 0.95, tag + ": toggle artwork is redrawn for the larger size")
				check(ui.back_button.icon.get_width() >= ui.back_button.get_theme_constant("icon_max_width"), tag + ": navigation icons have enough source resolution")
				if DisplayServer.get_name() != "headless" and dimensions in [SIZES[0], SIZES[3]]:
					redraw(viewport)
					await process_frame
					RenderingServer.force_draw()
					viewport.get_texture().get_image().save_png("res://builds/settings-layout-%s-%dx%d-%s.png" % [language, dimensions.x, dimensions.y, page])
		ui._tab(false)
		await settle()
		var previous: bool = settings.show_hints
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = ui.switches.show_hints.get_global_rect().get_center()
			viewport.push_input(event, true)
		check(settings.show_hints != previous, "Resized settings toggles accept pointer input")
	check(ui.heading.get_theme_font_size("font_size") == reference_font, "Returning to a smaller window restores settings typography")
	settings.language = "en"
	settings.apply_language()
	viewport.queue_free()
	await settle()
	DirAccess.remove_absolute(save_path)
	print("ANNIHILATION settings layout: %d resize cases, both languages, %d failures" % [SIZES.size(), failures])
	quit(1 if failures else 0)
