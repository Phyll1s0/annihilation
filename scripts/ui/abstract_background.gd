extends ColorRect
## A quiet, texture-free field keeps attention on particles and disappearing space.
var settings

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 canvas_size = vec2(1280.0, 820.0);
void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	p.x *= canvas_size.x / canvas_size.y;
	float light = exp(-dot(p, p) * 3.2) * 0.018;
	COLOR = vec4(vec3(0.063, 0.071, 0.082) + light, 1.0);
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	resized.connect(func(): material.set_shader_parameter("canvas_size", size))
	material.set_shader_parameter("canvas_size", size)
