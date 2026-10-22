shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 fabric_color : source_color = vec4(0.172, 0.221, 0.196, 1.0);

void fragment() {
	// The weave fades below one pixel to keep moving sleeves free of shimmer.
	vec2 weave_uv = UV * vec2(110.0, 460.0);
	float resolved = 1.0 - smoothstep(0.30, 0.85, max(fwidth(weave_uv.x), fwidth(weave_uv.y)));
	float weave = sin(weave_uv.x * 6.2831853) * sin(weave_uv.y * 6.2831853) * resolved;
	float yarn = sin(UV.x * 62.83185 + sin(UV.y * 21.0)) * 0.012;
	ALBEDO = fabric_color.rgb * (1.0 + weave * 0.045 + yarn);
	ROUGHNESS = 0.94;
	SPECULAR = 0.22;
}
