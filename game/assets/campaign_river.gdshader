shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float ripple=sin(world.x*2.5+world.z*.7+TIME*.8)*sin(world.z*3.2-world.x*.4-TIME*.65);
 float glint=pow(max(0.0,ripple),12.0);
 ALBEDO=mix(vec3(.055,.20,.19),vec3(.17,.39,.33),ripple*.5+.5)+glint*.12;
 ROUGHNESS=.32;METALLIC=.18;
}
