shader_type spatial;
// Two shared mipmapped samples; world coordinates keep texel scale across merged meshes.
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(.4,.4,.4,1.0);
uniform vec4 accent_color : source_color = vec4(.2,.3,.2,1.0);
uniform float surface_kind = 0.0; // soil=0, panel=1, bark=2, foliage=3
uniform float metalness = 0.0;
uniform bool low_detail = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 vec3 n=normalize(world_normal);vec3 p=world_position;
 vec2 uv=abs(n.y)>.6?p.xz:(abs(n.x)>.6?p.zy:p.xy);
 vec2 texture_uv=surface_kind>1.5 && surface_kind<2.5?uv*vec2(.8,.07):uv*.18;
 float broad=texture(noise_texture,texture_uv).r;
 float grain=low_detail?broad:texture(noise_texture,uv*2.2).r;
 float blend=smoothstep(.15,.85,broad);
 if(surface_kind>.5 && surface_kind<1.5)blend=.35+(blend-.5)*.18;
 vec3 color=mix(base_color.rgb,accent_color.rgb,blend);
 float relief=.84+.16*max(0.0,dot(n,normalize(vec3(-.5,.85,.3))));
 color*=relief*(.94+grain*.12);
 if(surface_kind>.5 && surface_kind<1.5){
  vec2 grid=abs(fract(uv/vec2(3.0,1.5))-.5);
  float seam=smoothstep(.477,.497,max(grid.x,grid.y));
  color*=1.0-seam*.36;
 }else if(surface_kind>1.5 && surface_kind<2.5){
  float ridges=sin(uv.x*24.0+broad*9.0+sin(p.y*.7));
  color*=.84+.16*smoothstep(-.7,.5,ridges);
 }else if(surface_kind>2.5){color*=.94+grain*.06;}
 ALBEDO=color;ROUGHNESS=clamp(.9-metalness*.45+grain*.08,0.0,1.0);METALLIC=metalness;
}
