shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color=vec4(.24,.28,.14,1);
void vertex() {
 VERTEX.x+=(sin(TIME*1.1+UV.x*4.5+UV.y*1.4)*.12+sin(UV.x*15.0)*.045)*UV.x;
}
void fragment() {
 float border=step(UV.x,.02)+step(.98,UV.x)+step(UV.y,.018)+step(.98,UV.y);
 float stem=(1.0-smoothstep(.002,.006,abs(UV.x-.5)))*step(.14,UV.y)*step(UV.y,.84);
 float motif=stem;
 for(int i=0;i<7;i++) {
  float row=.24+float(i)*.073;
  for(int side=-1;side<=1;side+=2) {
   vec2 p=vec2((UV.x-.5)*float(side)-.056,UV.y-row);
   p=mat2(vec2(.78,.62),vec2(-.62,.78))*p;
   motif=max(motif,1.0-smoothstep(.95,1.1,length(p/vec2(.021,.068))));
  }
 }
 float weave=sin(UV.x*1000.0)*sin(UV.y*1100.0)*.012;
 ALBEDO=mix(cloth_color.rgb+weave,vec3(.54,.43,.24),clamp(border*.6+motif*.65,0.0,1.0));
 ROUGHNESS=.94;
}
