extends SceneTree
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const SIZES := [Vector2i(1280, 820), Vector2i(960, 680), Vector2i(1920, 1080),
	Vector2i(2940, 1846), Vector2i(5120, 2880), Vector2i(2560, 1080),
	Vector2i(960, 1280), Vector2i(1280, 820)]
var failures := 0
var cases := 0
var save_path := "user://navigation_layout_%d.json" % OS.get_process_id()
var viewport: SubViewport
var app

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for i in 4:
		await process_frame

func check_controls(node: Node, screen: Rect2, tag: String) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		check(screen.grow(1).encloses(node.get_global_rect()), tag + ": controls stay on screen: " + node.name)
	for child in node.get_children():
		check_controls(child, screen, tag)

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.get_global_rect().get_center()
		viewport.push_input(event, true)

func redraw(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		redraw(child)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	redraw(viewport)
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png("res://builds/" + name_value + ".png")

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(save_path + ".cfg")
	app.settings.music_enabled = false
	app.settings.reduce_motion = true
	app.progress = Progress.new(save_path)
	viewport.add_child(app)
	app.show_screen("campaign")
	await settle()
	var reference_font: int = app.campaign.chapter_title.get_theme_font_size("font_size")
	var reference_card: float = app.campaign.cards[0].size.x
	for dimensions in SIZES:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for language in Settings.LANGUAGES:
			app.settings.language = language
			app.settings.apply_language()
			await settle()
			for chapter in app.campaign.chapter_names:
				app.campaign.chapter = chapter
				app.show_screen("campaign")
				await settle()
				cases += 1
				var tag := "%s %s %dx%d" % [language, chapter, dimensions.x, dimensions.y]
				check_controls(app.campaign, screen, tag)
				check(app.campaign.center.size.distance_to(Vector2(dimensions)) < 1.0, tag + ": chapter frame fits after resizing")
				for arrow in [app.campaign.previous_button, app.campaign.following_button]:
					check(not arrow.get_global_rect().intersects(app.campaign.grid.get_global_rect()), tag + ": arrows do not overlap level cards")
				if dimensions.x >= 1920 and dimensions.y >= 1080 and dimensions.x != 2560:
					check(float(app.campaign.chapter_title.get_theme_font_size("font_size")) / dimensions.y >= float(reference_font) / 820.0 * 0.95, tag + ": chapter typography grows with fullscreen")
					check(app.campaign.cards[0].size.x / dimensions.y >= reference_card / 820.0 * 0.95, tag + ": level cards grow with fullscreen")
				check(app.campaign.back_button.icon.get_width() >= app.campaign.back_button.get_theme_constant("icon_max_width"), tag + ": icons have enough source resolution")
			if dimensions in [SIZES[0], SIZES[1], SIZES[3]]:
				await capture("navigation-%s-%dx%d" % [language, dimensions.x, dimensions.y])
			click(app.campaign.previous_button)
			await settle()
			check(app.campaign.chapter == app.campaign.chapter_names[-2], "Resized chapter arrows accept pointer input")
			click(app.campaign.cards[0])
			await settle()
			check(app.screen == "game" and app.levels[app.game.current].chapter == app.campaign.chapter, "Resized level cards open the correct chapter's puzzle")
			app.start_level(1, false)
			app.game.session.selected = 0
			app.game._try_move("right")
			await settle()
			var state := Puzzle.key(app.game.session.state)
			check(app.game.session.steps == 1 and not app.game.session.cleared(), "Navigation test has a live, unfinished puzzle")
			app.pause_game()
			await settle()
			check_controls(app.pause_layer, screen, "pause " + str(dimensions))
			check(screen.encloses(app.pause_panel.get_global_rect()), "Pause panel stays inside the viewport")
			check(app.pause_center.size.distance_to(Vector2(dimensions)) < 1.0, "Pause frame restores its size after shrinking")
			if dimensions == SIZES[3]:
				await capture("pause-%s-%dx%d" % [language, dimensions.x, dimensions.y])
			click(app.pause_actions.settings)
			await settle()
			check(app.screen == "settings", "Resized pause settings button opens settings")
			click(app.preferences.back_button)
			await settle()
			check(app.screen == "game" and app.paused, "Returning from settings restores the pause menu")
			click(app.pause_actions.resume)
			await settle()
			check(not app.paused and app.game.input_enabled and Puzzle.key(app.game.session.state) == state and app.game.session.history.size() == 1, "Resuming preserves the board and undo history")
			app.pause_game()
			click(app.pause_actions.home)
			await settle()
			check(app.screen == "home", "Pause Home button opens the title screen")
			click(app.home.continue_button)
			await settle()
			check(app.screen == "campaign" and Puzzle.key(app.game.session.state) == state, "Start opens selection while preserving the saved puzzle")
			click(app.campaign.resume_button)
			await settle()
			check(app.screen == "game" and Puzzle.key(app.game.session.state) == state, "Continue in selection restores the exact state")
			app.pause_game()
			click(app.pause_actions.restart)
			await settle()
			check(not app.paused and app.game.session.steps == 0, "Resized Restart button resets the current run")
			app.pause_game()
			click(app.pause_actions.levels)
			await settle()
			check(app.screen == "campaign" and not app.paused, "Back to levels leaves the pause menu and opens chapter selection")
	check(app.campaign.chapter_title.get_theme_font_size("font_size") == reference_font, "Shrinking restores chapter typography")
	check(app.pause_actions.resume.get_theme_font_size("font_size") == 18, "Shrinking restores pause typography")
	app.settings.language = "en"
	app.settings.apply_language()
	viewport.queue_free()
	await settle()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".cfg")
	print("NULL navigation layout: %d chapter/language/resize cases, pause routes, %d failures" % [cases, failures])
	quit(1 if failures else 0)
