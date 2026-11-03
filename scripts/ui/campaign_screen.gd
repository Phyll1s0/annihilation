extends "res://scripts/ui/screen_base.gd"
signal navigation_requested(destination: String)
signal level_requested(index: int, hard: bool)
const Catalog = preload("res://scripts/catalog.gd")
var levels: Array = []
var progress
var settings
var chapter := ""
var chapter_buttons: Array[Button] = []
var chapter_names: Array[String] = []
var cards: Array[Button] = []
var grid: GridContainer
var easy_button: Button
var hard_button: Button
var chapter_title: Label
var chapter_number: Label
var detail: Label
var bars: Dictionary = {}
var previous_button: Button
var following_button: Button
var back_button: Button
var settings_button: Button
var center: CenterContainer
var body: VBoxContainer
var level_area: CenterContainer
var ui_scale := 1.0
var tabs: HBoxContainer
var my_levels_button: Button
var resume_button: Button
var scroll: ScrollContainer

func _ready() -> void:
	_setup_theme()
	back_button = _back_button(func(): navigation_requested.emit("home"))
	settings_button = _icon_button("settings-outline", "Settings", func(): navigation_requested.emit("settings"))
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -72
	settings_button.offset_right = -24
	settings_button.offset_top = 24
	settings_button.offset_bottom = 72
	add_child(settings_button)
	tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	var campaign_button := _button("Campaign", func(): pass, Vector2(155, 44))
	_accent(campaign_button, true)
	tabs.add_child(campaign_button)
	my_levels_button = _button("My levels", func(): navigation_requested.emit("my_levels"), Vector2(155, 44))
	tabs.add_child(my_levels_button)
	resume_button = _button("Continue", func(): navigation_requested.emit("continue"), Vector2(120, 44))
	tabs.add_child(resume_button)
	center = CenterContainer.new()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(center)
	body = VBoxContainer.new()
	body.custom_minimum_size.x = 600
	body.add_theme_constant_override("separation", 24)
	center.add_child(body)
	chapter_number = _label("", 11, MUTED)
	chapter_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(chapter_number)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 56)
	body.add_child(header)
	chapter_title = _title("", 36, 1)
	header.add_child(chapter_title)
	var progress_box := VBoxContainer.new()
	progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_box.add_theme_constant_override("separation", 10)
	header.add_child(progress_box)
	bars.easy = _progress_bar("Easy", Color("b8bec5"), progress_box)
	bars.hard = _progress_bar("Hard", PRIMARY, progress_box)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 12)
	body.add_child(modes)
	easy_button = _button("Easy", func(): _mode(false), Vector2(155, 44))
	hard_button = _button("Hard", func(): _mode(true), Vector2(155, 44))
	easy_button.add_theme_font_size_override("font_size", 14)
	hard_button.add_theme_font_size_override("font_size", 14)
	easy_button.tooltip_text = tr("Clear the board")
	easy_button.set_meta("hint", "Clear the board")
	hard_button.tooltip_text = tr("Clear the board in the fewest moves")
	hard_button.set_meta("hint", "Clear the board in the fewest moves")
	modes.add_child(easy_button)
	modes.add_child(hard_button)
	var grid_center := CenterContainer.new()
	level_area = grid_center
	grid_center.custom_minimum_size.y = 132
	body.add_child(grid_center)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid_center.add_child(grid)
	detail = _label("", 13, MUTED)
	detail.custom_minimum_size.y = 22
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(detail)
	var pagination := HBoxContainer.new()
	pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	pagination.add_theme_constant_override("separation", 5)
	body.add_child(pagination)
	chapter_names = Catalog.chapters(levels)
	chapter = chapter_names[0]
	for name_value in chapter_names:
		var name_copy := name_value
		var button := _button("•", func(): chapter = name_copy; refresh(), Vector2(26, 28))
		button.add_theme_font_size_override("font_size", 19)
		button.tooltip_text = name_copy
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		pagination.add_child(button)
		chapter_buttons.append(button)
	previous_button = _icon_button("chevron-back-outline", "Previous chapter", func(): _shift(-1), 42, 60)
	previous_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	previous_button.offset_left = 168
	previous_button.offset_right = 228
	previous_button.offset_top = -30
	previous_button.offset_bottom = 30
	add_child(previous_button)
	following_button = _icon_button("chevron-forward-outline", "Next chapter", func(): _shift(1), 42, 60)
	following_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	following_button.offset_left = -228
	following_button.offset_right = -168
	following_button.offset_top = -30
	following_button.offset_bottom = 30
	add_child(following_button)
	# The scroll area fills the page; navigation must remain above it for hit testing.
	for button in [back_button, settings_button, tabs]: move_child(button, get_child_count() - 1)
	_remember_layout(self)
	center.minimum_size_changed.connect(_fit_center)
	body.item_rect_changed.connect(_place_chapter_arrows)
	level_area.item_rect_changed.connect(_place_chapter_arrows)
	grid.item_rect_changed.connect(_place_chapter_arrows)
	resized.connect(_layout_campaign)
	refresh()

func _layout_campaign() -> void:
	if following_button == null:
		return
	ui_scale = _screen_scale()
	_apply_layout(self, ui_scale)
	var mobile := size.x < 960 or size.y < 600
	var narrow := size.x < 600
	var short_screen := size.y < 600 and not narrow
	chapter_number.visible = not short_screen
	bars.easy.bar.get_parent().get_parent().visible = not short_screen
	if mobile:
		body.custom_minimum_size.x = minf(600, size.x - 32)
		body.add_theme_constant_override("separation", 14 if narrow else 6)
		var title_size := 28 if narrow else 24
		var title_width := chapter_title.get_theme_font("font").get_string_size(chapter_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		var available_title := size.x - 162 if narrow else size.x - 64
		chapter_title.add_theme_font_size_override("font_size", floori(title_size * minf(1, available_title / maxf(1, title_width))))
		chapter_title.get_parent().add_theme_constant_override("separation", 20)
		for bar in bars.values(): bar.bar.get_parent().custom_minimum_size.x = 110
		for button in tabs.get_children():
			button.custom_minimum_size = Vector2(88, 44)
			button.add_theme_font_size_override("font_size", 12)
		for button in [easy_button, hard_button]: button.custom_minimum_size.x = minf(155, (size.x - 44) / 2)
		for card in cards:
			var hit := minf(76, (size.x - 62) / 4) if narrow else 64.0
			card.custom_minimum_size = Vector2.ONE * hit
			card.add_theme_font_size_override("font_size", 28)
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		level_area.custom_minimum_size.y = 100 if narrow else 64
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size.x = 0
		detail.visible = narrow
		# Page arrows provide larger touch targets than eleven small dots.
		chapter_buttons[0].get_parent().visible = false
	else:
		detail.visible = true
		chapter_buttons[0].get_parent().visible = true
	back_button.position = Vector2(24, 24) * ui_scale
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -72 * ui_scale
	settings_button.offset_right = -24 * ui_scale
	settings_button.offset_top = 24 * ui_scale
	settings_button.offset_bottom = 72 * ui_scale
	tabs.size = tabs.get_combined_minimum_size()
	tabs.position = Vector2((size.x - tabs.size.x) / 2.0, (84 if narrow else 24) * ui_scale)
	_fit_center()
	call_deferred("_place_chapter_arrows")

func _fit_center() -> void:
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if size.x < 960 or size.y < 600:
		scroll.offset_top = 140 if size.x < 600 else 72
		scroll.offset_bottom = -72 if size.x < 600 else -48
		scroll.offset_left = 16
		scroll.offset_right = -16
	center.custom_minimum_size.y = maxf(1, scroll.size.y)
	# Font shaping can briefly enlarge the minimum during a chapter change.
	center.queue_sort()

func _place_chapter_arrows() -> void:
	if level_area == null or following_button == null:
		return
	var middle := level_area.get_global_rect().get_center() - global_position
	var hit := 60.0 * ui_scale
	if size.x < 960 or size.y < 600:
		for button in [previous_button, following_button]:
			button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			button.size = Vector2.ONE * 48
		previous_button.position = Vector2(24, size.y - 60)
		following_button.position = Vector2(size.x - 72, size.y - 60)
		return
	var gap := 40.0 * ui_scale
	for button in [previous_button, following_button]:
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.size = Vector2.ONE * hit
	previous_button.position = Vector2(middle.x - grid.size.x / 2.0 - gap - hit, middle.y - hit / 2.0)
	following_button.position = Vector2(middle.x + grid.size.x / 2.0 + gap, middle.y - hit / 2.0)

func _progress_bar(title: String, color: Color, parent: Container) -> Dictionary:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 220
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_label(title, 11, MUTED))
	_spacer(row)
	var counter := _label("", 11, MUTED)
	row.add_child(counter)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 3
	bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("36393d")
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	box.add_child(bar)
	return {"counter": counter, "bar": bar}

func _shift(offset: int) -> void:
	var index := chapter_names.find(chapter)
	chapter = chapter_names[clampi(index + offset, 0, chapter_names.size() - 1)]
	refresh()

func _mode(hard: bool) -> void:
	settings.hard_mode = hard
	settings.save()
	refresh()

func refresh() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	var resume_index := Catalog.index_of(levels, str(progress.resume.get("level_id", "")))
	resume_button.visible = not progress.resume.is_empty() and progress.level_unlocked(levels, resume_index, settings.developer_mode)
	if resume_button.visible:
		var saved: Dictionary = progress.resume
		resume_button.tooltip_text = tr("Level %s · %s · Moves: %d") % [saved.level_id, tr("Hard") if saved.hard_mode else tr("Easy"), saved.actions.size()]
	_accent(easy_button, not settings.hard_mode)
	_accent(hard_button, settings.hard_mode)
	var unlocked: Array = progress.unlocked_chapters(levels, settings.developer_mode)
	var playable := chapter in unlocked
	var blocker: String = progress.blocking_chapter(levels, chapter)
	var lock_hint := tr("Complete every Easy level in %s to unlock.") % tr(blocker) if not playable else ""
	var chapter_index := chapter_names.find(chapter)
	chapter_title.text = tr(chapter)
	chapter_number.text = "%02d / %02d" % [chapter_index + 1, chapter_names.size()]
	previous_button.disabled = chapter_index == 0
	following_button.disabled = chapter_index == chapter_names.size() - 1
	for i in chapter_buttons.size():
		chapter_buttons[i].tooltip_text = tr(chapter_names[i]) + (" · " + tr("Locked") if chapter_names[i] not in unlocked else "")
		chapter_buttons[i].add_theme_color_override("font_color", PRIMARY if i == chapter_index else Color("68717b") if chapter_names[i] in unlocked else Color("36393d"))
	var easy_count := 0
	var hard_count := 0
	var total := 0
	for i in levels.size():
		var definition: Dictionary = levels[i]
		if definition.chapter != chapter:
			continue
		total += 1
		var record: Dictionary = progress.records.get(definition.id, {})
		easy_count += 1 if progress.easy_cleared(definition.id) else 0
		hard_count += 1 if record.get("hard", false) else 0
		var index := i
		var card := _button(definition.id, func(): level_requested.emit(index, settings.hard_mode), Vector2(96, 96))
		card.disabled = not playable
		card.add_theme_font_override("font", heavy)
		card.add_theme_font_size_override("font_size", 32)
		var cleared: bool = record.get("hard" if settings.hard_mode else "easy", false)
		card.add_theme_stylebox_override("normal", _style(Color(PRIMARY, 0.08) if cleared else Color(0.18, 0.18, 0.18, 0.32),
			Color(PRIMARY, 0.35) if cleared else Color(0, 0, 0, 0), 0))
		card.add_theme_stylebox_override("hover", _style(Color(PRIMARY, 0.07), Color(1, 1, 1, 0.56), 0))
		card.add_theme_color_override("font_color", PRIMARY if cleared else INK)
		var caption := "%s  /  %s" % [definition.id, tr(definition.title)]
		if settings.hard_mode:
			caption += tr("   ·   Best possible: %d") % definition.optimal_moves
		card.tooltip_text = caption + ("\n" + lock_hint if not playable else "")
		var hint: String = caption if playable else lock_hint
		card.mouse_entered.connect(func(): detail.text = hint)
		card.focus_entered.connect(func(): detail.text = hint)
		grid.add_child(card)
		_remember_layout(card)
		cards.append(card)
	for key in ["easy", "hard"]:
		var amount: int = easy_count if key == "easy" else hard_count
		bars[key].counter.text = "%d / %d" % [amount, total]
		bars[key].bar.value = float(amount) / total * 100
	detail.text = lock_hint
	_layout_campaign()

func _refresh_language() -> void:
	refresh()
