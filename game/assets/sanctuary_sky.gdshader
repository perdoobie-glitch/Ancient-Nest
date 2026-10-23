shader_type sky;
uniform bool use_panorama = false;
uniform sampler2D panorama : source_color, filter_linear_mipmap;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 if (use_panorama) {
  vec2 uv=SKY_COORDS;
  vec3 a=texture(panorama,uv).rgb;
  vec3 b=texture(panorama,vec2(1.0-uv.x,uv.y)).rgb;
  float edge=1.0-smoothstep(0.0,.035,min(uv.x,1.0-uv.x));
  vec3 distant=mix(a,b,edge*.5);
  float mist=mix(.30,.58,1.0-smoothstep(.05,.65,abs(EYEDIR.y)));
  COLOR=mix(distant,vec3(.68,.75,.78),mist);
 } else {
 float h=max(EYEDIR.y,0.0);
 vec3 base=mix(vec3(.83,.76,.65),vec3(.25,.42,.57),pow(h,.5));
 if(EYEDIR.y>.015) {
  vec2 p=EYEDIR.xz/(EYEDIR.y+.26)*2.7;
  float n=noise(p)+.48*noise(p*2.2)+.23*noise(p*4.7)+.10*noise(p*9.2);
  float cloud=smoothstep(.94,1.24,n)*smoothstep(.01,.16,EYEDIR.y);
  base=mix(base,vec3(.99,.87,.73),cloud*.7);
 }
 float sun=pow(max(0.0,dot(EYEDIR,normalize(vec3(.48,.54,-.69)))),650.0);
 float haze=pow(max(0.0,dot(EYEDIR,normalize(vec3(.48,.54,-.69)))),9.0);
 base+=vec3(1.0,.79,.49)*sun*.8+vec3(.20,.13,.055)*haze;
 if(EYEDIR.y<0.0)base=mix(vec3(.63,.72,.75),vec3(.24,.39,.46),min(1.0,-EYEDIR.y*2.0));
 COLOR=base;
 }
}
