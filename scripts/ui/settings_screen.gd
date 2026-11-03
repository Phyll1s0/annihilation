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
var developer: VBoxContainer
var developer_button: Button
var editor_button: Button
var audio: VBoxContainer
var audio_button: Button
var volume_slider: HSlider
var volume_value: Label
var volume_knob: DPITexture
var pointer_action: Label
var pointer_binding: Label

func _ready() -> void:
	settings.apply_language()
	_setup_theme()
	toggle_on = preload("res://assets/icons/toggle-on.svg").duplicate()
	toggle_off = preload("res://assets/icons/toggle-off.svg").duplicate()
	theme.set_icon("checked", "CheckButton", toggle_on)
	theme.set_icon("unchecked", "CheckButton", toggle_off)
	volume_knob = preload("res://assets/icons/slider-knob.svg").duplicate()
	theme.set_icon("grabber", "HSlider", volume_knob)
	theme.set_icon("grabber_highlight", "HSlider", volume_knob)
	for style_name in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("292d32") if style_name == "slider" else Color("b8c1cc")
		track.set_corner_radius_all(2)
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		theme.set_stylebox(style_name, "HSlider", track)
	theme.set_stylebox("focus", "HSlider", _style(Color.TRANSPARENT, LINE, 3))
	back_button = _back_button(func(): navigation_requested.emit("back"))
	var margin := _margin(self, 82)
	frame = margin
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	developer_button = _button("Developer", _developer_tab, Vector2(160, 48))
	navigation.add_child(general_button)
	audio_button = _button("Audio", _audio_tab, Vector2(160, 48))
	navigation.add_child(audio_button)
	navigation.add_child(controls_button)
	navigation.add_child(developer_button)
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
	audio = VBoxContainer.new()
	audio.add_theme_constant_override("separation", 24)
	page.add_child(audio)
	var music_row := HBoxContainer.new()
	audio.add_child(music_row)
	music_row.add_child(_label("Music", 18))
	_spacer(music_row)
	var music_toggle := CheckButton.new()
	music_toggle.custom_minimum_size = Vector2(56, 40)
	music_toggle.toggled.connect(func(enabled: bool): _set_option("music_enabled", enabled); _refresh_audio())
	music_row.add_child(music_toggle)
	switches.music_enabled = music_toggle
	var volume_row := HBoxContainer.new()
	audio.add_child(volume_row)
	volume_row.add_child(_label("Volume", 18))
	_spacer(volume_row)
	volume_value = _label("", 14, MUTED)
	volume_row.add_child(volume_value)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.custom_minimum_size = Vector2(200, 40)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(func(value: float):
		settings.music_volume = value / 100.0
		_save_settings()
		_refresh_audio()
		settings_changed.emit())
	audio.add_child(volume_slider)
	audio.add_child(_label("Still Orbit", 14, MUTED))
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	page.add_child(controls)
	var movement_row := HBoxContainer.new()
	controls.add_child(movement_row)
	movement_row.add_child(_label("Keyboard-only movement", 18))
	_spacer(movement_row)
	var movement_toggle := CheckButton.new()
	movement_toggle.custom_minimum_size = Vector2(56, 40)
	movement_toggle.tooltip_text = tr("Mouse selects particles; use arrow keys or WASD to move.")
	movement_toggle.set_meta("hint", "Mouse selects particles; use arrow keys or WASD to move.")
	movement_toggle.toggled.connect(func(enabled: bool): _set_option("keyboard_only_movement", enabled))
	movement_row.add_child(movement_toggle)
	switches.keyboard_only_movement = movement_toggle
	for entry in [["Select / move", "Click a particle, then a neighboring tile"], ["Move", "↑ ↓ ← →  /  WASD"], ["Cycle particles", "Tab  /  Shift Tab"],
		["Undo", "Z"], ["Restart", "R"], ["Deselect / pause", "Esc"]]:
		var row := HBoxContainer.new()
		controls.add_child(row)
		var action := _label(entry[0], 16)
		row.add_child(action)
		_spacer(row)
		var binding := _label(entry[1], 14, MUTED)
		binding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		binding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(binding)
		if entry[0] == "Select / move":
			pointer_action = action
			pointer_binding = binding
	var rules := _label("Meet opposite colors to clear the board. The collision tile disappears.\nMatching colors block each other. Portals with the same letter are linked.\nOn an arrow tile, a particle can leave only in the arrow direction.", 12, MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(rules)
	developer = VBoxContainer.new()
	developer.add_theme_constant_override("separation", 20)
	page.add_child(developer)
	var developer_row := HBoxContainer.new()
	developer.add_child(developer_row)
	developer_row.add_child(_label("Developer mode", 18))
	_spacer(developer_row)
	var developer_toggle := CheckButton.new()
	developer_toggle.custom_minimum_size = Vector2(56, 40)
	developer_toggle.toggled.connect(func(enabled: bool):
		_set_option("developer_mode", enabled)
		editor_button.disabled = not enabled)
	developer_row.add_child(developer_toggle)
	switches.developer_mode = developer_toggle
	var developer_copy := _label("Unlock every campaign level and enable level creation.", 14, MUTED)
	developer_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	developer.add_child(developer_copy)
	editor_button = _button("Level editor", func(): navigation_requested.emit("create_level"), Vector2(180, 48))
	developer.add_child(editor_button)
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

func _layout_settings() -> void:
	if frame == null:
		return
	ui_scale = _screen_scale()
	volume_knob.base_scale = ui_scale
	toggle_on.base_scale = ui_scale
	toggle_off.base_scale = ui_scale
	if language_arrow != null:
		language_arrow.base_scale = language_arrow_scale * ui_scale
	_apply_layout(self, ui_scale)
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
	developer.hide()
	audio.hide()
	_accent(audio_button, false)
	heading.text = tr("Controls") if show_controls else tr("Settings")
	_accent(general_button, not show_controls)
	_accent(controls_button, show_controls)
	_accent(developer_button, false)
	var active := controls_button if show_controls else general_button
	var marker: StyleBoxFlat = active.get_theme_stylebox("normal").duplicate()
	marker.set_border_width_all(0)
	marker.border_width_left = 2
	active.add_theme_stylebox_override("normal", marker)

func _developer_tab() -> void:
	audio.hide()
	_accent(audio_button, false)
	general.hide()
	controls.hide()
	developer.show()
	heading.text = tr("Developer")
	_accent(general_button, false)
	_accent(controls_button, false)
	_accent(developer_button, true)

func _audio_tab() -> void:
	general.hide()
	controls.hide()
	developer.hide()
	audio.show()
	heading.text = tr("Audio")
	for button in [general_button, controls_button, developer_button]: _accent(button, false)
	_accent(audio_button, true)
	_refresh_audio()

func _refresh_audio() -> void:
	volume_slider.set_value_no_signal(roundi(settings.music_volume * 100))
	volume_value.text = "%d%%" % roundi(settings.music_volume * 100)
	volume_slider.editable = settings.music_enabled
	volume_slider.modulate.a = 1.0 if settings.music_enabled else 0.4

func _set_option(key: String, enabled: bool) -> void:
	settings.set(key, enabled)
	_save_settings()
	if key == "fullscreen":
		settings.apply_window()
	if key == "keyboard_only_movement": _refresh_controls()
	settings_changed.emit()

func _refresh_controls() -> void:
	if pointer_action == null: return
	pointer_action.text = tr("Select particle" if settings.keyboard_only_movement else "Select / move")
	pointer_binding.text = tr("Click a particle" if settings.keyboard_only_movement else "Click a particle, then a neighboring tile")

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
		heading.text = tr("Audio") if audio.visible else (tr("Developer") if developer.visible else (tr("Controls") if controls.visible else tr("Settings")))
		status.text = tr(status_message)
		_refresh_controls()

func refresh() -> void:
	language_selector.select(settings.LANGUAGES.find(settings.language))
	for key in switches:
		switches[key].set_pressed_no_signal(settings.get(key))
	editor_button.disabled = not settings.developer_mode
	_refresh_audio()
	_refresh_controls()
