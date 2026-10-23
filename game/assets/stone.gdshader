shader_type spatial;
varying vec3 local_world;
varying vec3 world_normal;
uniform bool low_detail=false;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
void vertex() { local_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL); }
void fragment() {
 vec3 p=local_world;
 vec2 tiles=abs(world_normal.y)>.65 ? p.xz : (abs(world_normal.x)>.65 ? p.zy : p.xy);
 float floor_face=step(.65,abs(world_normal.y));
 float course=floor(tiles.y/.72);
 vec2 masonry=vec2(tiles.x/2.4+mod(course,2.0)*.5,tiles.y/.72);
 vec2 grid=abs(fract(mix(masonry,tiles/2.0,floor_face))-.5);
 float grout=smoothstep(.480,.496,max(grid.x,grid.y));
 float broad=texture(noise_texture,tiles*.042).r;
 float cloud=broad;
 if(!low_detail)cloud+=.3*texture(noise_texture,tiles*.22).r;
 float vein=0.0;
 if(!low_detail)vein=pow(1.0-abs(sin(p.x*.7+p.z*.4+broad*7.0)),13.0);
 float grain=.5;
 if(!low_detail)grain=texture(noise_texture,tiles*1.9).r;
 vec3 ivory=mix(vec3(.38,.405,.38),vec3(.56,.545,.49),cloud*.55);
 ivory*=mix(.76,1.05,clamp(world_normal.y*.5+.5,0.0,1.0));
 ivory*=mix(.88,1.0,smoothstep(0.0,18.0,p.y));
 // Subtle directional relief remains readable even with dynamic shadows off.
 float relief=.78+.22*max(0.0,dot(normalize(world_normal),normalize(vec3(-.5,.85,.3))));
 ivory*=relief;
 ivory=mix(ivory*vec3(.91,.99,1.01),ivory*vec3(1.04,1.0,.92),floor_face);
 ivory-=vein*.025; ivory+=(grain-.5)*.020;
 ALBEDO=mix(ivory,vec3(.225,.235,.22),grout*.56);
 ROUGHNESS=.74+grain*.12;
}
