shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D pulp_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 flesh_tint=vec3(1.0);
uniform float selected=0.0;

void fragment() {
    vec3 tissue=texture(pulp_albedo, UV * 1.8).rgb;
    vec2 p=(UV-0.5)*2.0;
    float locule=min(length((p-vec2(-0.205,-0.12))/vec2(0.17,0.31)),
                     length((p-vec2(0.205,-0.12))/vec2(0.17,0.31)));
    float membrane=1.0-smoothstep(0.68,1.12,locule);
    vec3 flesh=tissue*vec3(0.70,0.81,0.92)*flesh_tint;
    ALBEDO=mix(flesh,flesh*vec3(0.76,0.81,0.65),membrane*0.36)*(1.0+selected*0.025);
    ROUGHNESS=mix(0.29,0.20,membrane);
    SPECULAR=0.36;
    BACKLIGHT=ALBEDO*vec3(0.09,0.13,0.045);
    float height=dot(tissue,vec3(0.2126,0.7152,0.0722))*0.000006;
    vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
    vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
    float det=dot(dx,r1);
    NORMAL=normalize(NORMAL-(dFdx(height)*r1+dFdy(height)*r2)*sign(det)/max(abs(det),0.00000001));
}
