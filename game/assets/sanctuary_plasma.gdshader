shader_type spatial;
render_mode unshaded, cull_back;
// Opaque, depth-tested energy; no refraction, alpha blend or light/shadow pass.
void fragment() {
 vec2 p=UV*2.0-1.0;
 float radius=length(p);
 float wave=sin(p.y*9.0+TIME*0.55)*0.10;
 float filament=pow(max(0.0,1.0-abs(p.x+wave)*7.5),3.0);
 float halo=1.0-smoothstep(0.015,0.06,abs(radius-0.76));
 float pulse=0.86+0.14*sin(TIME*0.75+p.y*5.0);
 float energy=(filament*0.80+halo*0.55)*pulse*(1.0-smoothstep(0.88,1.0,radius));
 ALBEDO=vec3(0.025,0.045,0.040)+vec3(0.055,0.72,0.20)*energy;
 EMISSION=vec3(0.08,0.85,0.28)*energy*1.35;
}
