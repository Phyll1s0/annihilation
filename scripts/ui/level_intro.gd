extends Control
## A brief title card that dissolves to reveal the live board underneath.
const HOLD_SECONDS := 0.12
const FADE_SECONDS := 0.63
var title_font: Font
var number_font: Font
var title: Label
var number: Label
var body: VBoxContainer
var fade: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(body)
	number = Label.new()
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_override("font", number_font)
	number.add_theme_color_override("font_color", Color("89939e"))
	body.add_child(number)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_override("font", title_font)
	title.add_theme_color_override("font_color", Color("e6e9ec"))
	body.add_child(title)
	resized.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	var factor := maxf(1.0, minf(size.x / 1280.0, size.y / 820.0))
	body.custom_minimum_size.x = minf(720.0 * factor, maxf(1.0, size.x - 64.0))
	body.add_theme_constant_override("separation", roundi(14.0 * factor))
	number.add_theme_font_size_override("font_size", roundi(13.0 * factor))
	title.add_theme_font_size_override("font_size", roundi(42.0 * factor))

func play(number_text: String, title_text: String) -> void:
	cancel()
	number.text = number_text
	title.text = title_text
	show()
	fade = create_tween()
	fade.tween_interval(HOLD_SECONDS)
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
	fade.tween_callback(cancel)

func cancel() -> void:
	if fade != null and fade.is_running(): fade.kill()
	modulate.a = 1.0
	hide()
