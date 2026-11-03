extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal level_requested(definition: Dictionary)
signal edit_requested(path: String)
var library
var records
var settings
var frame: MarginContainer
var contents: VBoxContainer
var list: VBoxContainer
var rows: Array[Dictionary] = []
var records_dialog
var empty_label: Label
var create_button: Button
var back_button: Button
var settings_button: Button
var tabs: HBoxContainer

func _ready() -> void:
	_setup_theme()
	back_button = _back_button(func(): navigation_requested.emit("home"))
	settings_button = _icon_button("settings-outline", "Settings", func(): navigation_requested.emit("settings"))
	add_child(settings_button)
	tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	tabs.add_child(_button("Campaign", func(): navigation_requested.emit("campaign"), Vector2(155, 44)))
	var current_tab := _button("My levels", func(): pass, Vector2(155, 44))
	_accent(current_tab, true)
	tabs.add_child(current_tab)
	frame = MarginContainer.new()
	add_child(frame)
	contents = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 20)
	frame.add_child(contents)
	var header := HBoxContainer.new()
	contents.add_child(header)
	header.add_child(_title("My levels", 28, 1))
	_spacer(header)
	create_button = _button("Create", func(): navigation_requested.emit("create_level"), Vector2(120, 44))
	header.add_child(create_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	records_dialog = preload("res://scripts/ui/records_dialog.gd").new()
	records_dialog.records = records
	add_child(records_dialog)
	_remember_layout(frame)
	_remember_layout(tabs)
	resized.connect(_layout_library)
	refresh()

func _layout_library() -> void:
	if frame == null: return
	var factor := _screen_scale()
	_apply_layout(frame, factor)
	_apply_layout(tabs, factor)
	back_button.position = Vector2(24, 24) * factor
	back_button.custom_minimum_size = Vector2(48, 48) * factor
	back_button.add_theme_constant_override("icon_max_width", roundi(32 * factor))
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -72 * factor
	settings_button.offset_right = -24 * factor
	settings_button.offset_top = 24 * factor
	settings_button.offset_bottom = 72 * factor
	settings_button.custom_minimum_size = Vector2(48, 48) * factor
	settings_button.add_theme_constant_override("icon_max_width", roundi(24 * factor))
	tabs.position = Vector2((size.x - tabs.get_combined_minimum_size().x) / 2.0, 24 * factor)
	tabs.size = tabs.get_combined_minimum_size()
	var width := minf(800 * factor, size.x - 80 * factor)
	frame.position = Vector2((size.x - width) / 2.0, 112 * factor)
	frame.size = Vector2(width, maxf(1, size.y - 156 * factor))

func refresh() -> void:
	if list == null: return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	rows.clear()
	create_button.visible = settings.developer_mode
	empty_label = null
	var saved: Array = library.list_levels()
	if saved.is_empty():
		empty_label = _label("No saved levels yet. Create a level and choose Save to add it here." if settings.developer_mode else "No saved levels yet.", 16, MUTED)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty_label)
		_remember_layout(empty_label)
	for item in saved:
		var definition: Dictionary = item.definition
		var path: String = item.path
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", _style(Color(1,1,1,0.018), LINE))
		list.add_child(plate)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		plate.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		var title := _label("", 18)
		title.text = definition.title
		title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.tooltip_text = definition.title
		text.add_child(title)
		var best: int = records.best(definition)
		text.add_child(_label(tr_n("Best known: %d move", "Best known: %d moves", best) % best if best > 0 else tr("No records yet"), 12, MUTED))
		var play := _button("Play", func(): level_requested.emit(definition), Vector2(88, 44))
		play.disabled = not item.playable
		if play.disabled: play.tooltip_text = tr("Finish this map in the editor before playing.")
		row.add_child(play)
		var scores := _button("Leaderboard", func(): records_dialog.show_level(definition), Vector2(120, 44))
		scores.add_theme_font_size_override("font_size", 12)
		row.add_child(scores)
		var edit := _button("Edit", func(): edit_requested.emit(path), Vector2(88, 44))
		edit.visible = settings.developer_mode
		row.add_child(edit)
		_remember_layout(plate)
		rows.append({"play": play, "edit": edit, "scores": scores, "definition": definition})
	_layout_library()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or records_dialog.visible: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		navigation_requested.emit("home")
		get_viewport().set_input_as_handled()

func _refresh_language() -> void:
	refresh()
