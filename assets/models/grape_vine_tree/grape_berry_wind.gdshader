shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grape_deep : source_color = vec3(0.030, 0.008, 0.060);
uniform vec3 grape_mid : source_color = vec3(0.095, 0.022, 0.145);
uniform vec3 bloom_tint : source_color = vec3(0.34, 0.38, 0.47);
uniform vec2 wind_direction = vec2(0.86, 0.34);
uniform float wind_strength : hint_range(0.0, 0.05) = 0.010;
uniform float wind_speed : hint_range(0.1, 4.0) = 0.95;

varying vec3 grape_world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	grape_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wd = normalize(wind_direction);
	float cluster_phase = grape_world_pos.x * 2.7 + grape_world_pos.z * 1.9;
	float sway = sin(TIME * wind_speed + cluster_phase) * 0.72
		+ sin(TIME * wind_speed * 1.73 + cluster_phase * 1.41) * 0.28;
	float flex = smoothstep(0.95, 2.25, VERTEX.y);
	VERTEX.x += wd.x * sway * wind_strength * (0.45 + flex * 0.55);
	VERTEX.z += wd.y * sway * wind_strength * (0.45 + flex * 0.55);
}

void fragment() {
	float pigment = hash31(floor(grape_world_pos * 24.0));
	float fine = hash31(grape_world_pos * 83.0);
	float bloom = smoothstep(0.42, 0.80, fine) * (0.22 + pigment * 0.20);
	vec3 skin = mix(grape_deep, grape_mid, 0.28 + pigment * 0.58);
	ALBEDO = mix(skin, bloom_tint, bloom * 0.24);
	ROUGHNESS = clamp(0.46 + bloom * 0.34 + (fine - 0.5) * 0.08, 0.40, 0.82);
	SPECULAR = 0.34;
	NORMAL_MAP = vec3(
		0.5 + (fine - 0.5) * 0.055,
		0.5 + (pigment - 0.5) * 0.045,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.28;
}
