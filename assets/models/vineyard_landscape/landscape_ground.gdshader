shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_a : source_color = vec3(0.12, 0.15, 0.035);
uniform vec3 grass_b : source_color = vec3(0.23, 0.20, 0.055);
uniform vec3 earth : source_color = vec3(0.17, 0.085, 0.025);

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
	float n = hash21(floor(world_pos.xz * 1.25));
	float fine = hash21(floor(world_pos.xz * 21.0));
	float broad = 0.5 + 0.5 * sin(world_pos.x * 0.31 + world_pos.z * 0.17);
	vec3 grass = mix(grass_a, grass_b, broad * 0.65 + n * 0.35);
	float dry_patch = smoothstep(0.70, 0.94, hash21(floor(world_pos.xz * 0.36 + 7.0)));
	ALBEDO = mix(grass, earth, dry_patch * 0.42);
	ROUGHNESS = 0.90 + fine * 0.08;
	SPECULAR = 0.10;
	NORMAL_MAP = vec3(
		0.5 + (fine - 0.5) * 0.09,
		0.5 + (n - 0.5) * 0.06,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.30;
}
