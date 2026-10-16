shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 bark_dark : source_color = vec3(0.080, 0.035, 0.012);
uniform vec3 bark_light : source_color = vec3(0.28, 0.125, 0.035);

varying vec3 world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broken = hash31(floor(world_pos * vec3(7.0, 15.0, 7.0)));
	float ridge = 0.5 + 0.5 * sin(world_pos.y * 15.0 + world_pos.x * 2.7);
	float tone = clamp(broken * 0.68 + ridge * 0.32, 0.0, 1.0);
	ALBEDO = mix(bark_dark, bark_light, 0.18 + tone * 0.62);
	ROUGHNESS = 0.82 + broken * 0.12;
	SPECULAR = 0.14;
	NORMAL_MAP = vec3(
		0.5 + (ridge - 0.5) * 0.12,
		0.5 + (broken - 0.5) * 0.08,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.42;
}
