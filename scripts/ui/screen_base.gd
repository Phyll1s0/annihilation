extends Control

const INK := Color("efefef")
const MUTED := Color("8d9298")
const PAPER := Color("1b1b1b")
const LINE := Color(1, 1, 1, 0.22)
const PRIMARY := Color("6af5b9")

var regular: Font
var heavy: Font
var tech: Font
var entrance: Tween

func _style(fill: Color, border: Color = LINE, radius: int = 3) -> StyleBoxFlat:
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
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	var light_fallback := fallback.duplicate()
	light_fallback.font_weight = 200
	regular = preload("res://assets/fonts/Poppins-Regular.ttf").duplicate()
	regular.fallbacks = [fallback]
	heavy = preload("res://assets/fonts/Poppins-ExtraLight.ttf").duplicate()
	heavy.fallbacks = [light_fallback]
	tech = preload("res://assets/fonts/Electrolize-Regular.ttf").duplicate()
	tech.fallbacks = [fallback]
	var ui := Theme.new()
	ui.default_font = regular
	ui.default_font_size = 15
	ui.set_color("font_color", "Label", INK)
	ui.set_color("font_color", "Button", INK)
	ui.set_color("font_hover_color", "Button", PRIMARY)
	ui.set_color("font_pressed_color", "Button", PRIMARY)
	ui.set_color("font_disabled_color", "Button", Color("484d52"))
	ui.set_color("icon_normal_color", "Button", INK)
	ui.set_color("icon_hover_color", "Button", PRIMARY)
	ui.set_color("icon_pressed_color", "Button", PRIMARY)
	ui.set_color("icon_disabled_color", "Button", Color("484d52"))
	ui.set_stylebox("normal", "Button", _style(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.12)))
	ui.set_stylebox("hover", "Button", _style(Color(PRIMARY, 0.055), Color(PRIMARY, 0.55)))
	ui.set_stylebox("pressed", "Button", _style(Color(PRIMARY, 0.10), PRIMARY))
	ui.set_stylebox("disabled", "Button", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	ui.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color(PRIMARY, 0.65)))
	ui.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	ui.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	ui.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	ui.set_stylebox("focus", "CheckButton", _style(Color(0, 0, 0, 0), Color(PRIMARY, 0.5)))
	ui.set_icon("checked", "CheckButton", preload("res://assets/icons/toggle-on.svg"))
	ui.set_icon("unchecked", "CheckButton", preload("res://assets/icons/toggle-off.svg"))
	ui.set_stylebox("panel", "TooltipPanel", _style(Color("262626"), LINE))
	ui.set_color("font_color", "TooltipLabel", PRIMARY)
	ui.set_font_size("font_size", "TooltipLabel", 12)
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
	var style := _style(Color(1, 1, 1, 0.04) if active else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	style.set_border_width_all(0)
	style.border_color = PRIMARY
	style.border_width_bottom = 1 if active else 0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", PRIMARY if active else MUTED)

func _title(text: String, font_size: int = 48, tracking: int = 3) -> Label:
	var label := _label(text, font_size, INK, true)
	var spaced := FontVariation.new()
	spaced.base_font = heavy
	spaced.spacing_glyph = tracking
	label.add_theme_font_override("font", spaced)
	return label

func _icon_button(icon: String, hint: String, action: Callable, icon_size: int = 28, hit_size: int = 48) -> Button:
	var button := _button("", action, Vector2(hit_size, hit_size))
	button.icon = load("res://assets/icons/" + icon + ".svg")
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.tooltip_text = hint
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return button

func _back_button(action: Callable) -> Button:
	var button := _icon_button("arrow-back-circle-outline", "返回", action, 32)
	button.position = Vector2(24, 24)
	add_child(button)
	return button

func enter(reduced: bool) -> void:
	if entrance != null and entrance.is_running():
		entrance.kill()
	modulate.a = 1.0
	if not reduced:
		modulate.a = 0.0
		entrance = create_tween()
		entrance.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
