shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wood_dark : source_color = vec3(0.15, 0.060, 0.020);
uniform vec3 wood_light : source_color = vec3(0.39, 0.185, 0.055);

varying vec3 world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stave_cell = fract(UV.x * 18.0);
	float stave_id = floor(UV.x * 18.0);
	float stave_variation = hash31(vec3(stave_id, 3.0, 7.0));
	float seam_distance = min(stave_cell, 1.0 - stave_cell);
	float seam = 1.0 - smoothstep(0.018, 0.055, seam_distance);
	float grain = 0.5 + 0.5 * sin(UV.y * 115.0 + sin(UV.x * 37.0) * 2.2 + world_pos.x * 2.0);
	float weather = hash31(floor(world_pos * 7.0));
	float tone = clamp(grain * 0.23 + weather * 0.57 + stave_variation * 0.20, 0.0, 1.0);
	vec3 wood = mix(wood_dark, wood_light, 0.25 + tone * 0.62);
	ALBEDO = mix(wood, wood_dark * 0.38, seam * 0.72);
	ROUGHNESS = 0.70 + weather * 0.18;
	SPECULAR = 0.18;
	NORMAL_MAP = vec3(
		0.5 + (grain - 0.5) * 0.055,
		0.5 + (weather - 0.5) * 0.035,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.26;
}
