extends SceneTree
## Exercise imprecise taps and gestures rather than only exact cell-center clicks.
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
var viewport: SubViewport
var app
var checks := 0
var failures := 0
var directory := "user://touch_controls_%d" % OS.get_process_id()
var finger_id := 41

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 5: await process_frame

func point(index: int) -> Vector2:
	return app.game.board.global_position + app.game.board.center_of(index)

func finger(at: Vector2, pressed: bool, canceled := false, index := -1) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	event.index = finger_id if index < 0 else index
	viewport.push_input(event, true)
	if not pressed and index < 0: finger_id += 1

func tap(at: Vector2, drift := Vector2.ZERO) -> void:
	finger(at, true)
	finger(at + drift, false)

func drag(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger_id
	event.position = to
	event.relative = to - from
	viewport.push_input(event, true)

func swipe(from: Vector2, offset: Vector2) -> void:
	finger(from, true)
	drag(from, from + offset)
	finger(from + offset, false)

func mouse(at: Vector2, emulated := false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
		viewport.push_input(event, true)

func remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for name_value in dir.get_files(): DirAccess.remove_absolute(path.path_join(name_value))
	for name_value in dir.get_directories(): remove_tree(path.path_join(name_value))
	DirAccess.remove_absolute(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(390, 664)
	root.add_child(viewport)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.reduce_motion = true
	app.settings.music_enabled = false
	app.settings.developer_mode = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	viewport.add_child(app)
	for dimensions in [Vector2i(390, 664), Vector2i(844, 300), Vector2i(320, 568)]:
		viewport.size = dimensions
		app.start_level(1, false)
		await settle()
		var tag := "%dx%d: " % [dimensions.x, dimensions.y]
		var unit: float = app.game.board.unit
		tap(point(0) - Vector2(unit / 2 + 7, 0))
		check(app.game.session.selected == 0, tag + "a slightly missed particle tap still selects")
		tap(point(0))
		tap(point(0))
		check(app.game.session.selected == 0, tag + "repeated touches keep the selection")
		var before := Puzzle.key(app.game.session.state)
		tap(point(0), Vector2(10, 8))
		check(app.game.session.selected == 0 and Puzzle.key(app.game.session.state) == before, tag + "finger jitter does not cancel selection or move")
		tap(Vector2(dimensions.x / 2, 4))
		check(app.game.session.selected == -1, tag + "an intentional tap far from the grid deselects")
		finger(point(0), true)
		check(app.game.session.selected == -1, tag + "a touch waits for release before acting")
		finger(point(0), false, true)
		check(app.game.session.selected == -1 and app.game.session.steps == 0, tag + "a canceled touch does nothing")
		swipe(point(0), Vector2(70, 4))
		check(app.game.session.steps == 1 and app.game.session.selected == 1, tag + "one swipe selects and moves exactly one tile")
		mouse(point(1), true)
		check(app.game.session.selected == 1, tag + "emulated mouse does not toggle touch selection")
		swipe(app.game.board.global_position + Vector2(4, app.game.board.size.y - 4), Vector2(70, 0))
		check(app.game.session.steps == 2 and app.game.session.selected == 2, tag + "a selected particle can move by swiping open board space")
		app.start_level(1, false)
		await settle()
		tap(point(0))
		swipe(point(0), Vector2(60, 58))
		check(app.game.session.steps == 0 and app.game.session.selected == 0, tag + "an ambiguous diagonal does not make an accidental move")
		finger(point(0), true)
		app.pause_game()
		finger(point(0) + Vector2(70, 0), false)
		app.resume_game()
		check(app.game.session.steps == 0, tag + "pausing cancels a pending gesture")
		finger(point(0), true)
		app.game._restart()
		finger(point(0) + Vector2(70, 0), false)
		check(app.game.session.steps == 0 and app.game.session.selected == -1, tag + "restart discards an old finger-down event")
		app.settings.keyboard_only_movement = true
		swipe(point(0), Vector2(70, 0))
		check(app.game.session.steps == 1, tag + "keyboard-only mouse preferences still allow touch swipes")
		app.settings.keyboard_only_movement = false
		app.start_level(0, false)
		await settle()
		tap(point(0))
		tap(point(1) + Vector2(app.game.board.unit / 2 + 7, 0))
		check(app.game.session.cleared() and app.game.session.steps == 1, tag + "an imprecise edge tap can reach the intended neighboring tile")
		app.start_level(5, false)
		await settle()
		tap(point(0))
		tap(point(6))
		check(app.game.session.selected == 0 and app.game.session.steps == 0, tag + "a hole does not clear touch selection")
		mouse(point(6))
		check(app.game.session.selected == -1, tag + "mouse clicks on holes retain their existing behavior")
		app.start_level(1, false)
		await settle()
		swipe(point(0), Vector2(500, 0))
		check(app.game.session.steps == 1, tag + "a swipe released beyond the board is still handled once")
	app.start_level(1, false)
	await settle()
	app.game.board.reduce_motion = false
	swipe(point(0), Vector2(70, 0))
	swipe(app.game.board.global_position + Vector2.ONE * 4, Vector2(70, 0))
	await create_timer(0.8).timeout
	check(app.game.session.steps == 2 and app.game.session.selected == 2, "A quick second gesture is buffered until the movement animation ends")
	app.start_level(1, false)
	await settle()
	app.game.board.reduce_motion = false
	swipe(point(0), Vector2(70, 0))
	swipe(app.game.board.global_position + Vector2.ONE * 4, Vector2(70, 0))
	app.game._undo()
	await create_timer(0.5).timeout
	check(app.game.session.steps == 0 and app.game.pending_touch.is_empty(), "Undo cancels queued touch movement")
	app.start_level(1, false)
	await settle()
	app.game.board.reduce_motion = false
	swipe(point(0), Vector2(70, 0))
	swipe(app.game.board.global_position + Vector2.ONE * 4, Vector2(70, 0))
	app.pause_game()
	await create_timer(0.5).timeout
	app.resume_game()
	check(app.game.session.steps == 1 and app.game.pending_touch.is_empty(), "Pause cancels queued touch movement")
	app._navigate("create_level")
	await settle()
	app.editor._brush("white")
	var board = app.editor.board
	var first: Vector2 = board.global_position + board.center_of(0)
	var second: Vector2 = board.global_position + board.center_of(1)
	var third: Vector2 = board.global_position + board.center_of(2)
	finger(first, true)
	finger(third, true, false, finger_id + 100)
	finger(third, false, false, finger_id + 100)
	drag(first, second)
	finger(second, false)
	check(app.editor.model.pieces[0] == 1 and app.editor.model.pieces[1] == 1 and app.editor.model.pieces[2] == 0, "Editor painting tracks arbitrary primary IDs and ignores secondary fingers")
	check(app.editor.model.history.size() == 1, "A nonzero-ID painting gesture remains one undoable stroke")
	app.editor._brush("black")
	mouse(first, true)
	check(app.editor.model.pieces[0] == 1, "Editor emulated mouse events do not repaint the touch stroke")
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION touch controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
