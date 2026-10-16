shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 bark_dark : source_color = vec3(0.060, 0.026, 0.010);
uniform vec3 bark_light : source_color = vec3(0.205, 0.095, 0.030);
uniform vec2 wind_direction = vec2(0.86, 0.34);
uniform float branch_sway : hint_range(0.0, 0.03) = 0.006;
uniform float wind_speed : hint_range(0.1, 4.0) = 0.80;

varying vec3 bark_world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	bark_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wd = normalize(wind_direction);
	float flex = smoothstep(1.12, 2.18, VERTEX.y);
	float sway = sin(TIME * wind_speed + bark_world_pos.x * 1.5 + bark_world_pos.z) * branch_sway * flex;
	VERTEX.x += wd.x * sway;
	VERTEX.z += wd.y * sway;
}

void fragment() {
	float vertical_ridge = 0.5 + 0.5 * sin(bark_world_pos.y * 34.0 + bark_world_pos.x * 11.0);
	float breakup = hash31(floor(bark_world_pos * vec3(18.0, 7.0, 18.0)));
	float tone = clamp(vertical_ridge * 0.34 + breakup * 0.66, 0.0, 1.0);
	ALBEDO = mix(bark_dark, bark_light, 0.18 + tone * 0.62);
	ROUGHNESS = 0.79 + breakup * 0.13;
	SPECULAR = 0.18;
	float fine_ridge = sin(bark_world_pos.y * 72.0 + bark_world_pos.x * 21.0 + breakup * 2.8);
	NORMAL_MAP = vec3(
		0.5 + fine_ridge * 0.10,
		0.5 + (breakup - 0.5) * 0.08,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.48;
}
