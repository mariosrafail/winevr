shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 dark_green : source_color = vec3(0.040, 0.145, 0.018);
uniform vec3 sun_green : source_color = vec3(0.20, 0.36, 0.050);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform bool use_pbr_textures = false;
uniform vec3 texture_tint : source_color = vec3(0.72, 0.90, 0.62);
uniform float emission_strength : hint_range(0.0, 0.5) = 0.10;
uniform vec2 wind_direction = vec2(0.85, 0.32);
uniform float wind_strength : hint_range(0.0, 0.10) = 0.028;
uniform float wind_speed : hint_range(0.1, 3.0) = 0.75;
uniform float object_scale_hint : hint_range(0.1, 20.0) = 1.0;

varying vec3 world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wd = normalize(wind_direction);
	float phase = world_pos.x * 0.75 + world_pos.z * 0.52;
	float gust = sin(TIME * wind_speed + phase) * 0.72
		+ sin(TIME * wind_speed * 2.21 + phase * 1.7) * 0.28;
	float height_mask = smoothstep(0.08 * object_scale_hint, 1.1 * object_scale_hint, max(VERTEX.y, 0.0));
	VERTEX.x += wd.x * gust * wind_strength * (0.35 + 0.65 * height_mask);
	VERTEX.z += wd.y * gust * wind_strength * (0.35 + 0.65 * height_mask);
}

void fragment() {
	float variation = hash31(floor(world_pos * 1.6));
	float sun_patch = 0.5 + 0.5 * sin(world_pos.x * 0.75 + world_pos.z * 0.48);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (use_pbr_textures) {
		vec3 base = texture(albedo_texture, UV).rgb;
		float light_variation = 0.84 + variation * 0.20 + sun_patch * 0.08;
		ALBEDO = base * texture_tint * light_variation;
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = 0.52;
		ROUGHNESS = clamp(texture(roughness_texture, UV).r * 1.04, 0.48, 0.92);
	} else {
		ALBEDO = mix(dark_green, sun_green, clamp(variation * 0.62 + sun_patch * 0.28, 0.0, 1.0));
		ROUGHNESS = 0.78 + variation * 0.12;
	}
	EMISSION = ALBEDO * emission_strength;
	SPECULAR = 0.20;
}
