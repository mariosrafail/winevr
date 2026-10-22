shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 oak_dark : source_color = vec3(0.18, 0.10, 0.045);
uniform vec3 oak_light : source_color = vec3(0.44, 0.29, 0.14);
varying vec3 local_position;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void vertex() { local_position = VERTEX; }
void fragment() {
	vec2 p = local_position.xz;
	float board = fract((p.y + 0.04) * 8.0);
	float seam = 1.0 - smoothstep(0.004, 0.016, min(board, 1.0 - board));
	float grain = 0.5 + 0.5 * sin(p.y * 260.0 + sin(p.x * 9.0) * 1.7);
	grain = mix(0.5, grain, 1.0 - smoothstep(0.5, 2.0, fwidth(p.y) * 260.0));
	float pores = hash21(floor(p * 220.0));
	float board_tone = hash21(vec2(floor((p.y + 0.04) * 8.0), 3.0));
	ALBEDO = mix(oak_dark, oak_light, 0.38 + board_tone * 0.2 + grain * 0.18 + pores * 0.08) * (1.0 - seam * 0.34);
	ROUGHNESS = 0.69 + pores * 0.15;
	SPECULAR = 0.24;
	NORMAL_MAP = vec3(0.5, 0.5 + (grain - 0.5) * 0.05, 1.0);
	NORMAL_MAP_DEPTH = 0.22;
}
