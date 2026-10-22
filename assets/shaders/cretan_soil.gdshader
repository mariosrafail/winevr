shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_a : source_color = vec3(0.37, 0.37, 0.21);
uniform vec3 grass_b : source_color = vec3(0.54, 0.46, 0.29);
uniform vec3 earth : source_color = vec3(0.47, 0.35, 0.22);
varying vec3 terrain_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	terrain_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = terrain_world.xz;
	float broad = noise21(p * 0.22) * 0.65 + noise21(p * 0.78) * 0.35;
	float grain = noise21(p * 24.0);
	float dry = smoothstep(0.33, 0.76, broad);
	vec3 base = mix(grass_a, grass_b, broad);
	base = mix(base, earth, dry * 0.58);
	float limestone = smoothstep(0.79, 0.92, grain) * 0.26;
	ALBEDO = mix(base * (0.87 + grain * 0.24), vec3(0.68, 0.63, 0.50), limestone);
	ROUGHNESS = 0.91 + grain * 0.08;
	SPECULAR = 0.13;
	NORMAL_MAP = vec3(0.5 + (grain - 0.5) * 0.13, 0.5 + (noise21(p * 31.0 + 4.0) - 0.5) * 0.13, 1.0);
	NORMAL_MAP_DEPTH = 0.42;
}
