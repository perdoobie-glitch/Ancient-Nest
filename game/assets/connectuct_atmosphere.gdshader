shader_type sky;
// Fictional visible atmospheric damage, not a literal rendering of ozone gas.
// Static sky: no per-frame radiance rebuild, screen-space fog or cloud volumes.
uniform sampler2D weather_noise : filter_linear_mipmap, repeat_enable;
uniform bool low_detail=false;
void sky(){
 vec3 ray=normalize(EYEDIR);float altitude=max(ray.y,0.0);
 vec3 horizon=vec3(.79,.41,.24);vec3 zenith=vec3(.035,.105,.24);
 vec3 color=mix(horizon,zenith,pow(altitude,.36));
 vec2 uv=SKY_COORDS;
 float broad=texture(weather_noise,uv*vec2(5.0,2.5)).r;
 float detail=low_detail?broad:texture(weather_noise,uv*vec2(17.0,7.0)).r;
 float haze=exp(-altitude*8.0);color=mix(color,vec3(.83,.63,.45),haze*.42);
 float clouds=smoothstep(.46,.67,broad+detail*.15)*smoothstep(.03,.22,altitude)*(1.0-smoothstep(.5,.86,altitude));
 color=mix(color,vec3(.48,.38,.49),clouds*.43);
 // Torn violet/teal bands reveal dark upper atmosphere between thinning veils.
 float ribbon=abs(sin(ray.x*7.0+ray.z*3.0+sin(ray.z*5.0)*.6+ray.y*10.0));
 float veil=(1.0-smoothstep(.035,.12,ribbon))*smoothstep(.15,.35,altitude)*(1.0-smoothstep(.68,.9,altitude));
 float gaps=smoothstep(.35,.67,broad);
 color+=mix(vec3(.17,.045,.23),vec3(.035,.15,.18),detail)*veil*gaps;
 float sun=dot(ray,normalize(vec3(-.42,.32,-.7)));
 color+=vec3(.8,.44,.17)*pow(max(sun,0.0),24.0)*.35;
 color=mix(color,vec3(1.0,.86,.55),smoothstep(.9993,.99965,sun));
 if(ray.y<0.0)color=mix(vec3(.16,.18,.21),horizon,exp(ray.y*9.0));
 COLOR=color;
}
