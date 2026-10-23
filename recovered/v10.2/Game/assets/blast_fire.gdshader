shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;
uniform float age=0.0;
void fragment() {
 float rim=1.0-abs(dot(normalize(NORMAL),normalize(VIEW)));
 float flicker=.8+.2*sin(UV.y*32.0+UV.x*19.0+age*35.0);
 vec3 color=mix(vec3(1.0,.92,.58),vec3(1.0,.18,.035),clamp(age*2.5+rim*.45,0.0,1.0));
 ALBEDO=color*1.8;
 ALPHA=clamp((1.0-smoothstep(.12,.65,age))*flicker,0.0,.92);
}
