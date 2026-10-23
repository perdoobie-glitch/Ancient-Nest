shader_type spatial;
render_mode cull_disabled;
varying vec4 leaf_color;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 VERTEX.x+=sin(TIME*1.2+world.x*.38+world.z*.24)*.015*UV.y;
 leaf_color=COLOR;
}
void fragment() {
 float vein=1.0-smoothstep(.0,.07,abs(UV.x-.5));
 float edge=smoothstep(.0,.13,UV.x)*smoothstep(.0,.13,1.0-UV.x);
 ALBEDO=leaf_color.rgb*(.85+.15*edge)+vec3(.07,.075,.035)*vein;
 ROUGHNESS=.85;
 BACKLIGHT=vec3(.10,.14,.065);
}
