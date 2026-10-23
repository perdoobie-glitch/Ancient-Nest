shader_type canvas_item;
uniform vec2 viewport_size=vec2(1440.0,900.0);
void fragment() {
 vec2 p=(UV-vec2(.5))*viewport_size;
 float radius=min(viewport_size.x,viewport_size.y)*.44;
 COLOR=vec4(0.0,0.0,0.0,smoothstep(radius-1.0,radius+1.0,length(p)));
}
