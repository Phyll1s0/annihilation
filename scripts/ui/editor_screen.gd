extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal playtest_requested(level: Dictionary, certified: bool)
const Model = preload("res://scripts/editor_model.gd")
const Library = preload("res://scripts/editor_library.gd")
const Solver = preload("res://scripts/editor_solver.gd")
const Board = preload("res://scripts/board_view.gd")
var directory := "user://editor"
var levels: Array = []
var model
var library
var board
var job
var job_revision := -1
var job_model
var brush := "floor"
var group := 1
var frame: MarginContainer
var body: HBoxContainer
var sidebar: VBoxContainer
var title_input: LineEdit
var level_menu: OptionButton
var width_input: SpinBox
var height_input: SpinBox
var portal_menu: OptionButton
var portal_count: Label
var brushes := {}
var undo_button: Button
var redo_button: Button
var play_button: Button
var verify_button: Button
var status: Label
var statistics: Label
var verification: Label
var autosave: Timer
var exchange_layer: Control
var exchange_panel: PanelContainer
var exchange_text: TextEdit
var exchange_status: Label
var file_dialog: FileDialog
var file_action := ""
var web_callback

func _ready() -> void:
	_setup_theme()
	theme.set_stylebox("normal", "LineEdit", _style(Color(1, 1, 1, 0.025), LINE))
	theme.set_stylebox("focus", "LineEdit", _style(Color("080808"), Color(1, 1, 1, 0.4)))
	theme.set_stylebox("normal", "TextEdit", _style(Color("080808"), LINE))
	library = Library.new(directory)
	model = library.load_draft()
	_build_ui()
	autosave = Timer.new()
	autosave.one_shot = true
	autosave.wait_time = 0.4
	autosave.timeout.connect(_persist)
	add_child(autosave)
	_remember_layout(frame)
	_remember_layout(exchange_panel)
	frame.minimum_size_changed.connect(_fit_frame)
	resized.connect(_layout_editor)
	_layout_editor()
	_refresh_menu()
	_sync()

func _build_ui() -> void:
	frame = _margin(self, 24)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	frame.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	header.add_child(_icon_button("arrow-back-circle-outline", "Back", func():
		_persist(); navigation_requested.emit("editor_back"), 32))
	header.add_child(_title("Level editor", 28, 1))
	_spacer(header)
	undo_button = _icon_button("arrow-undo-outline", "Undo · Ctrl/Cmd Z", func(): model.undo(); _edited(), 24)
	header.add_child(undo_button)
	redo_button = _button("Redo", func(): model.redo(); _edited(), Vector2(72, 42))
	header.add_child(redo_button)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	outer.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 260
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 12)
	scroll.add_child(sidebar)
	title_input = LineEdit.new()
	title_input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_input.placeholder_text = tr("Level name")
	title_input.max_length = 64
	title_input.custom_minimum_size.y = 38
	title_input.text_submitted.connect(func(value: String): model.rename(value); _edited())
	title_input.focus_exited.connect(func(): model.rename(title_input.text); _edited())
	sidebar.add_child(title_input)
	var open_row := HBoxContainer.new()
	sidebar.add_child(open_row)
	level_menu = OptionButton.new()
	level_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	level_menu.custom_minimum_size = Vector2(190, 36)
	level_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_menu.fit_to_longest_item = false
	level_menu.item_selected.connect(_open_selection)
	open_row.add_child(level_menu)
	open_row.add_child(_button("New", _new_level, Vector2(58, 36)))
	var dimensions := HBoxContainer.new()
	sidebar.add_child(dimensions)
	width_input = _dimension(dimensions)
	dimensions.add_child(_label("×", 16, MUTED))
	height_input = _dimension(dimensions)
	dimensions.add_child(_button("Resize", func():
		model.resize_grid(int(width_input.value), int(height_input.value)); _edited(), Vector2(76, 36)))
	sidebar.add_child(_label("Brush", 12, MUTED))
	var tools := GridContainer.new()
	tools.columns = 3
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	sidebar.add_child(tools)
	for entry in [["floor", "Floor"], ["void", "Void"], ["white", "White"], ["black", "Black"], ["clear", "Clear"], ["portal", "Portal"]]:
		var name_value: String = entry[0]
		var button := _button(entry[1], func(): _brush(name_value), Vector2(80, 36))
		button.add_theme_font_size_override("font_size", 12)
		tools.add_child(button)
		brushes[name_value] = button
	var portal_row := HBoxContainer.new()
	sidebar.add_child(portal_row)
	portal_menu = OptionButton.new()
	portal_menu.custom_minimum_size = Vector2(92, 36)
	for i in 26: portal_menu.add_item(String.chr(65 + i))
	portal_menu.item_selected.connect(func(index: int): group = index + 1; _brush("portal"))
	portal_row.add_child(portal_menu)
	portal_count = _label("", 12, MUTED)
	portal_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portal_row.add_child(portal_count)
	var actions := HBoxContainer.new()
	sidebar.add_child(actions)
	play_button = _button("Playtest", _playtest, Vector2(122, 44))
	verify_button = _button("Find minimum", _verify, Vector2(122, 44))
	for button in [play_button, verify_button]:
		button.add_theme_font_size_override("font_size", 12)
		actions.add_child(button)
	var files := HBoxContainer.new()
	sidebar.add_child(files)
	for entry in [["Save", _save], ["Import", func(): _exchange(false)], ["Export", func(): _exchange(true)]]:
		var button := _button(entry[0], entry[1], Vector2(80, 36))
		button.add_theme_font_size_override("font_size", 12)
		files.add_child(button)
	verification = _label("", 12, MUTED)
	verification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(verification)
	status = _label("Drag to paint. Right click to erase.", 12, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var drawing := VBoxContainer.new()
	drawing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(drawing)
	board = Board.new()
	board.font = regular
	board.edit_mode = true
	board.reduce_motion = true
	board.show_hints = false
	board.focus_mode = Control.FOCUS_ALL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.paint_started.connect(func(): board.grab_focus(); model.begin_edit())
	board.paint_finished.connect(func(): model.commit_edit(); _sync())
	board.cell_painted.connect(_paint)
	drawing.add_child(board)
	statistics = _label("", 12, MUTED)
	statistics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawing.add_child(statistics)
	drawing.add_child(status)
	_build_exchange()

func _dimension(parent: Node) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = 1
	input.max_value = Model.MAX_SIZE
	input.custom_minimum_size = Vector2(72, 36)
	parent.add_child(input)
	return input

func _layout_editor() -> void:
	if frame == null: return
	var factor := _screen_scale()
	_apply_layout(frame, factor)
	_apply_layout(exchange_panel, factor)
	theme.default_font_size = roundi(14 * factor)
	for selector in [level_menu, portal_menu]:
		var popup: PopupMenu = selector.get_popup()
		popup.max_size = Vector2i(0, roundi(size.y * 0.7))
		popup.add_theme_font_size_override("font_size", roundi(14 * factor))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.maximum_unit = 100 * factor
	board.visual_scale = factor
	board.padding = Vector2(16, 16) * factor
	board.queue_redraw()
	exchange_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := 44.0 * factor
	exchange_panel.offset_left = margin
	exchange_panel.offset_top = margin
	exchange_panel.offset_right = -margin
	exchange_panel.offset_bottom = -margin

func _fit_frame() -> void:
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _brush(value: String) -> void:
	brush = value
	_sync()

func _paint(cell: int, erase: bool) -> void:
	model.begin_edit()
	if model.paint(cell, "void" if erase else brush, group):
		_edited()
	elif not model.last_error.is_empty(): _status(model.last_error)

func _edited() -> void:
	if job != null and model.revision != job_revision: job.cancel()
	if model.dirty: _status("Drag to paint. Right click to erase.")
	_sync()
	if is_instance_valid(autosave) and autosave.is_inside_tree(): autosave.start()

func _sync() -> void:
	if not is_instance_valid(board) or not board.is_inside_tree(): return
	board.present(model.state(), -1)
	if not title_input.has_focus(): title_input.text = model.title
	width_input.set_value_no_signal(model.width)
	height_input.set_value_no_signal(model.height)
	undo_button.disabled = model.history.is_empty() and model.before.is_empty()
	redo_button.disabled = model.future.is_empty()
	for key in brushes: _accent(brushes[key], key == brush)
	var tint: Color = board._portal_color(group)
	portal_menu.add_theme_color_override("font_color", tint)
	portal_count.add_theme_color_override("font_color", tint)
	portal_count.text = tr("%d / 2 ends") % model.board.count(group)
	statistics.text = tr("White %d · Black %d · Portal ends %d") % [model.pieces.count(1), model.pieces.count(-1), model.board.filter(func(tag): return tag > 0).size()]
	verification.text = tr("Minimum not verified") if model.certificate.is_empty() else tr("Verified minimum: %d") % model.certificate.optimal_moves
	verify_button.text = tr("Cancel") if job != null else tr("Find minimum")

func _status(message: String) -> void:
	if not is_instance_valid(status): return
	status.text = tr(message)
	if is_instance_valid(exchange_layer) and exchange_layer.visible and is_instance_valid(exchange_status): exchange_status.text = tr(message)

func _persist() -> void:
	model.rename(title_input.text)
	if library.save_draft(model) != OK: _status("Could not save the draft.")

func _stash() -> bool:
	model.rename(title_input.text)
	model.commit_edit()
	if model.dirty and library.archive_draft(model) != OK:
		_status("Could not save the current draft.")
		return false
	return true

func _replace(next_model, unsaved: bool = true) -> void:
	if job != null: job.cancel()
	title_input.release_focus()
	model = next_model
	model.dirty = unsaved
	_status("Drag to paint. Right click to erase.")
	_sync()
	_persist()
	_refresh_menu()

func _new_level() -> void:
	if _stash(): _replace(Model.new(), false)

func _save() -> void:
	model.rename(title_input.text)
	model.commit_edit()
	if library.save_level(model) != OK:
		_status("Could not save the level.")
		return
	_persist()
	model.dirty = false
	_refresh_menu()
	_status("Level saved.")

func _refresh_menu() -> void:
	level_menu.clear()
	level_menu.add_item(tr("Open a level…"))
	level_menu.add_separator(tr("My levels"))
	for item in library.list_levels():
		level_menu.add_item(item.title)
		level_menu.set_item_metadata(level_menu.item_count - 1, {"path": item.path})
	level_menu.add_separator(tr("Campaign"))
	for index in levels.size():
		level_menu.add_item("%s · %s" % [levels[index].id, tr(levels[index].title)])
		level_menu.set_item_metadata(level_menu.item_count - 1, {"index": index})
	level_menu.select(0)

func _open_selection(index: int) -> void:
	var item = level_menu.get_item_metadata(index)
	if not item is Dictionary: return
	if not _stash(): return
	var parsed: Dictionary
	if item.has("path"):
		parsed = library.load_file(item.path, true, false)
	else:
		parsed = Model.parse(levels[int(item.index)], true, true)
	if parsed.has("model"): _replace(parsed.model, not item.has("path"))
	else: _status(parsed.error)

func _playtest() -> void:
	model.rename(title_input.text)
	model.commit_edit()
	var error: String = model.validation_error()
	if not error.is_empty(): _status(error); return
	if job != null: job.cancel()
	_persist()
	playtest_requested.emit(model.definition(), not model.certificate.is_empty())

func _verify() -> void:
	if job != null:
		job.cancel()
		return
	model.rename(title_input.text)
	model.commit_edit()
	var error: String = model.validation_error()
	if not error.is_empty(): _status(error); return
	job = Solver.new()
	job_revision = model.revision
	job_model = model
	if job.start(model.state()) != OK:
		job = null
		_status("Could not start verification.")
	_sync()

func _process(_delta: float) -> void:
	if job == null: return
	var result: Dictionary = job.poll()
	if result.is_empty():
		verification.text = tr("Searching… %d states") % job.count()
		return
	job = null
	if job_model == model and job_revision == model.revision:
		match result.status:
			"solved":
				if model.accept_solution(result): _persist(); _status("Minimum verified.")
				else: _status("Could not verify the minimum.")
			"unsolvable": _status("No solution. Try changing the map.")
			"limit": _status("Search limit reached. Easy playtest is still available.")
			_: _status("Verification cancelled.")
	_sync()

func _build_exchange() -> void:
	exchange_layer = Control.new()
	exchange_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(exchange_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exchange_layer.add_child(shade)
	exchange_panel = PanelContainer.new()
	exchange_panel.add_theme_stylebox_override("panel", _style(Color("080808"), LINE, 4))
	exchange_layer.add_child(exchange_panel)
	var contents := VBoxContainer.new()
	exchange_panel.add_child(contents)
	contents.add_child(_title("Level JSON", 24, 1))
	exchange_text = TextEdit.new()
	exchange_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	exchange_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exchange_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	contents.add_child(exchange_text)
	exchange_status = _label("", 12, MUTED)
	exchange_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(exchange_status)
	var actions := HBoxContainer.new()
	contents.add_child(actions)
	for entry in [["Import JSON", func(): import_text(exchange_text.text)], ["Copy JSON", func(): DisplayServer.clipboard_set(exchange_text.text)],
		["Open file", _open_file], ["Save file", _export_file], ["Close", func(): exchange_layer.hide()]]:
		var button := _button(entry[0], entry[1], Vector2(100, 40))
		button.add_theme_font_size_override("font_size", 12)
		actions.add_child(button)
	exchange_layer.hide()
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.json ; NULL level"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)

func _exchange(exporting: bool) -> void:
	model.rename(title_input.text)
	exchange_status.text = ""
	exchange_text.text = JSON.stringify(model.document(), "\t") if exporting else ""
	exchange_layer.show()
	exchange_text.grab_focus()

func import_text(text: String) -> bool:
	if text.length() > 1000000: _status("The level file is too large."); return false
	var json := JSON.new()
	if json.parse(text) != OK: _status("The file is not valid JSON."); return false
	var parsed := Model.parse(json.data)
	if not parsed.has("model"): _status(parsed.error); return false
	if not _stash(): return false
	_replace(parsed.model)
	exchange_layer.hide()
	_status("Level imported. Verify its minimum to enable Hard.")
	return true

func _open_file() -> void:
	if OS.has_feature("web"):
		web_callback = JavaScriptBridge.create_callback(_web_import)
		var window = JavaScriptBridge.get_interface("window")
		window.nullLevelImport = web_callback
		JavaScriptBridge.eval("(()=>{const f=document.createElement('input');f.type='file';f.accept='.json,application/json';f.onchange=()=>{if(!f.files[0])return;if(f.files[0].size>1000000){window.nullLevelImport(null);return;}f.files[0].text().then(t=>window.nullLevelImport(t)).catch(()=>window.nullLevelImport(null));};f.click();})()", true)
		return
	file_action = "import"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered(Vector2i(760, 480))

func _web_import(arguments: Array) -> void:
	if arguments.is_empty() or arguments[0] == null: _status("Could not open the level file.")
	else: import_text(str(arguments[0]))

func _export_file() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(exchange_text.text.to_utf8_buffer(), "NULL-level.json", "application/json")
		return
	file_action = "export"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_file = "NULL-level.json"
	file_dialog.popup_centered(Vector2i(760, 480))

func _file_selected(path: String) -> void:
	if file_action == "import":
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 1000000: _status("Could not open the level file."); return
		import_text(file.get_as_text())
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null: _status("Could not save the level."); return
		file.store_string(exchange_text.text)
		file.flush()
		var error := file.get_error()
		file.close()
		if error != OK: _status("Could not save the level."); return
		_status("Level exported.")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if exchange_layer.visible:
		if event.physical_keycode == KEY_ESCAPE: exchange_layer.hide(); get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.physical_keycode == KEY_F5:
		_playtest()
	elif event.ctrl_pressed or event.meta_pressed:
		match event.physical_keycode:
			KEY_S: _save()
			KEY_Z:
				if event.shift_pressed: model.redo()
				else: model.undo()
				_edited()
			_: return
	else: return
	get_viewport().set_input_as_handled()

func _refresh_language() -> void:
	if board == null: return
	title_input.placeholder_text = tr("Level name")
	_refresh_menu()
	_sync()

func _exit_tree() -> void:
	if job != null: job.shutdown()
	if library != null and model != null:
		if is_instance_valid(title_input): model.rename(title_input.text)
		model.commit_edit()
		library.save_draft(model)
