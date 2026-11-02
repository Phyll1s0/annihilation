extends SceneTree
## Exercise every authored board at real viewport dimensions, including live resizes.
const Progress = preload("res://scripts/progress.gd")
const Settings = preload("res://scripts/settings.gd")
const Background = preload("res://scripts/ui/void_background.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const SIZES := [Vector2i(1280, 820), Vector2i(960, 680), Vector2i(1280, 720),
	Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080),
	Vector2i(960, 1280), Vector2i(640, 480), Vector2i(390, 844),
	Vector2i(2560, 1640), Vector2i(2940, 1846), Vector2i(3840, 2160),
	Vector2i(5120, 2880), Vector2i(1280, 820)]
var failures := 0
var layouts := 0
var received := [-1]
var save_path := "user://layout_test_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var settings = Settings.new(save_path + ".cfg")
	settings.reduce_motion = true
	var background = Background.new()
	background.settings = settings
	viewport.add_child(background)
	background.set_page("game")
	var ui = load("res://scenes/game_screen.tscn").instantiate()
	ui.settings = settings
	ui.progress = Progress.new(save_path)
	viewport.add_child(ui)
	ui.board.cell_pressed.connect(func(index: int): received[0] = index)
	await settle()
	var reference_units: Dictionary = {}
	var reference_counter: int = ui.count_label.get_theme_font_size("font_size")
	var reference_back_size: Vector2 = ui.back_button.size
	for dimensions in SIZES:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		if dimensions == SIZES[0]:
			check(ui.back_button.size.distance_to(reference_back_size) < 1.0, "Returning to a smaller window restores the control hit targets")
		for level_index in ui.levels.size():
			ui._open_level(level_index, false)
			await settle()
			layouts += 1
			var tag := "%s at %dx%d" % [ui.levels[level_index].id, dimensions.x, dimensions.y]
			var board = ui.board
			if dimensions == SIZES[0] and not reference_units.has(level_index):
				reference_units[level_index] = board.unit
			if dimensions.x >= 1920 and dimensions.y >= 1080:
				check(board.unit / dimensions.y >= float(reference_units[level_index]) / 820.0 * 0.95,
					tag + ": the actual level grows with the screen instead of hitting a fixed cell cap")
				check(float(ui.count_label.get_theme_font_size("font_size")) / dimensions.y >= float(reference_counter) / 820.0 * 0.95,
					tag + ": gameplay text remains proportional on large screens")
			if dimensions == SIZES[0]:
				check(absf(board.unit - float(reference_units[level_index])) < 1.0, tag + ": returning to a smaller window restores the original board scale")
			var grid := Rect2(board.global_position + board.origin, Vector2(board.state.width, board.state.height) * board.unit)
			check(screen.encloses(grid), tag + ": the complete grid fits the viewport")
			check(board.get_global_rect().encloses(grid), tag + ": tiles are not clipped by the board")
			check(grid.position.y >= ui.toolbar.get_global_rect().end.y + 4, tag + ": the grid clears the toolbar (grid %.1f, toolbar %s, counter font %d)" % [grid.position.y, ui.toolbar.get_global_rect(), ui.count_label.get_theme_font_size("font_size")])
			check(grid.end.y <= ui.status_label.position.y - 8, tag + ": feedback has separate space")
			check(grid.get_center().distance_to(screen.get_center()) < 1.0, tag + ": the puzzle stays centered")
			check(board.unit >= 28.0, tag + ": cells stay usable at the smallest test viewport")
			for control in [ui.back_button, ui.pause_button, ui.easy_button, ui.hard_button, ui.toolbar]:
				check(screen.encloses(control.get_global_rect()), tag + ": controls fit on screen")
			check(not ui.modes.get_global_rect().intersects(ui.toolbar.get_global_rect()), tag + ": difficulty and toolbar do not overlap")
			check(ui.status_label.text.is_empty(), tag + ": gameplay starts without a text footer")
			for cell in board.state.board.size():
				if board.state.board[cell] >= 0:
					check(board._cell_at(board.center_of(cell)) == cell, tag + ": tile positions match hit testing")
			var source: int = ui.levels[level_index].solution[0].source
			received[0] = -1
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				event.position = board.global_position + board.center_of(source)
				viewport.push_input(event, true)
			check(received[0] == source and ui.session.selected == source, tag + ": pointer input reaches the displayed particle")
			if DisplayServer.get_name() != "headless" and (dimensions in [SIZES[0], SIZES[1]] or level_index == 11):
				var directory := "res://builds/layouts/%dx%d" % [dimensions.x, dimensions.y]
				DirAccess.make_dir_recursive_absolute(directory)
				await process_frame
				RenderingServer.force_draw()
				viewport.get_texture().get_image().save_png(directory + "/%s.png" % ui.levels[level_index].id)
		# A result can be wider than a small board, so check it separately after resize.
		ui._open_level(0, false)
		ui.session.selected = 0
		ui._try_move("right")
		await settle()
		check(ui.result_panel.visible and screen.encloses(ui.result_panel.get_global_rect()), "%dx%d: completion controls remain on screen" % [dimensions.x, dimensions.y])
	# Resizing an active, animated puzzle must preserve its rules and history.
	ui._open_level(11, false)
	var initial := Puzzle.key(ui.session.state)
	settings.reduce_motion = false
	ui.apply_settings()
	var action: Dictionary = ui.levels[11].solution[0]
	ui.session.selected = int(action.source)
	ui._try_move(action.direction)
	var moved := Puzzle.key(ui.session.state)
	var selection: int = ui.session.selected
	viewport.size = Vector2i(2560, 1640)
	await settle()
	check(Puzzle.key(ui.session.state) == moved and ui.session.steps == 1 and ui.session.selected == selection,
		"Resizing a live puzzle preserves particles, terrain, selection, and steps")
	check(ui.session.history.size() == 1, "Resizing an animated puzzle preserves undo history")
	ui._undo()
	check(Puzzle.key(ui.session.state) == initial and ui.session.steps == 0, "Undo after a resize restores the original puzzle")
	viewport.size = SIZES[0]
	await settle()
	check(absf(ui.board.unit - float(reference_units[11])) < 1.0, "Shrinking an active puzzle restores its original scale")
	settings.reduce_motion = true
	ui.apply_settings()
	ui._show_notice("Cannot move")
	await create_timer(1.5).timeout
	check(ui.status_label.text.is_empty(), "Brief feedback clears itself")
	viewport.queue_free()
	await settle()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".cfg")
	print("NULL layout: %d puzzle/window combinations, %d failures" % [layouts, failures])
	quit(1 if failures else 0)
