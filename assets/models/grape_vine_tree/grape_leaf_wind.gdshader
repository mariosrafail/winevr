shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;

uniform vec2 wind_direction = vec2(0.86, 0.34);
uniform float wind_strength : hint_range(0.0, 0.12) = 0.038;
uniform float wind_speed : hint_range(0.1, 4.0) = 1.15;
uniform float flutter_strength : hint_range(0.0, 0.08) = 0.016;
uniform vec3 leaf_tint : source_color = vec3(0.50, 0.74, 0.40);

varying float wind_lighting;

float gust_noise(vec3 p, float t) {
	float broad = sin(t * 0.92 + p.x * 1.45 + p.z * 0.78);
	float detail = sin(t * 2.37 + p.x * 4.1 - p.z * 2.65) * 0.30;
	float micro = sin(t * 4.15 + p.x * 7.8 + p.y * 2.2) * 0.12;
	return broad * 0.68 + detail + micro;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wd = normalize(wind_direction);
	float t = TIME * wind_speed;
	float gust = gust_noise(wp, t);
	float canopy_mask = smoothstep(0.72, 1.95, VERTEX.y);
	float local_flutter = sin(t * 3.1 + wp.x * 8.2 + wp.z * 6.4);

	VERTEX.x += wd.x * gust * wind_strength * (0.38 + canopy_mask * 0.62);
	VERTEX.z += wd.y * gust * wind_strength * (0.38 + canopy_mask * 0.62);
	VERTEX.y += local_flutter * flutter_strength * (0.35 + canopy_mask * 0.65);
	wind_lighting = gust;
}

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	vec3 normal_tex = texture(normal_texture, UV).rgb;
	float rough_tex = texture(roughness_texture, UV).r;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = base.rgb * leaf_tint * (1.0 + wind_lighting * 0.018);
	NORMAL_MAP = normal_tex;
	NORMAL_MAP_DEPTH = 0.62;
	ROUGHNESS = clamp(rough_tex * 1.04, 0.48, 0.88);
	SPECULAR = 0.27;
}
