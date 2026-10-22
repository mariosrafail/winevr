shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float selected=0.0;
void fragment() {
    float fibers=sin(UV.x*210.0+sin(UV.y*35.0)*1.4)*0.5+0.5;
    float fine=fract(sin(dot(floor(UV*420.0),vec2(12.9898,78.233)))*43758.5453);
    vec3 testa=mix(vec3(0.16,0.069,0.022),vec3(0.30,0.16,0.057),UV.y);
    ALBEDO=testa*mix(0.91,1.04,fibers)*(1.0+selected*0.05);
    ROUGHNESS=0.31+fibers*0.055+(fine-0.5)*0.018;
    SPECULAR=0.32;
}
