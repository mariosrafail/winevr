shader_type spatial;
render_mode unshaded;

uniform vec3 hill_shadow : source_color = vec3(0.26, 0.23, 0.115);
uniform vec3 hill_haze : source_color = vec3(0.54, 0.38, 0.18);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float height = smoothstep(-2.0, 12.0, world_pos.y);
	float haze = 0.46 + 0.24 * height;
	ALBEDO = mix(hill_shadow, hill_haze, haze);
}
