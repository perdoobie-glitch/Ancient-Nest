class_name NestInteriorLighting
extends RefCounted
# Lighting only. Fixed local ranges avoid illuminating the whole enclosed arena
# with every lamp; only two accent lights pay for indoor shadow maps.
static func build(a: NestArena) -> void:
	var warm=Color("ffdfad")
	var cool=Color("c3e4ef")
	for pos in [Vector3(-24,27,-18),Vector3(24,27,-10),Vector3(-15,27,13),Vector3(25,27,18)]:
		spot(a,pos,pos+Vector3.DOWN*12,18,66,1.15,warm)
	# Soft high fills keep the overhead precision-jump route readable too.
	for z in [-16,16]:spot(a,Vector3(0,30,z),Vector3(0,22,z),13,68,.85,cool)
	# Broad low-energy uplights reveal the newly elevated vault.
	for x in [-24,24]:spot(a,Vector3(x,26,0),Vector3(x,43,0),24,72,.7,warm)
	for pos in [Vector3(-20,12,-14),Vector3(20,12,-14),Vector3(-20,12,14),Vector3(20,12,14),Vector3(0,12,2)]:
		spot(a,pos,pos+Vector3.DOWN*5,10,68,.9,warm)
	for pos in [Vector3(0,4,3),Vector3(27,4,-3)]:
		var fill=OmniLight3D.new();fill.name="InteriorSoftFill";fill.position=pos
		fill.light_color=cool;fill.light_energy=.65;fill.omni_range=7;fill.omni_attenuation=1.3
		fill.shadow_enabled=false;a.add_child(fill)
	# Two shadow accents use existing cover: the service bridge underside and
	# the inner side of the east observatory wall. Ambient keeps silhouettes visible.
	spot(a,Vector3(-23,7,-1),Vector3(-16,1.4,0),12,52,1.0,cool,true)
	spot(a,Vector3(26,20,12),Vector3(20,14,3),14,55,1.0,warm,true)
static func spot(a: NestArena, pos: Vector3, target: Vector3, radius: float, angle: float, energy: float, color: Color, shadows: bool=false) -> void:
	var light=SpotLight3D.new();light.name="InteriorShadowAccent" if shadows else "InteriorCeilingWash"
	a.add_child(light);light.position=pos;light.look_at(target,Vector3.FORWARD if absf((target-pos).normalized().dot(Vector3.UP))>.99 else Vector3.UP)
	light.light_color=color;light.light_energy=energy;light.spot_range=radius;light.spot_angle=angle
	light.spot_attenuation=1.15;light.shadow_enabled=shadows;light.shadow_bias=.04;light.shadow_normal_bias=.6
	if shadows:a.interior_shadow_lights.append(light)
