shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec2 forearm_bend = vec2(0.0);
uniform float forearm_length = 1.0;

void vertex() {
	// Leave the palm/finger rig untouched. Distribute a small wrist bend over
	// the forearm, using the same centreline as the opening of the sleeve.
	float original_along = max(VERTEX.z - 0.035, 0.0);
	float length_scale = VERTEX.z > 0.035 ? forearm_length : 1.0;
	float along = original_along * length_scale;
	VERTEX.z -= original_along - along;
	vec2 slope = forearm_bend * along / 0.18;
	VERTEX.xy += forearm_bend * along * along / 0.36;
	NORMAL = normalize(vec3(NORMAL.xy, NORMAL.z / length_scale - dot(NORMAL.xy, slope)));
	TANGENT = normalize(vec3(TANGENT.xy + slope * length_scale * TANGENT.z, TANGENT.z * length_scale));
	BINORMAL = normalize(vec3(BINORMAL.xy + slope * length_scale * BINORMAL.z, BINORMAL.z * length_scale));
}

// UV2 and COLOR.a carry the undeformed anatomical coordinates. They remain
// attached to the skin as the skeleton bends, unlike a world-space noise field.
float band(float distance, float width) {
	float q = distance / width;
	return exp(-q * q);
}

vec2 finger_detail(vec2 p, float x, float root, float middle, float distal) {
	float finger = band(p.x - x, 0.008) * (1.0 - smoothstep(root, root + 0.006, p.y));
	float joints = max(band(p.y - middle, 0.005), band(p.y - distal, 0.004));
	joints = max(joints, band(p.y - root + 0.003, 0.007));
	float crease = band(p.y - middle, 0.0008) + band(p.y - distal, 0.0007);
	crease += 0.40 * (band(p.y - middle - 0.0025, 0.00055) + band(p.y - distal - 0.002, 0.0005));
	return vec2(joints, crease) * finger;
}

void fragment() {
	vec2 p = UV2;
	// The shortened desktop forearm ends inside the cuff. Do not render its
	// concealed continuation through cloth when the sleeve curves away.
	if (forearm_length < 0.99 && p.y > 0.216) {
		discard;
	}
	float y = COLOR.a * 0.10 - 0.05;
	float palm = smoothstep(-0.002, 0.008, y);
	float back = 1.0 - smoothstep(-0.008, 0.002, y);
	float hand = 1.0 - smoothstep(0.055, 0.095, p.y);
	vec2 detail = finger_detail(p, -0.030, -0.037, -0.078, -0.103);
	detail += finger_detail(p, -0.009, -0.043, -0.089, -0.117);
	detail += finger_detail(p, 0.013, -0.039, -0.082, -0.108);
	detail += finger_detail(p, 0.032, -0.028, -0.061, -0.082);
	float palm_region = smoothstep(-0.042, -0.028, p.y) * (1.0 - smoothstep(0.042, 0.061, p.y));
	float palm_lines = band(p.y + 0.018 - p.x * 0.20 + 0.0007 * sin(p.x * 130.0), 0.00085);
	palm_lines += band(p.y - 0.012 + p.x * 0.42 + 0.0005 * sin(p.x * 180.0), 0.0008);
	// The thenar crease curves around the thumb pad instead of crossing it.
	float life_line = band(p.x + 0.021 - 0.012 * cos((p.y - 0.009) * 54.0), 0.0008);
	palm_lines += life_line * smoothstep(-0.014, -0.005, p.y);
	float creases = clamp(detail.y * mix(0.45, 1.0, palm) + palm_lines * palm_region * palm, 0.0, 1.6);
	float knuckles = clamp(detail.x * back, 0.0, 1.0);
	float thenar = band(length((p - vec2(-0.023, 0.020)) * vec2(1.0, 0.67)), 0.021) * palm;
	float palm_edge = band(p.x - 0.027, 0.013) * palm * palm_region;
	float pads = COLOR.r;
	float mottling = COLOR.g;
	float veins = COLOR.b * back;
	vec3 color = texture(skin_albedo, UV).rgb;
	color *= vec3(1.0, 0.97, 0.945);
	float blood_colour = clamp(pads * 0.90 + knuckles * 0.78 + thenar * 0.50 + palm_edge * 0.50 + palm * hand * 0.10, 0.0, 1.0);
	color *= mix(vec3(1.0), vec3(1.08, 0.83, 0.80), blood_colour);
	color *= 1.0 + (mottling - 0.5) * 0.14;
	color *= mix(vec3(1.0), vec3(0.89, 0.96, 0.99), veins * 0.70);
	color *= mix(vec3(1.0), vec3(0.77, 0.65, 0.60), creases * 0.48);
	ALBEDO = color;
	METALLIC = 0.0;
	SPECULAR = 0.28;
	ROUGHNESS = clamp(0.57 + palm * 0.07 + knuckles * 0.055 + (mottling - 0.5) * 0.055 - pads * 0.025, 0.52, 0.71);
	NORMAL_MAP = texture(skin_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.55;
}
