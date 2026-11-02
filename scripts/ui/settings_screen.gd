extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal settings_changed
var settings
var switches: Dictionary = {}
var status: Label
var heading: Label
var general: VBoxContainer
var controls: VBoxContainer
var general_button: Button
var controls_button: Button
var language_selector: OptionButton
var status_message := "Settings are saved automatically."
var frame: MarginContainer
var back_button: Button
var toggle_on: DPITexture
var toggle_off: DPITexture
var language_arrow: DPITexture
var language_arrow_scale := 1.0
var ui_scale := 1.0

func _ready() -> void:
	settings.apply_language()
	_setup_theme()
	toggle_on = preload("res://assets/icons/toggle-on.svg").duplicate()
	toggle_off = preload("res://assets/icons/toggle-off.svg").duplicate()
	theme.set_icon("checked", "CheckButton", toggle_on)
	theme.set_icon("unchecked", "CheckButton", toggle_off)
	back_button = _back_button(func(): navigation_requested.emit("back"))
	var margin := _margin(self, 82)
	frame = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 128)
	margin.add_theme_constant_override("margin_right", 128)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 160
	layout.add_child(navigation)
	var gap := Control.new()
	gap.custom_minimum_size.y = 150
	navigation.add_child(gap)
	general_button = _button("General", func(): _tab(false), Vector2(160, 48))
	controls_button = _button("Controls", func(): _tab(true), Vector2(160, 48))
	navigation.add_child(general_button)
	navigation.add_child(controls_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	navigation.add_child(_button("Back", func(): navigation_requested.emit("back"), Vector2(160, 48)))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.06), Color(1, 1, 1, 0.40), 3))
	layout.add_child(panel)
	var inside := _margin(panel, 22)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	inside.add_child(page)
	heading = _title("Settings", 28, 1)
	page.add_child(heading)
	general = VBoxContainer.new()
	general.add_theme_constant_override("separation", 18)
	page.add_child(general)
	var language_row := HBoxContainer.new()
	general.add_child(language_row)
	var language_label := _label("Language", 18)
	language_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	language_row.add_child(language_label)
	_spacer(language_row)
	language_selector = OptionButton.new()
	language_selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_selector.custom_minimum_size = Vector2(160, 40)
	language_selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	language_selector.add_item("English")
	language_selector.add_item("简体中文")
	language_selector.item_selected.connect(_set_language)
	language_row.add_child(language_selector)
	var arrow = language_selector.get_theme_icon("arrow")
	if arrow is DPITexture:
		language_arrow = arrow.duplicate()
		language_arrow_scale = language_arrow.base_scale
		language_selector.add_theme_icon_override("arrow", language_arrow)
	for entry in [["show_hints", "Show legal moves", "Show reachable tiles when a particle is selected."],
		["reduce_motion", "Reduced motion", "Freeze the sky and show moves without animation."],
		["fullscreen", "Fullscreen", "Press F11 to toggle fullscreen."]]:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		general.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 6)
		row.add_child(copy)
		copy.add_child(_label(entry[1], 18))
		var description := _label(entry[2], 12, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(description)
		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(56, 40)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.toggled.connect(func(enabled: bool): _set_option(key, enabled))
		row.add_child(toggle)
		switches[key] = toggle
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	page.add_child(controls)
	for entry in [["Select / move", "Click a particle, then a neighboring tile"], ["Move", "↑ ↓ ← →  /  WASD"], ["Cycle particles", "Tab  /  Shift Tab"],
		["Undo", "Z"], ["Restart", "R"], ["Deselect / pause", "Esc"]]:
		var row := HBoxContainer.new()
		controls.add_child(row)
		row.add_child(_label(entry[0], 16))
		_spacer(row)
		var binding := _label(entry[1], 14, MUTED)
		binding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		binding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(binding)
	var rules := _label("Meet opposite colors to clear the board. The collision tile disappears.\nMatching colors block each other. Portals with the same letter are linked.", 12, MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(rules)
	var remaining := Control.new()
	remaining.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(remaining)
	status = _label("Settings are saved automatically.", 11, MUTED)
	page.add_child(status)
	_tab(false)
	refresh()
	_remember_layout(self)
	frame.minimum_size_changed.connect(_fit_frame)
	resized.connect(_layout_settings)
	_layout_settings()

func _remember_layout(node: Node) -> void:
	if node is Control:
		node.set_meta("base_minimum", node.custom_minimum_size)
	if node is Label or node is Button:
		node.set_meta("base_font_size", node.get_theme_font_size("font_size"))
		var font = node.get_theme_font("font")
		if font is FontVariation:
			node.set_meta("base_tracking", font.spacing_glyph)
	if node is BoxContainer:
		node.set_meta("base_separation", node.get_theme_constant("separation"))
	if node is MarginContainer:
		var margins := {}
		for edge in ["left", "top", "right", "bottom"]:
			margins[edge] = node.get_theme_constant("margin_" + edge)
		node.set_meta("base_margins", margins)
	for child in node.get_children():
		_remember_layout(child)

func _apply_layout(node: Node) -> void:
	if node.has_meta("base_minimum"):
		node.custom_minimum_size = node.get_meta("base_minimum") * ui_scale
	if node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size", roundi(node.get_meta("base_font_size") * ui_scale))
	if node.has_meta("base_tracking"):
		node.get_theme_font("font").spacing_glyph = roundi(node.get_meta("base_tracking") * ui_scale)
	if node.has_meta("base_separation"):
		node.add_theme_constant_override("separation", roundi(node.get_meta("base_separation") * ui_scale))
	if node.has_meta("base_margins"):
		var margins: Dictionary = node.get_meta("base_margins")
		for edge in margins:
			node.add_theme_constant_override("margin_" + edge, roundi(margins[edge] * ui_scale))
	for child in node.get_children():
		_apply_layout(child)

func _layout_settings() -> void:
	if frame == null:
		return
	ui_scale = maxf(1.0, minf(size.x / 1280.0, size.y / 820.0))
	toggle_on.base_scale = ui_scale
	toggle_off.base_scale = ui_scale
	if language_arrow != null:
		language_arrow.base_scale = language_arrow_scale * ui_scale
	_apply_layout(self)
	theme.default_font_size = roundi(15 * ui_scale)
	back_button.position = Vector2(24, 24) * ui_scale
	back_button.add_theme_constant_override("icon_max_width", roundi(32 * ui_scale))
	back_button.size = back_button.custom_minimum_size
	var popup := language_selector.get_popup()
	popup.add_theme_font_override("font", regular)
	popup.add_theme_font_size_override("font_size", roundi(15 * ui_scale))
	popup.add_theme_constant_override("v_separation", roundi(8 * ui_scale))
	popup.add_theme_stylebox_override("panel", _style(Color("080808"), LINE, roundi(3 * ui_scale)))
	_fit_frame()

func _fit_frame() -> void:
	# Container minimums settle after fonts and vector icons have changed size.
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _tab(show_controls: bool) -> void:
	general.visible = not show_controls
	controls.visible = show_controls
	heading.text = tr("Controls") if show_controls else tr("Settings")
	_accent(general_button, not show_controls)
	_accent(controls_button, show_controls)
	var active := controls_button if show_controls else general_button
	var marker: StyleBoxFlat = active.get_theme_stylebox("normal").duplicate()
	marker.set_border_width_all(0)
	marker.border_width_left = 2
	active.add_theme_stylebox_override("normal", marker)

func _set_option(key: String, enabled: bool) -> void:
	settings.set(key, enabled)
	_save_settings()
	if key == "fullscreen":
		settings.apply_window()
	settings_changed.emit()

func _save_settings() -> void:
	status_message = "Settings saved." if settings.save() == OK else "Could not save settings. Changes still apply to this session."
	status.text = tr(status_message)

func _set_language(index: int) -> void:
	if index < 0 or index >= settings.LANGUAGES.size():
		return
	settings.language = settings.LANGUAGES[index]
	_save_settings()
	settings.apply_language()
	settings_changed.emit()

func _refresh_language() -> void:
	if heading != null:
		heading.text = tr("Controls") if controls.visible else tr("Settings")
		status.text = tr(status_message)

func refresh() -> void:
	language_selector.select(settings.LANGUAGES.find(settings.language))
	for key in switches:
		switches[key].set_pressed_no_signal(settings.get(key))
