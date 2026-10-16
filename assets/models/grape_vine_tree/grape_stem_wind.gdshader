shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 stem_dark : source_color = vec3(0.075, 0.105, 0.018);
uniform vec3 stem_light : source_color = vec3(0.22, 0.30, 0.055);
uniform vec2 wind_direction = vec2(0.86, 0.34);
uniform float wind_strength : hint_range(0.0, 0.04) = 0.010;
uniform float wind_speed : hint_range(0.1, 4.0) = 0.95;

varying vec3 stem_world_pos;

void vertex() {
	stem_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wd = normalize(wind_direction);
	float phase = stem_world_pos.x * 2.8 + stem_world_pos.z * 2.1;
	float sway = sin(TIME * wind_speed + phase) * wind_strength;
	VERTEX.x += wd.x * sway;
	VERTEX.z += wd.y * sway;
}

void fragment() {
	float var = 0.5 + 0.5 * sin(stem_world_pos.y * 21.0 + stem_world_pos.x * 7.0);
	ALBEDO = mix(stem_dark, stem_light, 0.30 + 0.45 * var);
	ROUGHNESS = 0.78;
	SPECULAR = 0.20;
}
