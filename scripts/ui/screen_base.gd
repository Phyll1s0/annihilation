extends Control

const INK := Color("272a26")
const MUTED := Color("777c72")
const PAPER := Color("f2f0ea")
const LINE := Color("d5d7cc")

var regular: SystemFont
var heavy: SystemFont

func _style(fill: Color, border: Color = LINE, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _setup_theme() -> void:
	regular = SystemFont.new()
	regular.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	heavy = SystemFont.new()
	heavy.font_names = regular.font_names
	heavy.font_weight = 700
	var ui := Theme.new()
	ui.default_font = regular
	ui.default_font_size = 15
	ui.set_color("font_color", "Label", INK)
	ui.set_color("font_color", "Button", INK)
	ui.set_color("font_hover_color", "Button", INK)
	ui.set_color("font_pressed_color", "Button", PAPER)
	ui.set_color("font_disabled_color", "Button", Color("a4a89d"))
	ui.set_stylebox("normal", "Button", _style(Color("eeeee5")))
	ui.set_stylebox("hover", "Button", _style(Color("fffdf6"), Color("9b9f92")))
	ui.set_stylebox("pressed", "Button", _style(INK, INK))
	ui.set_stylebox("disabled", "Button", _style(Color("e9eae1"), Color("dedfd5")))
	ui.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), MUTED))
	ui.set_constant("separation", "VBoxContainer", 12)
	ui.set_constant("separation", "HBoxContainer", 12)
	theme = ui

func _label(text: String, font_size: int = 15, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", heavy)
	return label

func _button(text: String, action: Callable, minimum: Vector2 = Vector2(0, 42)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _spacer(parent: Container) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _margin(parent: Node, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, amount)
	parent.add_child(margin)
	return margin

func _accent(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override("normal", _style(INK if active else Color("eeeee5"), INK if active else LINE))
	button.add_theme_color_override("font_color", PAPER if active else INK)
