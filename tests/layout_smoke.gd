extends SceneTree
## Exercise every authored board at real viewport dimensions, including live resizes.
const Progress = preload("res://scripts/progress.gd")
const Settings = preload("res://scripts/settings.gd")
const Background = preload("res://scripts/ui/void_background.gd")
const SIZES := [Vector2i(1280, 820), Vector2i(960, 680), Vector2i(1280, 720),
	Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080),
	Vector2i(960, 1280), Vector2i(640, 480), Vector2i(390, 844)]
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
	for dimensions in SIZES:
		viewport.size = dimensions
		await settle()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for level_index in ui.levels.size():
			ui._open_level(level_index, false)
			await settle()
			layouts += 1
			var tag := "%s at %dx%d" % [ui.levels[level_index].id, dimensions.x, dimensions.y]
			var board = ui.board
			var grid := Rect2(board.global_position + board.origin, Vector2(board.state.width, board.state.height) * board.unit)
			check(screen.encloses(grid), tag + ": the complete grid fits the viewport")
			check(board.get_global_rect().encloses(grid), tag + ": tiles are not clipped by the board")
			check(grid.position.y >= ui.toolbar.get_global_rect().end.y + 4, tag + ": the grid clears the toolbar")
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
	ui._show_notice("Cannot move")
	await create_timer(1.5).timeout
	check(ui.status_label.text.is_empty(), "Brief feedback clears itself")
	viewport.queue_free()
	await settle()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".cfg")
	print("NULL layout: %d puzzle/window combinations, %d failures" % [layouts, failures])
	quit(1 if failures else 0)
