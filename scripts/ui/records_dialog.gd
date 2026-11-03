extends "res://scripts/ui/screen_base.gd"
## The same local score view is available from both authoring and level selection.
var records
var level: Dictionary = {}
var panel: PanelContainer
var table: VBoxContainer
var player_input: LineEdit
var heading: Label
var status: Label
var header: GridContainer
var profile: GridContainer

func _ready() -> void:
	_setup_theme()
	theme.set_stylebox("normal", "LineEdit", _style(Color(1, 1, 1, 0.025), LINE))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("080808"), LINE, 4))
	add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 16)
	panel.add_child(contents)
	header = GridContainer.new()
	header.columns = 3
	contents.add_child(header)
	header.add_child(_title("Local leaderboard", 24, 1))
	_spacer(header)
	header.add_child(_button("Close", close, Vector2(100, 40)))
	heading = _label("", 16, MUTED)
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(heading)
	profile = GridContainer.new()
	profile.columns = 2
	profile.add_child(_label("Player name", 14, MUTED))
	player_input = LineEdit.new()
	player_input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	player_input.max_length = 32
	player_input.custom_minimum_size = Vector2(240, 40)
	player_input.text_submitted.connect(func(_value: String): save_player())
	player_input.focus_exited.connect(save_player)
	profile.add_child(player_input)
	contents.add_child(profile)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(scroll)
	table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 12)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(table)
	status = _label("", 12, MUTED)
	contents.add_child(status)
	var hint := _label("Best run per name. Export JSON to share this map and its records; import a friend's JSON to merge their scores.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(hint)
	_remember_layout(panel)
	resized.connect(_layout_dialog)
	_layout_dialog()
	hide()

func _layout_dialog() -> void:
	if panel == null: return
	var factor := _screen_scale()
	_apply_layout(panel, factor)
	header.columns = 1 if size.x < 600 else 3
	profile.columns = 1 if size.x < 600 else 2
	if size.x < 600: player_input.custom_minimum_size.x = 200
	theme.default_font_size = roundi(14 * factor)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := (16.0 if size.x < 600 or size.y < 600 else 44.0) * factor
	panel.offset_left = margin
	panel.offset_top = margin
	panel.offset_right = -margin
	panel.offset_bottom = -margin

func save_player() -> void:
	status.text = tr("Could not save records.") if records.set_player(player_input.text) != OK else ""
	player_input.text = records.player

func close() -> void:
	save_player()
	hide()

func show_level(definition: Dictionary) -> void:
	level = definition
	heading.text = str(level.title)
	player_input.text = records.player
	status.text = ""
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()
	var rows: Array = records.entries(level)
	if rows.is_empty(): table.add_child(_label("No records yet", 16, MUTED))
	for i in rows.size():
		var row := HBoxContainer.new()
		table.add_child(row)
		row.add_child(_label("%02d" % (i + 1), 16, MUTED))
		var name_label := _label("", 16)
		name_label.text = rows[i].player
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		row.add_child(_label(tr("Moves: %d") % rows[i].moves, 16, PRIMARY))
	for child in table.get_children(): _remember_layout(child)
	_layout_dialog()
	show()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _refresh_language() -> void:
	if visible and not level.is_empty(): show_level(level)
