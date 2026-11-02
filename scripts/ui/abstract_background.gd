extends ColorRect
## Reuses Neutronic's three screen-blended, horizontally scrolling dot-grid layers.
var settings
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D layer_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D layer_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D layer_c : repeat_enable, filter_linear_mipmap;
uniform vec2 canvas_size = vec2(1280.0, 820.0);
uniform float motion_time = 0.0;
void fragment() {
	vec2 p = UV * canvas_size;
	vec3 c = vec3(0.10588235);
	vec3 a = texture(layer_a, p / 800.0 + vec2(motion_time / 40.0 * 2.0, 0.0)).rgb * 0.30;
	vec3 b = texture(layer_b, p / 640.0 + vec2(motion_time / 60.0 * 2.0, 0.0)).rgb * 0.20;
	vec3 d = texture(layer_c, p / 640.0 + vec2(motion_time / 80.0 * 2.0, 0.0)).rgb * 0.20;
	c = 1.0 - (1.0 - c) * (1.0 - a);
	c = 1.0 - (1.0 - c) * (1.0 - b);
	c = 1.0 - (1.0 - c) * (1.0 - d);
	COLOR = vec4(c, 1.0);
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	for i in 3:
		shader_material.set_shader_parameter(["layer_a", "layer_b", "layer_c"][i], load("res://assets/background/dotgrid-%d.webp" % i))
	material = shader_material
	resized.connect(func(): material.set_shader_parameter("canvas_size", size))
	material.set_shader_parameter("canvas_size", size)

func _process(delta: float) -> void:
	if settings == null or not settings.reduce_motion:
		elapsed += delta
		material.set_shader_parameter("motion_time", elapsed)
