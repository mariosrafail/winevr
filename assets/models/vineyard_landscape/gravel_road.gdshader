shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 gravel_dark : source_color = vec3(0.075, 0.060, 0.045);
uniform vec3 gravel_light : source_color = vec3(0.22, 0.18, 0.13);
uniform vec3 dust : source_color = vec3(0.30, 0.23, 0.15);

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float coarse = hash21(floor(world_pos.xz * 8.0));
	float pebble = hash21(floor(world_pos.xz * 34.0 + 13.0));
	float dust_patch = smoothstep(0.62, 0.92, hash21(floor(world_pos.xz * 0.9)));
	vec3 stone = mix(gravel_dark, gravel_light, coarse * 0.72 + pebble * 0.28);
	ALBEDO = mix(stone, dust, dust_patch * 0.32);
	ROUGHNESS = 0.90 + pebble * 0.08;
	SPECULAR = 0.08;
	NORMAL_MAP = vec3(
		0.5 + (pebble - 0.5) * 0.18,
		0.5 + (coarse - 0.5) * 0.13,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.48;
}
