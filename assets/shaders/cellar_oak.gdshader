shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 oak_dark : source_color = vec3(0.20, 0.11, 0.055);
uniform vec3 oak_light : source_color = vec3(0.52, 0.34, 0.17);
varying vec3 local_position;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void vertex() { local_position = VERTEX; }
void fragment() {
	float stave = floor(UV.x * 26.0);
	float v = hash21(vec2(stave, 9.0));
	float seam_cell = fract(UV.x * 26.0);
	float seam = 1.0 - smoothstep(0.006, 0.03, min(seam_cell, 1.0 - seam_cell));
	float grain = 0.5 + 0.5 * sin(UV.x * 2100.0 + sin(UV.y * 18.0 + v * 7.0) * 3.5);
	grain = mix(0.5, grain, 1.0 - smoothstep(0.5, 2.0, fwidth(UV.x) * 2100.0));
	float pores = hash21(floor(UV * vec2(720.0, 310.0)));
	ALBEDO = mix(oak_dark, oak_light, 0.32 + v * 0.27 + grain * 0.13 + pores * 0.09) * (1.0 - seam * 0.65);
	ROUGHNESS = 0.69 + pores * 0.16;
	SPECULAR = 0.24;
	NORMAL_MAP = vec3(0.5 + (grain - 0.5) * 0.065, 0.5 + (pores - 0.5) * 0.025, 1.0);
	NORMAL_MAP_DEPTH = 0.35;
}
