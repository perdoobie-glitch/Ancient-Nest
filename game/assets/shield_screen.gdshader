shader_type canvas_item;
uniform float impact=0.0;
uniform float broken=0.0;
uniform float health_hit=0.0;
uniform float shield_level=1.0;
uniform bool shield_user=true;
uniform float recharge=0.0;
uniform vec4 energy_color : source_color=vec4(.22,.70,1.0,1.0);
uniform vec2 viewport_size=vec2(1440.0,900.0);
uniform vec4 damage_edges=vec4(0.0);
uniform float health_ratio=1.0;
uniform bool no_shields=false;
uniform bool low_shield=false;
uniform sampler2D blood_noise : filter_linear_mipmap, repeat_enable;
const vec3 stains[12]=vec3[](
 vec3(.015,.16,.075),vec3(.025,.46,.09),vec3(.005,.78,.085),
 vec3(.975,.12,.08),vec3(.99,.41,.075),vec3(.97,.76,.09),
 vec3(.12,.985,.085),vec3(.38,.99,.06),vec3(.79,.975,.075),
 vec3(.22,.012,.045),vec3(.72,.008,.06),vec3(.90,.985,.07));
float hex(vec2 p) {
 vec2 r=vec2(1.0,1.73205);
 vec2 a=mod(p,r)-r*.5,b=mod(p+r*.5,r)-r*.5;
 vec2 g=dot(a,a)<dot(b,b)?a:b;
 return max(abs(g.x),dot(abs(g),vec2(.5,.866025)));
}
void fragment() {
 // Outer 30% of the distance from centre to each screen edge.
 float edge=max(abs(UV.x-.5),abs(UV.y-.5))*2.0;
 float border=smoothstep(.70,.74,edge);
 float alpha=no_shields?border*.15:0.0;
 // v0.12 shield animations. Damage: hex shimmer along the border.
 // Depleted: a cracked-hex burst sweeping inward from the edges with a flash.
 float aspect=viewport_size.x/max(viewport_size.y,1.0);
 float cell=smoothstep(.40,.47,hex(UV*vec2(aspect,1.0)*13.0));
 float shimmer_band=smoothstep(.55,1.0,edge);
 float shimmer=impact*shimmer_band*(.18+cell*.62);
 // A narrow cracked band sweeps inward from the edges while fading out.
 float reach=mix(.5,1.02,broken);
 float band=smoothstep(reach-.08,reach,edge)*(1.0-smoothstep(reach+.06,reach+.2,edge));
 float crack=broken*cell*(band*1.25+smoothstep(.72,1.0,edge)*.3)+broken*broken*broken*.2;
 vec3 shimmer_color=low_shield?vec3(1.0,.76,.40):energy_color.rgb;
 vec3 energy=shimmer_color*shimmer+mix(energy_color.rgb,vec3(.9,.97,1.0),.55)*crack;
 float energy_alpha=clamp(shimmer+crack,0.0,.85);
 float severity=smoothstep(.07,.92,1.0-health_ratio);
 float grain=texture(blood_noise,UV*vec2(viewport_size.x/max(viewport_size.y,1.0)*7.0,7.0)).r;
 float blood=smoothstep(1.0-severity*.55,1.0,grain)*severity;
 float warning=damage_edges.x*pow(1.0-UV.x,8.0)+damage_edges.y*pow(UV.x,8.0)+damage_edges.z*pow(1.0-UV.y,8.0)+damage_edges.w*pow(UV.y,8.0);
 vec3 red=mix(vec3(1.0,.035,.025),vec3(.36,.008,.012),blood*.8);
 red=mix(red,vec3(1.0,.09,.035),clamp(warning,0.0,1.0));
 float total=max(alpha,energy_alpha);
 vec3 rgb=total>0.0?(red*alpha+energy*1.0)/max(alpha+energy_alpha,.0001):red;
 COLOR=vec4(rgb,total);
}
