shader_type canvas_item;
render_mode unshaded;
void fragment(){
 float flow=TIME*.33;
 float streak=pow(max(0.,sin(UV.x*105.+sin(UV.y*5.-flow)*1.1)),8.);
 float ripple=.5+.5*sin(UV.y*35.-flow*10.+UV.x*11.);
 float edge=smoothstep(0.,.22,UV.x)*(1.-smoothstep(.78,1.,UV.x));
 float fade=smoothstep(0.,.15,UV.y)*(1.-smoothstep(.75,1.,UV.y));
 COLOR=vec4(.55,.77,.68,(.015+streak*.10+ripple*.025)*edge*fade);
}
