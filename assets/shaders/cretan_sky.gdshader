shader_type sky;

// Static cloud field: radiance can remain cached on mobile and standalone XR.
uniform vec3 zenith_color : source_color = vec3(0.20, 0.42, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.80, 0.83);
uniform vec3 cloud_light : source_color = vec3(0.97, 0.96, 0.88);
uniform vec3 cloud_shade : source_color = vec3(0.69, 0.77, 0.80);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	float density = noise21(p) * 0.54;
	density += noise21(p * 2.03 + 8.17) * 0.27;
	density += noise21(p * 4.13 + 3.40) * 0.13;
	density += noise21(p * 8.31 + 11.27) * 0.06;
	return density;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 color = mix(horizon_color, zenith_color, pow(elevation, 0.38));
	if (direction.y > 0.01) {
		vec2 cloud_uv = direction.xz / (elevation + 0.18) * 1.8 + vec2(7.5, 4.4);
		float density = cloud_noise(cloud_uv);
		float cloud = smoothstep(0.53, 0.72, density);
		cloud *= smoothstep(0.025, 0.15, elevation) * (1.0 - smoothstep(0.75, 0.98, elevation));
		float shading = smoothstep(0.48, 0.75, cloud_noise(cloud_uv + vec2(0.16, -0.21)));
		color = mix(color, mix(cloud_shade, cloud_light, shading), cloud * 0.85);
		if (LIGHT0_ENABLED) {
			float sun_alignment = max(dot(direction, LIGHT0_DIRECTION), 0.0);
			color += vec3(0.15, 0.10, 0.035) * pow(sun_alignment, 22.0);
			color += vec3(1.0, 0.85, 0.60) * smoothstep(0.99992, 0.99997, sun_alignment) * 2.0;
		}
	}
	if (direction.y < 0.0) {
		color = mix(horizon_color, vec3(0.16, 0.19, 0.15), smoothstep(0.0, 0.35, -direction.y));
	}
	COLOR = color;
}
