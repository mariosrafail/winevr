shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone_color : source_color = vec4(0.23, 0.22, 0.19, 1.0);
uniform float grain_scale = 34.0;
uniform float tile_scale = 0.0;
varying vec3 world_position;
float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
                   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float n = noise(world_position * grain_scale);
    float cloud = noise(world_position * 2.8);
    ALBEDO = stone_color.rgb * (0.86 + n * 0.10 + cloud * 0.18);
    if (tile_scale > 0.0) {
        vec2 q = abs(fract(world_position.xz * tile_scale) - 0.5);
        float seam = smoothstep(0.487, 0.497, max(q.x, q.y));
        ALBEDO *= 1.0 - seam * 0.52;
    }
    ROUGHNESS = 0.68 + n * 0.16;
    SPECULAR = 0.28;
}
