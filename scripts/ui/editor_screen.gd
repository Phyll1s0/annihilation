extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal playtest_requested(level: Dictionary)
const Model = preload("res://scripts/editor_model.gd")
const Library = preload("res://scripts/editor_library.gd")
const Records = preload("res://scripts/custom_records.gd")
const Board = preload("res://scripts/board_view.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const DirectionGlyph = preload("res://scripts/ui/direction_glyph.gd")
var directory := "user://editor"
var levels: Array = []
var model
var library
var board
var records
var records_layer
var records_panel: PanelContainer
var records_table: VBoxContainer
var player_input: LineEdit
var records_heading: Label
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
var field_button: Button
var field_directions: HBoxContainer
var last_field_direction := "right"
var map_button: Button
var map_properties: VBoxContainer
var portal_row: HBoxContainer
var undo_button: Button
var redo_button: Button
var new_button: Button
var save_button: Button
var play_button: Button
var records_button: Button
var status: Label
var statistics: Label
var best_label: Label
var autosave: Timer
var exchange_layer: Control
var exchange_panel: PanelContainer
var exchange_text: TextEdit
var exchange_status: Label
var exchange_actions: GridContainer
var file_dialog: FileDialog
var file_action := ""
var web_callback
var header: HBoxContainer
var editor_title: Label
var sidebar_shell: VBoxContainer
var drawing: VBoxContainer
var mobile_tools: Button
var mobile_redo: Button
var tools_open := false

func _ready() -> void:
	_setup_theme()
	theme.default_font_size = 16
	theme.set_stylebox("normal", "LineEdit", _style(Color(1, 1, 1, 0.025), LINE))
	theme.set_stylebox("focus", "LineEdit", _style(Color("080808"), Color(1, 1, 1, 0.4)))
	theme.set_stylebox("normal", "TextEdit", _style(Color("080808"), LINE))
	if library == null: library = Library.new(directory)
	if records == null: records = Records.new(directory)
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
	header = HBoxContainer.new()
	outer.add_child(header)
	header.add_child(_icon_button("arrow-back-circle-outline", "Back", func():
		_persist(); navigation_requested.emit("editor_back"), 32))
	editor_title = _title("Level editor", 28, 1)
	header.add_child(editor_title)
	_spacer(header)
	new_button = _button("New", _new_level, Vector2(88, 44))
	header.add_child(new_button)
	save_button = _button("Save", _save, Vector2(88, 44))
	save_button.tooltip_text = "Ctrl/Cmd S"
	header.add_child(save_button)
	undo_button = _icon_button("arrow-undo-outline", "Undo · Ctrl/Cmd Z", func(): model.undo(); _edited(), 24)
	header.add_child(undo_button)
	redo_button = _button("Redo", func(): model.redo(); _edited(), Vector2(72, 42))
	header.add_child(redo_button)
	mobile_tools = _button("Tools", func(): tools_open = not tools_open; _layout_editor(), Vector2(68, 44))
	header.add_child(mobile_tools)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	outer.add_child(body)
	sidebar_shell = VBoxContainer.new()
	sidebar_shell.custom_minimum_size.x = 320
	sidebar_shell.add_theme_constant_override("separation", 14)
	body.add_child(sidebar_shell)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_shell.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	scroll.add_child(sidebar)
	title_input = LineEdit.new()
	title_input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_input.placeholder_text = tr("Level name")
	title_input.max_length = 64
	title_input.custom_minimum_size.y = 44
	title_input.text_submitted.connect(func(value: String): model.rename(value); _edited())
	title_input.focus_exited.connect(func(): model.rename(title_input.text); _edited())
	sidebar.add_child(title_input)
	map_button = _button("Map settings", func():
		map_properties.visible = not map_properties.visible
		_accent(map_button, map_properties.visible), Vector2(0, 40))
	map_button.add_theme_font_size_override("font_size", 14)
	sidebar.add_child(map_button)
	map_properties = VBoxContainer.new()
	map_properties.hide()
	sidebar.add_child(map_properties)
	var open_row := HBoxContainer.new()
	map_properties.add_child(open_row)
	level_menu = OptionButton.new()
	level_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	level_menu.custom_minimum_size = Vector2(190, 44)
	level_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_menu.fit_to_longest_item = false
	level_menu.item_selected.connect(_open_selection)
	open_row.add_child(level_menu)
	var dimensions := HBoxContainer.new()
	map_properties.add_child(dimensions)
	width_input = _dimension(dimensions)
	dimensions.add_child(_label("×", 16, MUTED))
	height_input = _dimension(dimensions)
	dimensions.add_child(_button("Resize", func():
		model.resize_grid(int(width_input.value), int(height_input.value)); _edited(), Vector2(88, 44)))
	sidebar.add_child(_label("Brush", 14, MUTED))
	var tools := GridContainer.new()
	tools.columns = 3
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	sidebar.add_child(tools)
	for entry in [["floor", "Floor"], ["void", "Void"], ["white", "White"], ["black", "Black"], ["clear", "Erase piece"], ["portal", "Portal"]]:
		var name_value: String = entry[0]
		var button := _button(entry[1], func(): _brush(name_value), Vector2(96, 48))
		button.add_theme_font_size_override("font_size", 14)
		tools.add_child(button)
		brushes[name_value] = button
		var hint: String = {"floor": "Place a floor; keep the particle.", "void": "Remove the tile and its particle. Right click also does this.",
			"white": "Place a white particle.", "black": "Place a black particle.", "clear": "Remove only the particle; keep the floor or portal.",
			"portal": "Place one end of the selected portal group."}[name_value]
		button.set_meta("hint", hint)
		button.tooltip_text = tr(hint)
	portal_row = HBoxContainer.new()
	sidebar.add_child(portal_row)
	portal_menu = OptionButton.new()
	portal_menu.custom_minimum_size = Vector2(92, 44)
	for i in 26: portal_menu.add_item(String.chr(65 + i))
	portal_menu.item_selected.connect(func(index: int): group = index + 1; _brush("portal"))
	portal_row.add_child(portal_menu)
	portal_count = _label("", 14, MUTED)
	portal_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portal_row.add_child(portal_count)
	field_button = _button("One-way field", func(): _brush(last_field_direction), Vector2(0, 48))
	sidebar.add_child(field_button)
	field_directions = HBoxContainer.new()
	field_directions.add_theme_constant_override("separation", 8)
	sidebar.add_child(field_directions)
	for direction in ["up", "right", "down", "left"]:
		var brush_name: String = direction
		var button := _button("", func(): _brush(brush_name), Vector2(64, 56))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := DirectionGlyph.new()
		glyph.direction = direction
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(glyph)
		var hint: String = {"up": "Leave this tile only upward.", "right": "Leave this tile only to the right.",
			"down": "Leave this tile only downward.", "left": "Leave this tile only to the left."}[direction]
		button.set_meta("hint", hint)
		button.tooltip_text = tr(hint)
		field_directions.add_child(button)
		brushes[direction] = button
	var actions := HBoxContainer.new()
	sidebar_shell.add_child(actions)
	play_button = _button("Playtest", _playtest, Vector2(154, 48))
	records_button = _button("Leaderboard", _show_records, Vector2(154, 48))
	for button in [play_button, records_button]:
		button.add_theme_font_size_override("font_size", 14)
		actions.add_child(button)
	var files := HBoxContainer.new()
	sidebar_shell.add_child(files)
	for entry in [["Import", func(): _exchange(false)], ["Export", func(): _exchange(true)]]:
		var button := _button(entry[0], entry[1], Vector2(96, 44))
		button.add_theme_font_size_override("font_size", 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		files.add_child(button)
	mobile_redo = _button("Redo", func(): model.redo(); _edited(), Vector2(64, 44))
	mobile_redo.add_theme_font_size_override("font_size", 12)
	files.add_child(mobile_redo)
	best_label = _label("", 14, MUTED)
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar_shell.add_child(best_label)
	status = _label("Drag to paint. Right click removes tiles.", 14, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawing = VBoxContainer.new()
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
	statistics = _label("", 14, MUTED)
	statistics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawing.add_child(statistics)
	drawing.add_child(status)
	_build_exchange()
	_build_records()

func _dimension(parent: Node) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = 1
	input.max_value = Model.MAX_SIZE
	input.custom_minimum_size = Vector2(72, 44)
	parent.add_child(input)
	return input

func _layout_editor() -> void:
	if frame == null: return
	var factor := _screen_scale()
	_apply_layout(frame, factor)
	_apply_layout(exchange_panel, factor)
	var mobile := size.x < 960 or size.y < 600
	var narrow := size.x < 600
	mobile_tools.visible = mobile
	mobile_tools.text = tr("Board" if tools_open else "Tools")
	sidebar_shell.visible = not mobile or tools_open
	drawing.visible = not mobile or not tools_open
	sidebar_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_FILL
	mobile_redo.visible = mobile and narrow
	redo_button.visible = not narrow
	editor_title.visible = not mobile
	if mobile:
		for side in ["left", "right", "top", "bottom"]: frame.add_theme_constant_override("margin_" + side, 8)
		header.add_theme_constant_override("separation", 4)
		for button in [new_button, save_button]:
			button.custom_minimum_size.x = 60
			button.add_theme_font_size_override("font_size", 12)
		for button in [header.get_child(0), undo_button]:
			button.custom_minimum_size = Vector2(44, 44)
			button.size = button.custom_minimum_size
		mobile_tools.add_theme_font_size_override("font_size", 12)
		sidebar_shell.custom_minimum_size.x = 0
		brushes.floor.get_parent().columns = 2 if narrow else 3
		for button in [play_button, records_button]: button.custom_minimum_size.x = 130
	else:
		brushes.floor.get_parent().columns = 3
	theme.default_font_size = roundi(16 * factor)
	for selector in [level_menu, portal_menu]:
		var popup: PopupMenu = selector.get_popup()
		popup.max_size = Vector2i(0, roundi(size.y * 0.7))
		popup.add_theme_font_size_override("font_size", roundi(16 * factor))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.maximum_unit = 100 * factor
	board.visual_scale = factor
	board.padding = Vector2(16, 16) * factor
	board.queue_redraw()
	exchange_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := (12.0 if mobile else 44.0) * factor
	exchange_panel.offset_left = margin
	exchange_panel.offset_top = margin
	exchange_panel.offset_right = -margin
	exchange_panel.offset_bottom = -margin
	exchange_actions.columns = 2 if narrow else 5

func _fit_frame() -> void:
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _brush(value: String) -> void:
	brush = value
	if value in Puzzle.FIELD_DIRECTIONS:
		last_field_direction = value
	_sync()

func _paint(cell: int, erase: bool) -> void:
	model.begin_edit()
	if model.paint(cell, "void" if erase else brush, group):
		_edited()
	elif not model.last_error.is_empty(): _status(model.last_error)

func _edited() -> void:
	if model.dirty: _status("Drag to paint. Right click removes tiles.")
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
	var field_active := brush in Puzzle.FIELD_DIRECTIONS
	_accent(field_button, field_active)
	field_directions.visible = field_active
	portal_row.visible = brush == "portal"
	var tint: Color = board._portal_color(group)
	portal_menu.add_theme_color_override("font_color", tint)
	portal_count.add_theme_color_override("font_color", tint)
	portal_count.text = tr("%d / 2 ends") % model.board.count(group)
	statistics.text = tr("White %d · Black %d · Portal ends %d") % [model.pieces.count(1), model.pieces.count(-1), model.board.filter(func(tag): return Puzzle.is_portal(tag)).size()]
	var best: int = records.best(model.definition())
	best_label.text = tr("No records yet") if best == 0 else tr_n("Best known: %d move", "Best known: %d moves", best) % best

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
	title_input.release_focus()
	model = next_model
	model.dirty = unsaved
	_status("Drag to paint. Right click removes tiles.")
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
	_status("Level saved to My levels.")

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
		parsed = library.load_file(item.path, false)
	else:
		parsed = Model.parse(levels[int(item.index)])
	if parsed.has("model"): _replace(parsed.model, not item.has("path"))
	else: _status(parsed.error)

func _playtest() -> void:
	model.rename(title_input.text)
	model.commit_edit()
	var error: String = model.validation_error()
	if not error.is_empty(): _status(error); return
	_persist()
	playtest_requested.emit(model.definition())

func _build_records() -> void:
	records_layer = preload("res://scripts/ui/records_dialog.gd").new()
	records_layer.records = records
	add_child(records_layer)
	records_panel = records_layer.panel
	records_table = records_layer.table
	player_input = records_layer.player_input
	records_heading = records_layer.heading

func _save_player() -> void:
	records_layer.save_player()

func _show_records() -> void:
	model.rename(title_input.text)
	records_layer.show_level(model.definition())

func open_saved(path: String) -> void:
	var parsed: Dictionary = library.load_file(path, false)
	if not parsed.has("model"): _status(parsed.error); return
	if parsed.model.id == model.id: return
	if _stash(): _replace(parsed.model, false)

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
	var actions := GridContainer.new()
	actions.columns = 5
	exchange_actions = actions
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
	file_dialog.filters = PackedStringArray(["*.json ; ANNIHILATION level"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)

func _exchange(exporting: bool) -> void:
	model.rename(title_input.text)
	exchange_status.text = ""
	exchange_text.text = JSON.stringify(records.document(model), "\t") if exporting else ""
	exchange_layer.show()
	exchange_text.grab_focus()

func import_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > 8000000: _status("The level file is too large."); return false
	var json := JSON.new()
	if json.parse(text) != OK: _status("The file is not valid JSON."); return false
	var parsed := Model.parse(json.data)
	if not parsed.has("model"): _status(parsed.error); return false
	if not _stash(): return false
	_replace(parsed.model)
	var outcome := {"rejected": 0, "saved": true}
	if json.data is Dictionary and json.data.has("records"):
		outcome = records.merge(model.definition(), json.data.records)
	_sync()
	exchange_layer.hide()
	if not outcome.get("saved", true): _status("Could not save records.")
	elif outcome.rejected > 0: _status("Level imported. Invalid scores were skipped.")
	else: _status("Level and records imported.")
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
		JavaScriptBridge.download_buffer(exchange_text.text.to_utf8_buffer(), "ANNIHILATION-level.json", "application/json")
		return
	file_action = "export"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_file = "ANNIHILATION-level.json"
	file_dialog.popup_centered(Vector2i(760, 480))

func _file_selected(path: String) -> void:
	if file_action == "import":
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 8000000: _status("Could not open the level file."); return
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
	if records_layer.visible: return
	# Saving must also work while entering a name; text editing keeps its own undo.
	if (event.ctrl_pressed or event.meta_pressed) and event.physical_keycode == KEY_S:
		_save()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.physical_keycode == KEY_F5:
		_playtest()
	elif event.ctrl_pressed or event.meta_pressed:
		match event.physical_keycode:
			KEY_Z:
				if event.shift_pressed: model.redo()
				else: model.undo()
				_edited()
			_: return
	else: return
	get_viewport().set_input_as_handled()

func _refresh_language() -> void:
	if board == null: return
	mobile_tools.text = tr("Board" if tools_open else "Tools")
	title_input.placeholder_text = tr("Level name")
	_refresh_menu()
	_sync()
	if records_layer.visible: _show_records()

func refresh() -> void:
	_sync()

func _exit_tree() -> void:
	if library != null and model != null:
		if is_instance_valid(title_input): model.rename(title_input.text)
		model.commit_edit()
		library.save_draft(model)
