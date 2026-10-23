shader_type spatial;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(.48,.47,.38);
varying vec3 world;
varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;normal_world=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 vec2 uv=abs(normal_world.x)>.65 ? world.zy : world.xy;
 float row=floor(uv.y/.65);
 vec2 cell=fract(vec2(uv.x/1.9+mod(row,2.0)*.5,uv.y/.65));
 float joint=1.0-smoothstep(.018,.035,min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y)));
 float broad=texture(noise_texture,uv*.065).r;
 float grain=texture(noise_texture,uv*2.1).r;
 ALBEDO=mix(tint*(.82+broad*.28+(grain-.5)*.035),tint*.55,joint*.60);
 ROUGHNESS=.84;
}
