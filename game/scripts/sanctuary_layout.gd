class_name NestSanctuaryLayout
extends RefCounted
static func build(a) -> void:
	var k=a.kit
	# Bottom: western service court, central vault, eastern machinery and an L loop.
	for slab in [[-29,0,5,20,30],[-24,0,-12,8,16],[0,0,-17,64,8],[0,0,2,22,20],[16,0,-1,14,12],[29,0,-1,20,22],[26,0,-12,10,10],[-4,0,16,42,8],[21,0,14,10,12],[-15,0,23,8,8],[27,0,-23,8,8]]:
		a.floor_at(slab[0],slab[1],slab[2],Vector2(slab[3],slab[4]))
	# Middle: temple atrium, northern arcade, broken side galleries and southeast market.
	for slab in [[0,7,2,22,18],[-7.5,7,-9,7,4],[7.5,7,-9,7,4],[-15.5,7,0,9,8],[15.5,7,0,9,8],[0,7,-18.25,48,5.5],[-13.5,7,-14.25,21,2.5],[13.5,7,-14.25,21,2.5],[6,7,-20,4,8],[6,7,-24,4,6],[6,7,12,6,8],[8,7,20,20,12],[-15,7,3,6,4]]:
		a.floor_at(slab[0],slab[1],slab[2],Vector2(slab[3],slab[4]))
	for x in [-21,21]:
		for z in [-17,0,17]: a.floor_at(x,7,z,Vector2(6,8))
		for z in [-10,10]:
			var id=(1 if x<0 else 2) if z<0 else (3 if x<0 else 4)
			k.label(a,Vector3(x,8.5,z),"D%d · BOTTOM ↓"%id,Color("dfc890"),24)
			k.ring(a,Vector3(x,0.02,z),1.8,k.gold)
			for sx in [-1,1]: k.box(a,Vector3(x+sx*2.9,7.5,z),Vector3(.22,1,4),k.stone,true)
	# Bases are offset balconies. The west deck ends at z=0 so its underside
	# cannot trap standing capsules as U1 rises toward the base.
	for slab in [[-34.75,9,0,6.5,32],[-25.5,9,-9.5,3,13],[-25.5,9,9.5,3,13],[-29.25,9,-13.5,4.5,5],[-28.75,9,8,5.5,16],[-32,9,18,12,4],[30.5,9,0,9,32],[36.5,9,-9.5,3,13],[36.5,9,9.5,3,13],[39,0,7,4,6],[39,9,7,4,6]]:
		a.floor_at(slab[0],slab[1],slab[2],Vector2(slab[3],slab[4]))
	for side in [-1,1]:
		for z in [-17,0,17]: a.up_route("BASE APPROACH",Vector3(side*23,7,z),Vector3(side*26,9,z),5.8,false)
		var flag=k.banner(a,Vector3(side*35,9,-5),k.green if side<0 else k.red); a.flag_meshes.append(flag)
		k.pillar(a,Vector3(side*35,9,-5),5)
		a.flag_labels.append(k.label(a,Vector3(side*31,12,0),"NAKI" if side<0 else "ANNU",Color("dfc890")))
		for y in [0.0,9.0]:
			for z in [-7.0,6.0]:
				var pos=Vector3(side*32,y+.08,z)
				if side<0 and y==9 and z==-7: pos=Vector3(-37,9.08,-9)
				if side>0 and y==0 and z==-7: pos=Vector3(33.1,.08,-7)
				a.spawns[0 if side<0 else 1].append(pos)
	# Top: northwest citadel, narrow bent skywalk, central garden and east observatory.
	for slab in [[-19,14,-21,16,12],[-33,14,-24.5,8,5],[-23,14,-25,22,4],[-11,14,-14,22,6],[2,14,-4,6,26],[6,14,8,26,20],[30,14,9,22,14],[37,14,19,6,12],[36,14,24,4,6]]:
		a.floor_at(slab[0],slab[1],slab[2],Vector2(slab[3],slab[4]))
	a.spawns[0].append(Vector3(-19,14.08,-23)); a.spawns[1].append(Vector3(29,14.08,9))
	a.up_route("U1 · BASE RETURN",Vector3(-29,0,12),Vector3(-29,9,-11),4.2)
	a.up_route("U3 · CITADEL ASCENT",Vector3(-33,9,-6),Vector3(-33,14,-22),4.2)
	a.up_route("U4 · MARKET TO TOP",Vector3(15,7,24),Vector3(34,14,24),4.2)
	a.up_route("U5 · EAST VAULT TO MIDDLE",Vector3(27,0,-24),Vector3(8,7,-24),4.2)
	a.up_route("U6 · WEST SERVICE TO MIDDLE",Vector3(-15,0,24),Vector3(-15,7,5),4.2)
	var lift=Node3D.new(); lift.name="U2Lift"; lift.set_script(load("res://scripts/lift.gd")); lift.kit=k; lift.upper_height=13.8; lift.position=Vector3(39,-.2,0); a.add_child(lift)
	k.label(a,Vector3(39,2,-3),"U2 · GRAVITY LIFT",Color("dfc890"),25)
	for z in [-3,3]: k.pillar(a,Vector3(42,0,z),15)
	a.up_route("J1 · CENTRAL RAMP TO MIDDLE",Vector3(0,0,-18.7),Vector3(0,7,-6.6),4.2)
	build_connected_structures(a)
	NestExterior.build(a)
	NestBombEnclosures.build(a)
	NestV19Map.build(a)
	NestRoundMap.build(a)
	# Distinct sight lines: waist-high cover with generous routes around it.
	for item in [[-26,0,4,3.8,1.3],[-23,0,-3,1.2,4],[-5,0,6,3.8,1.1],[4,0,-3,1.2,4],[26,0,3,3.8,1.3],[31,0,-5,1.3,3.2],[5,7,-17,3.5,1.0],[-7,7,6,2.8,1.0],[7,7,4,1.0,3.0],[12,7,19,3.5,1.0],[-18,14,-20,3.0,1.0],[9,14,5,1.0,3.0],[26,14,12,3.0,1.0]]:
		cover(a,Vector3(item[0],item[1],item[2]),Vector2(item[3],item[4]))
	for p in [Vector3(-9,7,-6),Vector3(9,7,-6),Vector3(-9,7,6),Vector3(9,7,6)]: k.pillar(a,p,4.2)
	for p in [Vector3(-21,0,-18),Vector3(21,0,-18),Vector3(-21,7,-18)]: k.arch(a,p,PI/2,4.5)
	for p in [Vector3(-33,9,13),Vector3(31,9,-13),Vector3(6,14,10),Vector3(-17,14,-24)]: k.planter(a,p,true)
	for p in [Vector3(0,7,2),Vector3(14,7,22),Vector3(12,14,15),Vector3(-4,0,15)]: k.planter(a,p)
	# Bottom machinery and broken storage walls; no mirrored placement.
	for p in [Vector3(29,0,-6),Vector3(31,0,3),Vector3(-27,0,14)]:
		k.cylinder(a,p+Vector3(0,1.15,0),.8,2.3,k.dark,true); k.ring(a,p+Vector3(0,2.32,0),.83,k.gold)
	for x in [-7,1]: k.box(a,Vector3(x,1.7,10),Vector3(2.5,3.4,.5),k.stone,true)
	# Middle market stalls add cover, canopies and an open southern route.
	for p in [Vector3(4,7,19)]:
		for x in [-1,1]: k.cylinder(a,p+Vector3(x*1.3,1.5,0),.075,3,k.gold)
		k.box(a,p+Vector3(0,3,0),Vector3(3.2,.12,2.2),k.dark)
		k.box(a,p+Vector3(0,.55,0),Vector3(2.6,1.1,1),k.stone,true)
	# Sky observatory has a ring, instruments and a raised focal sculpture.
	k.ring(a,Vector3(31,14.04,8),3.6,k.gold)
	for i in range(5):
		var p=Vector3(31+sin(i*TAU/5)*3.6,14,8+cos(i*TAU/5)*3.6)
		k.pillar(a,p,3.5)
	k.cylinder(a,Vector3(31,14.45,8),.75,.9,k.dark,true)
	var lens=k.sphere(a,Vector3(31,15.6,8),.46,k.lamp); lens.scale=Vector3(1,1.5,1)
	# Parapets on exposed edges leave each named ascent and drop open.
	for p in [Vector3(-30,14.55,-27),Vector3(-17,14.55,-27),Vector3(8,14.55,18),Vector3(28,14.55,16),Vector3(-34,0.55,20),Vector3(0,0.55,-21),Vector3(14,7.55,26)]:
		k.box(a,p,Vector3(6,1.1,.35),k.stone,true)
	for y in [0.0,7.0]:
		for x in [-18,-12,-6,6,12,18]: k.box(a,Vector3(x,y+.6,-21),Vector3(5.5,1.2,.45),k.stone,true)
	k.label(a,Vector3(-27,3,10),"BOTTOM · SERVICE VAULTS",Color("b9ced2"),26)
	k.label(a,Vector3(3,10,14),"MIDDLE · TEMPLE MARKET",Color("dfc890"),26)
	k.label(a,Vector3(12,17,9),"TOP · SKY GARDENS",Color("dfc890"),26)
static func cover(a, pos: Vector3, size: Vector2) -> void:
	var parent: Node3D=a.forge_group("Map cover",pos) if a.forge_editable else a
	var anchor: Vector3=Vector3.ZERO if a.forge_editable else pos
	a.kit.box(parent,anchor+Vector3(0,.6,0),Vector3(size.x,1.2,size.y),a.kit.stone,true)
	a.kit.box(parent,anchor+Vector3(0,1.22,0),Vector3(size.x+.07,.06,size.y+.07),a.kit.gold)
	a.floor_cover.append({"pos":pos,"size":size})

static func wall(a, pos: Vector3, size: Vector2, height: float=3.4) -> void:
	var parent: Node3D=a.forge_group("Map wall",pos) if a.forge_editable else a
	var anchor: Vector3=Vector3.ZERO if a.forge_editable else pos
	a.kit.box(parent,anchor+Vector3(0,height*.5,0),Vector3(size.x,height,size.y),a.kit.stone,true)
	a.kit.box(parent,anchor+Vector3(0,height-.1,0),Vector3(size.x+.08,.2,size.y+.08),a.kit.gold)
	a.floor_cover.append({"pos":pos,"size":size})
static func build_connected_structures(a) -> void:
	# Split rooms and bearing walls connect deck slabs rather than floating cover.
	for item in [[-10,0,0,.65,8,6.7],[10,0,3,.65,8,6.7],[-7,0,8,6,.6,6.7],[7,0,8,6,.6,6.7],[-26,0,-8,7,.65,6.7],[18,0,-19.7,8,.6,6.7],[-16,0,-19.7,9,.6,6.7],[-10,7,0,.65,8,6.7],[10,7,3,.65,8,6.7],[3,7,16,.6,5,3.6],[16.7,7,20,.6,7,3.6],[7,7,25.5,6,.6,3.6],[-21,14,-20,.6,5,3.4],[-16,14,-16,7,.6,3.4],[11,14,11,7,.6,3.4],[23,14,6,.6,5,3.4],[35,14,12,6,.6,3.4]]:
		wall(a,Vector3(item[0],item[1],item[2]),Vector2(item[3],item[4]),item[5])
	# Covered service bridge and continuous middle gallery bypass the old gaps.
	a.floor_at(-16,0,0,Vector2(10,5))
	wall(a,Vector3(-16,0,-2.3),Vector2(8,.45),3.4)
	a.kit.box(a,Vector3(-16,3.5,0),Vector3(9,.35,5),a.kit.stone,true)
	a.floor_at(21,7,7,Vector2(6,8)); a.floor_at(19,7,12,Vector2(8,4))
	wall(a,Vector3(23.7,7,7),Vector2(.45,7),3.2)
	a.kit.box(a,Vector3(21,10.5,7),Vector3(6,.35,7),a.kit.stone,true)
	# Bent upper walkway joins the west citadel to the central skywalk.
	a.floor_at(-19,14,-10,Vector2(5,10)); a.floor_at(-12,14,-5,Vector2(22,4))
	wall(a,Vector3(-21.2,14,-10),Vector2(.45,8),2.8)
	wall(a,Vector3(-12,14,-6.7),Vector2(16,.45),2.8)
	# Buttresses rise between levels, outside the named ramps and spawn pockets.
	for p in [Vector3(-20,0,1),Vector3(19,0,-2),Vector3(-5,7,-6),Vector3(17,7,14)]:
		wall(a,p,Vector2(.8,.8),6.8)
	# Two simple, asymmetric traversal alternatives; broad supported landing decks.
	for item in [{"name":"C1 · VAULT TO TEMPLE","start":Vector3(-12,0,16),"end":Vector3(-7,7,9)}, {"name":"C2 · ARCADE TO GARDEN","start":Vector3(21,7,-17),"end":Vector3(6,14,8)}]:
		var pad=NestManCannon.new(); pad.name=item.name; pad.position=item.start; pad.destination=item.end; a.add_child(pad)
		pad.horizontal_drag_compensation=.5;pad.flight_seconds=3.4 if item.name.begins_with("C2") else 1.8
		a.kit.cylinder(pad,Vector3(0,.05,0),1.15,.1,a.kit.dark)
		a.kit.ring(pad,Vector3(0,.13,0),.85,a.kit.gold)
		for side in [-1,1]: a.kit.box(pad,Vector3(side*.85,.35,.45),Vector3(.18,.6,1.1),a.kit.lamp)
		a.kit.label(pad,Vector3(0,2,0),item.name+" ↑",Color("77cbd8"),22)
		a.cannon_routes.append(item)

static func polish(a) -> void:
	# Small, solid jump ledges; main corridors and ascending ramps stay clear.
	for item in [[-19,0,1.8,.5],[-17.5,0,1.8,1.1],[-16,0,1.8,1.7],[-12,14,-5.9,1.0],[7,14,16.7,.7],[34,14,14.3,.9]]:
		var pos=Vector3(item[0],item[1],item[2]);var h=float(item[3])
		a.kit.box(a,pos+Vector3(0,h*.5,0),Vector3(1.25,h,1.0),a.kit.stone,true)
		a.kit.box(a,pos+Vector3(0,h+.03,0),Vector3(1.30,.06,1.06),a.kit.gold)
		a.floor_cover.append({"pos":pos,"size":Vector2(1.25,1.0)})
		a.floor_surfaces.append({"pos":pos+Vector3.UP*h,"size":Vector2(1.25,1.0)})
	a.floor_surfaces.append({"pos":Vector3(-16,3.675,0),"size":Vector2(9,5)})
	# Inset bronze courses and small emissive sconces finish bearing walls.
	for pos in [Vector3(-10,0,0),Vector3(10,0,3),Vector3(-10,7,0),Vector3(10,7,3),Vector3(23.7,7,7),Vector3(-21.2,14,-10)]:
		for y in [.5,2.5]:a.kit.box(a,pos+Vector3(.36,y,0),Vector3(.05,.08,6),a.kit.gold)
		a.kit.box(a,pos+Vector3(.42,2.15,2.2),Vector3(.12,.45,.18),a.kit.lamp)
