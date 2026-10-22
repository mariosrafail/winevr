shader_type spatial;
render_mode diffuse_burley;
uniform vec3 hillside_color : source_color = vec3(0.35, 0.40, 0.30);
varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 f = fract(p);
	vec2 i = floor(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float folds = noise21(world_position.xz * 0.23) * 0.65 + noise21(world_position.xz * 0.73) * 0.35;
	float limestone = smoothstep(0.57, 0.82, folds);
	ALBEDO = mix(hillside_color * (0.78 + folds * 0.34), hillside_color * 1.25, limestone * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
