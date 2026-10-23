shader_type spatial;
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool textured=false;
uniform float surface_roughness=.5;
uniform float surface_metallic=0.0;
uniform vec3 glow : source_color=vec3(0.0);
uniform int body_count=0;
uniform mat4 body_inverse[17];
uniform vec3 body_half[17];
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 for(int i=0;i<17;i++){
  if(i>=body_count)break;
  vec3 start=(body_inverse[i]*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
  vec3 finish=(body_inverse[i]*vec4(world_position,1.0)).xyz;
  vec3 d=finish-start;
  d=vec3(abs(d.x)<0.000001?0.000001:d.x,abs(d.y)<0.000001?0.000001:d.y,abs(d.z)<0.000001?0.000001:d.z);
  vec3 a=(-body_half[i]-start)/d;
  vec3 b=(body_half[i]-start)/d;
  vec3 near_t=min(a,b);vec3 far_t=max(a,b);
  float enter=max(max(near_t.x,near_t.y),near_t.z);
  float leave=min(min(far_t.x,far_t.y),far_t.z);
  if(enter<=leave && leave>0.001 && enter<0.998)discard;
 }
 vec4 color=base_color*(textured?texture(base_texture,UV):vec4(1.0));
 ALBEDO=color.rgb;ROUGHNESS=surface_roughness;METALLIC=surface_metallic;EMISSION=glow;
}
