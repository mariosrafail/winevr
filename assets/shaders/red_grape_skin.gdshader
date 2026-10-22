shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 texture_offset = vec2(0.0);
uniform vec3 skin_tint = vec3(1.0);
uniform vec3 skin_base = vec3(0.105, 0.065, 0.09);

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float skin_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
    vec2 skin_uv = UV * vec2(1.0, 0.75) + texture_offset;
    vec3 skin = texture(skin_albedo, skin_uv).rgb;
    float wax = smoothstep(0.24, 0.78, skin_noise(skin_uv * 8.0));
    float grain = skin_noise(skin_uv * 380.0);
    // Preserve the variety's red-purple or blue-black skin. The thin wax film
    // changes sheen rather than painting large opaque white patches on it.
    ALBEDO = mix(mix(skin * skin_tint * 0.82, skin_base, 0.20), vec3(0.17, 0.18, 0.22), wax * 0.035);
    METALLIC = 0.0;
    SPECULAR = 0.28;
    ROUGHNESS = clamp(mix(0.36, 0.58, wax) + (grain - 0.5) * 0.03, 0.35, 0.60);
    BACKLIGHT = ALBEDO * vec3(0.018, 0.006, 0.012) * (1.0 - wax * 0.45);

    // Fine skin relief in view-space, with no vertex displacement or changes
    // to the rig, berry silhouettes or contact surfaces.
    float height = dot(skin, vec3(0.2126, 0.7152, 0.0722)) * 0.000003 + grain * 0.0000002;
    vec3 dpdx = dFdx(VERTEX);
    vec3 dpdy = dFdy(VERTEX);
    vec3 r1 = cross(dpdy, NORMAL);
    vec3 r2 = cross(NORMAL, dpdx);
    float determinant = dot(dpdx, r1);
    vec3 gradient = (dFdx(height) * r1 + dFdy(height) * r2) * sign(determinant) / max(abs(determinant), 0.00000001);
    NORMAL = normalize(NORMAL - gradient);
}
