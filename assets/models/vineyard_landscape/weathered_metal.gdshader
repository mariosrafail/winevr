shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 metal_dark : source_color = vec3(0.12, 0.13, 0.13);
uniform vec3 metal_light : source_color = vec3(0.38, 0.40, 0.39);
uniform vec3 rust_color : source_color = vec3(0.24, 0.095, 0.028);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.78;

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
	float weather = hash31(floor(world_pos * 18.0));
	float fine = hash31(floor(world_pos * 55.0 + 11.0));
	float rust = smoothstep(0.82, 0.97, weather) * smoothstep(0.48, 0.95, fine);
	vec3 steel = mix(metal_dark, metal_light, 0.28 + weather * 0.44);
	ALBEDO = mix(steel, rust_color, rust * 0.65);
	METALLIC = metallic_amount * (1.0 - rust * 0.72);
	ROUGHNESS = 0.42 + weather * 0.20 + rust * 0.24;
	SPECULAR = 0.32;
}
