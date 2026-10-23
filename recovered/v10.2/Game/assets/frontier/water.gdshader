shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float wave=sin(world_position.x*2.1+TIME*.65)*sin(world_position.z*1.7-TIME*.4);
 float ripple=sin(world_position.x*5.0+world_position.z*3.1+TIME*.8);
 ALBEDO=mix(vec3(.055,.23,.20),vec3(.13,.37,.32),wave*.5+.5);
 ROUGHNESS=.22;SPECULAR=.65;
 NORMAL_MAP=normalize(vec3(wave*.1,ripple*.07,1.0))*.5+.5;
 EMISSION=vec3(.055,.10,.08)*max(0.0,pow(abs(ripple),20.0));
}
