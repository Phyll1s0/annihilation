extends SceneTree
## Runs real Control input and renders screenshots. Uses an isolated save file.

const Progress = preload("res://scripts/progress.gd")
var ui
var failures := 0
var save_path := "user://ui_test_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)

func click_cell(index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = ui.board.global_position + ui.board.center_of(index)
	Input.parse_input_event(event)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = ui.board.global_position + ui.board.center_of(index)
	Input.parse_input_event(event)

func settle() -> void:
	await process_frame
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + name + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	var ignore := FileAccess.open("res://builds/.gdignore", FileAccess.WRITE)
	ignore.close()
	root.size = Vector2i(1280, 820)
	ui = load("res://scenes/main.tscn").instantiate()
	ui.progress = Progress.new(save_path)
	root.add_child(ui)
	await settle()
	check(ui.title_label.text == "初见", "First level loads")
	click_cell(0)
	await settle()
	check(ui.session.selected == 0, "Mouse hit testing selects a piece")
	key(KEY_RIGHT)
	await create_timer(0.42).timeout
	check(ui.session.cleared() and ui.result_panel.visible, "Keyboard movement displays completion after animation")
	check(ui.progress.records["01"].easy and not ui.progress.records["01"].hard, "Easy completion saves separately")
	key(KEY_Z)
	await settle()
	check(ui.session.steps == 0 and not ui.result_panel.visible, "Undo after completion hides result")
	key(KEY_RIGHT)
	await create_timer(0.08).timeout
	key(KEY_Z)
	await create_timer(0.42).timeout
	check(ui.session.steps == 0 and not ui.board.animating() and ui.session.state.pieces == [1, -1], "Undo during animation cannot apply a stale move")
	ui.level_buttons[1].pressed.emit()
	ui.hard_button.pressed.emit()
	await settle()
	click_cell(0)
	await settle()
	for code in [KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT]:
		key(code)
		await create_timer(0.38).timeout
	check(ui.session.steps == 5 and not ui.session.cleared(), "Hard mode rejects a longer solution")
	check(not ui.progress.records["02"].hard and ui.progress.records["02"].easy, "Long hard solution does not award a hard medal")
	await capture("hard-retry")
	key(KEY_R)
	await settle()
	click_cell(0)
	await settle()
	for code in [KEY_RIGHT, KEY_RIGHT, KEY_RIGHT]:
		key(code)
		await create_timer(0.38).timeout
	check(ui.session.cleared() and ui.progress.records["02"].hard, "Optimal hard solution saves a hard medal")
	ui.level_buttons[7].pressed.emit()
	await settle()
	click_cell(0)
	await settle()
	key(KEY_RIGHT)
	await create_timer(0.42).timeout
	check(ui.session.state.board[10] == -1 and ui.session.state.board[1] == 0, "Portal animation commits the correct rule state")
	key(KEY_Z)
	await settle()
	check(ui.session.state.board[10] == 1 and ui.session.state.board[1] == 1, "Portal undo restores both ends through the UI")
	ui.level_buttons[11].pressed.emit()
	ui.progress.records.clear()
	ui._sync()
	await settle()
	await capture("gray-1280")
	root.size = Vector2i(960, 680)
	await settle()
	check(ui.hard_button.get_global_rect().end.x <= root.size.x, "Mode controls fit the minimum window width")
	check(ui.board.size.y >= 220 and ui.board.get_global_rect().end.y < 680, "Board fits the minimum window height")
	await capture("gray-960")
	DirAccess.remove_absolute(save_path)
	print("GRAY UI smoke: %d failures; screenshots in builds/" % failures)
	quit(1 if failures else 0)
