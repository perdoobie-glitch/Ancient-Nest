class_name NestExterior
extends RefCounted
# Additive shell only: no existing floor, wall, spawn, objective or route is removed.
const TOP_FLOOR_Y=14.0
const SIDE_ROOF_Y=43.675
const CENTRAL_ROOF_Y=49.675
const ROOF_THICKNESS=.65
static func build(a: NestArena) -> void:
	var k=a.kit
	var glass=k.material(Color(.26,.43,.43,.16),.15)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness=.18;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var colors=NestChurchWindow.palette(k)
	# A high perimeter encloses the existing asymmetric decks. Full-height piers
	# frame open door bays and coloured upper glazing, rather than sealing ramps.
	for side in [-1,1]:
		for x in [-36,-28,-20,-12,-4,4,12,20,28,36]:
			bay(a,Vector3(x,0,side*29),false,colors,absi(int(x))/8)
		for z in [-24,-16,-8,0,8,16,24]:
			bay(a,Vector3(side*43,0,z),true,colors,absi(int(z))/8)
	# Raised central roof and lower side wings form a cross overhead while all
	# existing playable deck shapes remain intact. Clerestory glazing admits sky.
	k.box(a,Vector3(0,CENTRAL_ROOF_Y,0),Vector3(24,ROOF_THICKNESS,58),k.stone,true)
	for side in [-1,1]:
		k.box(a,Vector3(side*27.5,SIDE_ROOF_Y,0),Vector3(31,ROOF_THICKNESS,58),k.stone,true)
		k.box(a,Vector3(side*12,(CENTRAL_ROOF_Y+SIDE_ROOF_Y)*.5,0),Vector3(.16,CENTRAL_ROOF_Y-SIDE_ROOF_Y,58),glass,true)
		for z in [-25,-13,0,13,25]:
			k.box(a,Vector3(side*27.5,SIDE_ROOF_Y-.45,z),Vector3(31,.45,.65),k.gold,true)
	# Outer walks join two existing decks; none pass through a visible wall.
	# East loop: current observatory -> open wall bay -> outside balcony -> ramp.
	a.floor_at(43,14,24,Vector2(12,4))
	# The balcony starts at the ramp endpoint, leaving headroom over the incline.
	a.floor_at(47,14,14,Vector2(4,16))
	a.floor_at(44,14,8,Vector2(10,4))
	a.floor_at(47,9,-10,Vector2(4,8))
	a.up_route("EAST OUTER ASCENT",Vector3(47,9,-6),Vector3(47,14,6),3.6)
	a.floor_at(41.5,9,-8,Vector2(15,4))
	# West loop starts at the existing northwest citadel and ends at the base.
	a.floor_at(-40,14,-24,Vector2(14,4))
	a.floor_at(-45,14,-17,Vector2(4,14))
	a.up_route("WEST OUTER ASCENT",Vector3(-45,9,6),Vector3(-45,14,-10),3.6)
	a.floor_at(-40,9,8,Vector2(14,4))
	a.floor_at(-45,9,7,Vector2(4,6))
	for item in [[49,14,14,0.3,19],[-47,14,-17,.3,13]]:
		k.box(a,Vector3(item[0],item[1]+.5,item[2]),Vector3(item[3],1,item[4]),k.stone,true)
	# Alcoves are on top of solid ledges, outside the windows, never inside props.
	for item in [[-20,16.0,-28],[-12,17.7,-28],[-4,19.4,-28],[4,21.1,-28],[12,22.8,-28],[20,24.5,-28]]:
		a.floor_at(item[0],item[1],item[2],Vector2(3.4,2.4))
		k.box(a,Vector3(item[0],item[1]-.45,item[2]),Vector3(3.4,.9,2.4),k.stone,true)
	# A continuous rafter spine plus crossbeams has safe headroom to the roof.
	# Deliberately narrow supports demand precise jumps; fallback drops land on decks.
	a.floor_at(0,22.8,0,Vector2(2.6,48))
	for z in [-20,-4,12]:a.floor_at(0,22.8,z,Vector2(64,2.4))
	for item in [[-20,15.7,-21],[-18,17.3,-21],[-15.5,18.9,-21],[-13,20.5,-21],[-10,22.1,-21]]:
		a.floor_at(item[0],item[1],item[2],Vector2(1.8,2.2))
		k.box(a,Vector3(item[0],item[1]-.3,item[2]),Vector3(1.8,.6,2.2),k.dark,true)
	# First rafter entrance connects the stepping ledges to the north crossbeam.
	a.floor_at(-7,22.8,-20,Vector2(7,2.4))
	# Gravity lift starts on a fixed ground apron. Top shaft remains open so the
	# updraft can carry a standing capsule above the lip before the southward exit.
	a.floor_at(39,0,0,Vector2(6,6))
	k.label(a,Vector3(38,16.5,5),"GRAVITY LIFT EXIT",Color("7ddbf0"),22)
	# Side-window sills have walkable ledges on each side of the glazing.
	for side in [-1,1]:
		for x in [-36,-28,28,36]:
			for z in [side*27.75,side*30.25]:
				a.floor_at(x,NestChurchWindow.SILL,z,Vector2(5.4,2.2))
				a.kit.box(a,Vector3(x,NestChurchWindow.SILL-.55,z),Vector3(4.7,.3,1.7),k.gold,true)
	a.set_meta("top_floor_roofs",{"floor":TOP_FLOOR_Y,"side":SIDE_ROOF_Y-ROOF_THICKNESS*.5,"central":CENTRAL_ROOF_Y-ROOF_THICKNESS*.5})
	a.bounds=Vector2(50,33)
static func bay(a: NestArena, pos: Vector3, rotated: bool, colors: Array[Material], variant: int) -> void:
	var n=Node3D.new();n.name="ExteriorWindowBay";a.add_child(n);n.position=pos
	if rotated:n.rotation.y=PI*.5
	var k=a.kit
	for side in [-1,1]:k.box(n,Vector3(side*3.85,21.675,0),Vector3(.3,43.35,.65),k.stone,true)
	# Open floor-level passages fit standing players at ground, middle, base, top.
	# Lintels and glazing remain above those passages; the upper windows are solid.
	for item in [[5.5,1.0],[12.8,.8],[20.5,.5],[42.35,2.0]]:
		k.box(n,Vector3(0,item[0],0),Vector3(7.4,item[1],.5),k.stone,true)
	for x in [-2.8,2.8]:
		k.box(n,Vector3(x,2.2,0),Vector3(1.8,4.4,.5),k.stone,true)
		k.box(n,Vector3(x,9.4,0),Vector3(1.8,4.8,.5),k.stone,true)
		k.box(n,Vector3(x,16.1,0),Vector3(1.8,4.2,.5),k.stone,true)
	# Navigation metadata follows the solid side pieces at each existing deck.
	for level in [0.0,7.0,9.0,14.0]:
		for side in [-1,1]:
			var offset=Vector3(side*2.8,0,0).rotated(Vector3.UP,n.rotation.y)
			a.floor_cover.append({"pos":pos+offset+Vector3.UP*level,"size":Vector2(.5,1.8) if rotated else Vector2(1.8,.5)})
	NestChurchWindow.build(n,k,colors,variant)
