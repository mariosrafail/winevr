shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

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
    // Each berry samples a different part of the seamless scanned-style skin.
    vec2 skin_uv = UV * vec2(1.0, 0.75) + UV2;
    vec3 scan = texture(skin_albedo, skin_uv).rgb;
    float wax = smoothstep(0.25, 0.77, skin_noise(skin_uv * 9.0));
    float grain = skin_noise(skin_uv * 380.0);
    vec3 tint = clamp(COLOR.rgb / vec3(0.32, 0.36, 0.16), vec3(0.86), vec3(1.10));
    vec3 skin = scan * vec3(0.57, 0.67, 0.71) * tint;
    ALBEDO = mix(skin, vec3(0.34, 0.39, 0.25), wax * 0.085);

    // Dry wax breaks up the highlight; exposed skin keeps a softer satin sheen.
    METALLIC = 0.0;
    SPECULAR = 0.25;
    ROUGHNESS = clamp(mix(0.41, 0.67, wax) + (grain - 0.5) * 0.035, 0.40, 0.69);
    // Subtle light through the flesh, strongest where wax is thinner.
    BACKLIGHT = ALBEDO * vec3(0.045, 0.065, 0.02) * (1.0 - wax * 0.45);

    // Micron-scale skin relief, using surface derivatives rather than a glossy
    // smooth sphere or displacement that could change berry contact geometry.
    float height = dot(scan, vec3(0.2126, 0.7152, 0.0722)) * 0.000012 + grain * 0.0000005;
    vec3 dpdx = dFdx(VERTEX);
    vec3 dpdy = dFdy(VERTEX);
    vec3 r1 = cross(dpdy, NORMAL);
    vec3 r2 = cross(NORMAL, dpdx);
    float determinant = dot(dpdx, r1);
    vec3 gradient = (dFdx(height) * r1 + dFdy(height) * r2) * sign(determinant) / max(abs(determinant), 0.00000001);
    NORMAL = normalize(NORMAL - gradient);
}
