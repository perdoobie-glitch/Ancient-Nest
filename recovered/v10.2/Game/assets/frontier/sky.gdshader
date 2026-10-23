shader_type sky;
uniform vec3 zenith:source_color=vec3(.2,.4,.6);
uniform vec3 horizon:source_color=vec3(.7,.8,.8);
uniform vec3 clouds:source_color=vec3(.94,.95,.9);
uniform float cover=.55;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),f.x),f.y);}
void sky(){
 float y=max(0.,EYEDIR.y);
 vec3 color=mix(horizon,zenith,pow(y,.42));
 vec2 p=EYEDIR.xz/(y+.3)*3.;
 float noise=(n(p)+.5*n(p*2.1)+.23*n(p*4.5))/1.73;
 float cloud=smoothstep(cover,cover+.19,noise)*smoothstep(.015,.18,y);
 color=mix(color,clouds,cloud*.8);
 float sun=pow(max(0.,dot(EYEDIR,normalize(vec3(-.45,.65,-.4)))),800.);
 color+=vec3(.85,.73,.47)*sun;
 COLOR=color;
}
