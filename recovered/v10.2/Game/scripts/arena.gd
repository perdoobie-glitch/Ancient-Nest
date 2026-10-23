class_name NestArena
extends Node3D
const MAP_NAMES=["Sanctuary","Crossroads","Savannah","Connectuct","Qaytal","Temple"]
var map_selection: int=0
var flag_positions: Array[Vector3]=[]
func map_title() -> String:return MAP_NAMES[map_selection]
func width_multiplier() -> float:return 1.35 if map_selection==0 else 1.20 if map_selection in [3,4] else 1.28 if map_selection==5 else 1.0
func length_multiplier() -> float:return 1.35 if map_selection==1 else 1.24 if map_selection==4 else 1.18 if map_selection in [3,5] else 1.0
var kit = NestKit.new()
var forge_editable: bool=false
var forge_piece_count: int=0
var forge_auto_count: int=0
var sites: Array[Vector3] = [Vector3(16,7,0),Vector3(16,0,0)]
var deposits: Array[Node3D] = []
var deposit_labels: Array[Label3D] = []
var ship_position = Vector3(-35,9,3)
var pads: Array[Vector3] = [Vector3(-23,14,-19),Vector3(6,0,15),Vector3(6,14,4),Vector3(0,0,15),Vector3(26,14,6),Vector3(3,0,15)]
var pad_names = ["SNIPER", "SNIPER", "ROCKETS", "SHOTGUN", "CLOAK", "SHIELD"]
var pad_meshes: Array[Node3D] = []
var pad_kinds = ["sniper","sniper","rocket","shotgun","cloak","overshield","ak47","burst_scoped","rifle","burst_scoped","shotgun","sidearm"]
var sealed_bodies: Array = []
var solid_art_bodies: Array[StaticBody3D] = []
var spawns = {0: [], 1: []}
var nav_points: Array[Vector3] = []
var nav_links: Dictionary = {}
var nav_graph = AStar3D.new()
var query_index=NestArenaQueryIndex.new()
var blocked_nav: Dictionary={}
var navigation_revision=0
const SUPPORT_CORNERS=[Vector2(-.32,-.32),Vector2(-.32,.32),Vector2(.32,-.32),Vector2(.32,.32)]
var flag_labels: Array[Label3D] = []
var flag_meshes: Array[MeshInstance3D] = []
const MAP_SCALE = .85
var cannon_routes: Array[Dictionary] = []
var bounds = Vector2(50,30)
var floor_surfaces: Array[Dictionary] = []
var floor_cover: Array[Dictionary] = []
var up_routes: Array[Dictionary] = []
var batch_stats: Dictionary = {}
var interior_shadow_lights: Array[SpotLight3D] = []
var forge_lights: Array[Light3D]=[]
var sun: DirectionalLight3D
func _ready() -> void:
	build()
func build() -> void:
	kit.restrained_architecture=true
	if forge_editable:kit.forge_arena=self
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var sky_mat = ShaderMaterial.new()
	sky_mat.shader=load("res://assets/sanctuary_sky.gdshader")
	if ResourceLoader.exists("res://assets/v19_panorama.jpg"):
		sky_mat.set_shader_parameter("use_panorama",true);sky_mat.set_shader_parameter("panorama",load("res://assets/v19_panorama.jpg"))
	sky.sky_material = sky_mat
	if map_selection==2:
		var desert=ProceduralSkyMaterial.new();desert.sky_top_color=Color("668ca4");desert.sky_horizon_color=Color("e0c99c");desert.ground_horizon_color=Color("d2b17d");desert.ground_bottom_color=Color("927451");sky.sky_material=desert
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d9df")
	env.ambient_light_energy = .3 if map_selection==2 else .52 if map_selection==0 else .45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Cheap depth fog; no volumetric pass. Playable nearby cover remains clear.
	env.fog_enabled=true
	env.fog_light_color=Color("d8bc86") if map_selection==2 else Color("aebfc7")
	env.fog_density=.0015
	env.fog_sky_affect=0.0
	env_node.environment = env
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0) if map_selection==0 else Vector3(-34,-28,0)
	sun.light_color = Color("fff0d9")
	sun.light_energy = .58 if map_selection==2 else .8
	sun.shadow_enabled = true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	if map_selection>=3:NestFrontierMaps.environment(self,env,sky,sun)
	pads.append_array([Vector3(-20,0,12),Vector3(3,0,-17),Vector3(-17,7,1),Vector3(8,7,20),Vector3(-12,14,-5),Vector3(26,14,9)])
	pad_names.append_array(["AK-47","SCOPED BR","AUTOMATIC RIFLE","SCOPED BR","SHOTGUN","MAGNUM"])
	if map_selection==0:
		NestSanctuaryLayout.build(self)
		NestSanctuaryLayout.polish(self)
		NestSanctuaryFlow.build(self)
		NestSanctuaryVaults.build(self)
	elif map_selection==1:NestCrossroadsLayout.build(self)
	elif map_selection==2:NestSavannahLayout.build(self)
	else:NestFrontierMaps.build(self)
	for i in range(2):
		var n = Node3D.new()
		add_child(n)
		n.position = sites[i]
		deposits.append(n)
		var plinth=kit.cylinder(n,Vector3(0,0.12,0),2.2,0.24,kit.gold);plinth.name="ObjectivePlinth"
		var sealed=Node3D.new(); sealed.name="Sealed"; n.add_child(sealed)
		var ore=load("res://models/OreDeposit.glb").instantiate(); sealed.add_child(ore)
		var bodies=[]
		for mesh in ore.find_children("*","MeshInstance3D",true,false): bodies.append(solid_mesh(sealed,mesh))
		sealed_bodies.append(bodies)
		var broken=Node3D.new(); broken.name="Opened"; n.add_child(broken); broken.visible=false
		for j in range(6): kit.sphere(broken,Vector3(sin(j)*1.6,0.22,cos(j)*1.6),0.35,kit.dark)
		kit.cylinder(broken,Vector3(0,0.7,0),0.3,1.4,kit.gold)
		kit.cylinder(broken,Vector3(0,1.2,0),.42,.3,kit.dark)
		for side in [-1,1]:
			kit.branch(broken,Vector3(side*.85,.12,0),Vector3(side*.27,1.0,0),.055,kit.dark)
			kit.box(broken,Vector3(side*.82,.13,0),Vector3(.4,.16,.4),kit.gold)
		var rotor=kit.box(broken,Vector3(0,1.5,0),Vector3(1.1,0.12,0.16),kit.gold); rotor.name="Rotor"
		var drill=NestDrillVisual.new(); broken.add_child(drill)
		kit.box(n,Vector3(0,0.7,-1.6),Vector3(0.8,1.4,0.8),kit.dark,true)
		deposit_labels.append(kit.label(self,sites[i]+Vector3(0,3,0),"%s · SEALED"%("A" if i==0 else "B"),Color("dfc890"),32))
	build_ship()
	for i in range(pads.size()):
		kit.ring(self,pads[i]+Vector3(0,0.02,0),0.7,kit.gold)
		var m = Node3D.new()
		add_child(m)
		m.position = pads[i]
		if pad_kinds[i] not in ["cloak","overshield"]:
			var weapon=NestWeaponArt.create(pad_kinds[i],0);weapon.position.y=.8;weapon.rotation.z=-.12;m.add_child(weapon)
		else:
			var orb_material=kit.material(Color(.2,.9,.4,.58) if pad_kinds[i]=="overshield" else Color(.13,.48,1.0,.58))
			orb_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;orb_material.emission_enabled=true;orb_material.emission=orb_material.albedo_color;orb_material.emission_energy_multiplier=.55
			kit.sphere(m,Vector3(0,.9,0),.72,orb_material)
		var pickup_title=NestWeaponCatalog.for_kind(pad_kinds[i]).get("title",pad_names[i])
		kit.label(m,Vector3(0,1.3,0),String(pickup_title).to_upper(),Color("dfc890"),20)
		m.visible = false
		pad_meshes.append(m)
	if map_selection<2:
		# Mist is strictly below the map: translucent layers never obscure a deck.
		var mist = ShaderMaterial.new(); mist.shader=load("res://assets/mist.gdshader")
		for i in range(3): kit.box(self,Vector3(0,-9-i*3,0),Vector3(180,0.1,160),mist)
		# Warm undercroft lamps and faceted floating rock foundations.
		for x in [-18,18]:
			for z in [-16,16]:
				var light=OmniLight3D.new(); light.position=Vector3(x,3,z); light.light_color=Color("ffcf91"); light.light_energy=0.8; light.omni_range=9; add_child(light)
		if map_selection==0:NestInteriorLighting.build(self)
		var rock_material=kit.material(Color("34434b"))
		for x in [-33,-21,21,33]:
			for z in [-15,15]:
				var rock=kit.sphere(self,Vector3(x,-6.5,z),3.0,rock_material)
				rock.scale=Vector3(1.2,1.8,1.0) # Non-playable foundations stay below the floors.
				for j in range(4):
					kit.sphere(self,Vector3(x+sin(j*2.2)*2.7,-5.0-j*0.2,z+cos(j*2.2)*2.7),1.8,rock_material)
	build_nav()
	if map_selection<2 and not ResourceLoader.exists("res://assets/v19_panorama.jpg"):build_distant_ruins()
	if map_selection<2:NestV19Scenery.build(self)
	if map_selection==1:
		for sign in find_children("*","Label3D",true,false):
			if sign.billboard!=BaseMaterial3D.BILLBOARD_DISABLED:sign.pixel_size=.0068
			sign.visibility_range_end=45
	set_meta("sanctuary_polish",NestSanctuaryPolish.apply(self))
	set_meta("map_polish",NestMapPolish.apply(self))
	for label in find_children("*","Label3D",true,false):
		if label not in deposit_labels:label.visible=false
	batch_stats=NestStaticBatch.build(self) if not forge_editable else {"editor_unbatched":true}
	apply_map_scale()
	build_weighted_nav()

func forge_auto_group(label: String, origin: Vector3) -> Node3D:
	var piece=Node3D.new();piece.name="ForgeObject_%04d"%forge_auto_count;forge_auto_count+=1
	piece.set_meta("forge_key",String(piece.name));piece.set_meta("forge_label",label);add_child(piece);piece.position=origin;return piece
func forge_group(kind: String, origin: Vector3) -> Node3D:
	var piece=Node3D.new();piece.name="ForgeMapPiece_%03d"%forge_piece_count
	piece.set_meta("forge_key",String(piece.name));piece.set_meta("forge_label",kind)
	forge_piece_count+=1;add_child(piece);piece.position=origin
	return piece
func set_shadows_enabled(enabled: bool) -> void:
	sun.shadow_enabled=enabled
	for light in interior_shadow_lights:light.shadow_enabled=enabled
	for light in forge_lights:
		if is_instance_valid(light):light.shadow_enabled=enabled and bool(light.get_meta("forge_shadow_preference",false))

func build_distant_ruins() -> void:
	# Decorative silhouettes have no collision and sit outside every playable route.
	var far_stone=kit.material(Color("536773"))
	for i in range(9):
		var angle=float(i)*TAU/9+.17
		var pos=Vector3(sin(angle)*118,-10+(i%3)*9,cos(angle)*105)
		var island=kit.sphere(self,pos-Vector3(0,5,0),5.5,far_stone); island.scale=Vector3(1.8,1.9,1.5)
		kit.box(self,pos,Vector3(13,.8,10),far_stone)
		for j in range(4):
			kit.cylinder(self,pos+Vector3((j%2)*7-3.5,3.2+(j%3),floori(j/2.0)*6-3),.6,6.4+(j%3)*2,far_stone)
		kit.box(self,pos+Vector3(0,6.4,0),Vector3(9,.5,8),far_stone)
func floor_at(x: float, y: float, z: float, size: Vector2) -> void:
	kit.floor_tile(self,Vector3(x,y,z),size)
	floor_surfaces.append({"pos":Vector3(x,y,z),"size":size})
func level_at(y: float) -> int:
	if map_selection>=3:return 2 if y>1.5 else 1
	if map_selection==2:return 2 if y>2 else 0 if y< -1 else 1
	if map_selection==1:return 2 if y>=2.2*MAP_SCALE else 1 if y>=-.5 else 0
	return 2 if y>=12*MAP_SCALE else 1 if y>=4*MAP_SCALE else 0
func up_route(title: String, start: Vector3, end: Vector3, width: float, signpost: bool=true) -> void:
	ramp(start,end,width)
	up_routes.append({"name":title,"start":start,"end":end,"width":width})
	if signpost:
		kit.label(self,start+Vector3(0,2,0),title+" ↑",Color("77cbd8"),23)
		kit.label(self,end+Vector3(0,2,0),title+" ↓",Color("dfc890"),20)
func ramp(start: Vector3, end: Vector3, width: float) -> void:
	var center = (start+end)/2
	var horizontal = Vector2(end.x-start.x,end.z-start.z).length()
	var length = start.distance_to(end)
	var node = Node3D.new()
	add_child(node)
	if forge_editable:
		node.name="ForgeMapPiece_%03d"%forge_piece_count;forge_piece_count+=1
		node.set_meta("forge_key",String(node.name));node.set_meta("forge_label","Map ramp")
	node.position = center-Vector3(0,0.15,0)
	node.rotation.y = atan2(end.x-start.x,end.z-start.z)
	node.rotation.x = -atan2(end.y-start.y,horizontal)
	kit.box(node,Vector3.ZERO,Vector3(width,0.3,length),kit.stone,true)
	for x in [-1,1]: kit.box(node,Vector3(x*(width/2-0.07),0.18,0),Vector3(0.1,0.08,length),kit.gold)
func build_ship() -> void:
	var n = Node3D.new();n.name="ExtractionShip"
	add_child(n)
	n.position = ship_position
	kit.box(n,Vector3(0,0.4,0),Vector3(3.5,0.8,6),kit.dark,true).visible=false
	kit.box(n,Vector3(0,1.5,-1.6),Vector3(1.7,1.2,1.6),kit.dark,true).visible=false
	var shuttle=load("res://models/Shuttle.glb").instantiate();n.add_child(shuttle)
	for mesh in shuttle.find_children("*","MeshInstance3D",true,false): solid_mesh(n,mesh,"metal")
	kit.label(self,ship_position+Vector3(0,3,0),"BASE SHIP",Color("dfc890"),30)
	if map_selection>=3:
		floor_cover.append({"pos":Vector3(12,0,31),"size":Vector2(5,7)})
		floor_cover.append({"pos":Vector3(-12,0,-31),"size":Vector2(5,7)})
		var opposite=n.duplicate();opposite.name="OppositeBerth";add_child(opposite);opposite.position=Vector3(-12,0,-31);opposite.rotation.y=PI
	if map_selection==2:floor_cover.append({"pos":Vector3(8,0,33),"size":Vector2(5,7)})
	if map_selection==1:floor_cover.append({"pos":Vector3(13,0,29),"size":Vector2(5,7)})
	# Delivery is on the dry adjacent berth, not inside hull collision.
	ship_position = Vector3(7,0,31) if map_selection>=3 else Vector3(-33,9,3) if map_selection==0 else Vector3(2,0,33) if map_selection==2 else Vector3(9,0,29)
func set_sides(attacking_faction: int, names: Array=["NAKI","ANNU"]) -> void:
	NestV19Map.set_sides(self,attacking_faction)
	flag_labels[0].text = names[attacking_faction]
	flag_labels[1].text = names[1-attacking_faction]
	flag_meshes[0].material_override = kit.green if attacking_faction==0 else kit.red
	flag_meshes[1].material_override = kit.red if attacking_faction==0 else kit.green
func supported(pos: Vector3) -> bool:
	for floor in floor_surfaces:
		if absf(floor.pos.y-pos.y)>.1: continue
		if absf(pos.x-floor.pos.x)<=floor.size.x*.5+.01 and absf(pos.z-floor.pos.z)<=floor.size.y*.5+.01: return true
	return false
func clear_walk(pos: Vector3) -> bool:
	if not supported(pos): return false
	for path in up_routes:
		var delta=Vector2(path.end.x-path.start.x,path.end.z-path.start.z)
		var t=(Vector2(pos.x-path.start.x,pos.z-path.start.z)).dot(delta)/delta.length_squared()
		if t<0 or t>1:continue
		var height=lerpf(path.start.y,path.end.y,t)-pos.y
		if height>.3 and height<3.0 and Vector2(pos.x,pos.z).distance_to(Vector2(path.start.x,path.start.z)+delta*t)<path.width*.5+.5:return false
	for item in floor_cover:
		if absf(item.pos.y-pos.y)<.1 and absf(pos.x-item.pos.x)<item.size.x*.5+.55 and absf(pos.z-item.pos.z)<item.size.y*.5+.55: return false
	return true
func build_nav() -> void:
	var cells={}
	var levels=[0.0,4.0] if map_selection==3 else [0.0,2.8] if map_selection==4 else [0.0,3.2] if map_selection==5 else [0.0,7.0,9.0,14.0,22.8] if map_selection==0 else [-4.0,0.0,3.8] if map_selection==2 else [-2.4,0.0,1.2,2.8]
	for y in levels:
		for x in range(-ceili(bounds.x),ceili(bounds.x)+1,2):
			for z in range(-floori(bounds.y/2)*2,floori(bounds.y/2)*2+1,2):
				var p=Vector3(x,y,z)
				if not clear_walk(p): continue
				cells[Vector3i(x,roundi(y*10),z)]=nav_points.size(); nav_points.append(p)
	for i in range(nav_points.size()): nav_links[i]=[]
	for key in cells:
		for offset in [Vector3i(2,0,0),Vector3i(-2,0,0),Vector3i(0,0,2),Vector3i(0,0,-2)]:
			var next=key+offset
			if not cells.has(next): continue
			var valid=true
			for fraction in [.25,.5,.75]:
				if not clear_walk(Vector3(key.x,key.y/10.0,key.z).lerp(Vector3(next.x,next.y/10.0,next.z),fraction)): valid=false; break
			if valid: nav_links[cells[key]].append(cells[next])
	# Every ramp has explicit intermediate nodes, and each endpoint connects to
	# supported floor nodes with sampled, continuous walking support.
	for path in up_routes:
		var previous=-1
		var count=ceili(path.start.distance_to(path.end)/3.0)
		for step in range(count+1):
			var pos: Vector3=path.start.lerp(path.end,float(step)/count)
			var index=nav_points.size(); nav_points.append(pos); nav_links[index]=[]
			if previous>=0: nav_links[index].append(previous); nav_links[previous].append(index)
			previous=index
			if step not in [0,count]: continue
			for other in range(index):
				var dest=nav_points[other]
				if absf(dest.y-pos.y)>.1 or dest.distance_to(pos)>6.0: continue
				var valid=true
				for fraction in [.2,.4,.6,.8]:
					if not clear_walk(pos.lerp(dest,fraction)): valid=false; break
				if valid: nav_links[index].append(other); nav_links[other].append(index)
	# Launch edges are directed; walking back along a ballistic path is impossible.
	for path in cannon_routes:
		var start=nearest_nav(path.start);var finish=nearest_nav(path.end)
		if start!=finish and not nav_links[start].has(finish):nav_links[start].append(finish)
func nearest_nav(pos: Vector3) -> int:
	if query_index.ready and query_index.point_count==nav_points.size():return query_index.nearest(pos,nav_points,blocked_nav)
	var best = 0
	var dist = INF
	for i in range(nav_points.size()):
		if blocked_nav.has(i):continue
		var d = pos.distance_squared_to(nav_points[i])
		if d<dist: best=i; dist=d
	return best
func build_weighted_nav() -> void:
	blocked_nav.clear();navigation_revision+=1
	query_index.rebuild(nav_points,floor_surfaces,map_selection==2)
	nav_graph.clear(); nav_graph.reserve_space(nav_points.size())
	for i in range(nav_points.size()): nav_graph.add_point(i,nav_points[i])
	for id in nav_links:
		for next in nav_links[id]:
			if not nav_graph.are_points_connected(id,next,false): nav_graph.connect_points(id,next,false)
	if not forge_editable:call_deferred("validate_navigation",navigation_revision)
func validate_navigation(revision: int) -> void:
	if not is_inside_tree():return
	var tree=get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree() or revision!=navigation_revision or forge_editable:return
	# A load-time query against actual static collision catches pillars, trim,
	# ceilings and other authored solids missing from the floor-cover metadata.
	var shape=CapsuleShape3D.new();shape.radius=NestActor.BODY_RADIUS;shape.height=NestActor.STAND_HEIGHT
	var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.collide_with_areas=false;query.margin=0.0
	var viewport=get_viewport()
	if viewport==null:return
	var world=viewport.find_world_3d()
	if world==null:return
	var space=world.direct_space_state
	for id in blocked_nav:nav_graph.set_point_disabled(id,false)
	blocked_nav.clear()
	for i in range(nav_points.size()):
		query.transform=Transform3D(Basis.IDENTITY,nav_points[i]+Vector3.UP*(NestActor.STAND_CENTER+.12))
		if not space.intersect_shape(query,1).is_empty():blocked_nav[i]=true;nav_graph.set_point_disabled(i,true)
	set_meta("navigation_blocked_cells",blocked_nav.size())
func route(start: Vector3, finish: Vector3,avoid: Array=[]) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if nav_graph.get_point_count()==0: return result
	var source=nearest_nav(start);var target=nearest_nav(finish)
	if not avoid.is_empty():
		var ignored=blocked_nav.duplicate()
		for id in avoid:ignored[id]=true
		source=query_index.nearest(start,nav_points,ignored);target=query_index.nearest(finish,nav_points,ignored)
	for id in avoid:nav_graph.set_point_disabled(id,true)
	result.assign(nav_graph.get_point_path(source,target))
	for id in avoid:
		if not blocked_nav.has(id):nav_graph.set_point_disabled(id,false)
	if not result.is_empty() and has_walk_support(finish,.65): result.append(finish)
	return result
func recovery_route(game: Node3D,start: Vector3,finish: Vector3,exclude: Array[RID],avoid: Array) -> Array[Vector3]:
	# Rare bounded recovery: choose a physically reachable graph entrance, and
	# temporarily omit recently blocked cells instead of chasing the same corner.
	var candidates=[]
	for i in range(nav_points.size()):
		if blocked_nav.has(i) or i in avoid or absf(nav_points[i].y-start.y)>.6:continue
		var distance=start.distance_squared_to(nav_points[i])
		if distance<64:candidates.append({"id":i,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for id in avoid:nav_graph.set_point_disabled(id,true)
	var result: Array[Vector3]=[]
	var finish_id=nearest_nav(finish)
	for candidate in candidates.slice(0,12):
		var pos=nav_points[candidate.id]
		if not walk_segment_clear(game,start,pos,exclude):continue
		var path=nav_graph.get_point_path(candidate.id,finish_id)
		if path.is_empty():continue
		result.assign(path)
		if has_walk_support(finish,.65):result.append(finish)
		break
	for id in avoid:
		if not blocked_nav.has(id):nav_graph.set_point_disabled(id,false)
	return result
func has_walk_support(pos: Vector3, tolerance: float=.5) -> bool:
	if not query_index.ready or query_index.floor_count!=floor_surfaces.size():query_index.rebuild(nav_points,floor_surfaces,map_selection==2)
	if map_selection==2:
		var corners_supported=true
		for offset in SUPPORT_CORNERS:
			if not query_index.floor_at(pos+Vector3(offset.x,0,offset.y),tolerance,-.001):corners_supported=false;break
		if corners_supported:return true
	if query_index.floor_at(pos,tolerance,.32):return true
	for path in up_routes:
		var start=Vector2(path.start.x,path.start.z);var delta=Vector2(path.end.x,path.end.z)-start
		var t=(Vector2(pos.x,pos.z)-start).dot(delta)/delta.length_squared()
		if t<0 or t>1:continue
		if Vector2(pos.x,pos.z).distance_to(start+delta*t)<path.width*.5-.32 and absf(pos.y-lerpf(path.start.y,path.end.y,t))<=tolerance:return true
	return false
func bot_surface_height(point: Vector3,reference: float,max_delta: float=1.5) -> float:
	# Steering support on authored ramps; never changes collision or player physics.
	var best=INF;var difference=max_delta
	if not query_index.ready:query_index.rebuild(nav_points,floor_surfaces,map_selection==2)
	for slab in query_index.floors.get(query_index.cell(point),[]):
		if absf(point.x-slab.pos.x)>slab.size.x*.5-.28 or absf(point.z-slab.pos.z)>slab.size.y*.5-.28:continue
		var d=absf(float(slab.pos.y)-reference)
		if d<difference:best=slab.pos.y;difference=d
	if difference<.12:return best
	for path in up_routes:
		var start=Vector2(path.start.x,path.start.z);var line=Vector2(path.end.x,path.end.z)-start
		if line.length_squared()<.001:continue
		var t=(Vector2(point.x,point.z)-start).dot(line)/line.length_squared()
		if t<0 or t>1 or Vector2(point.x,point.z).distance_to(start+line*t)>path.width*.5-.28:continue
		var height=lerpf(path.start.y,path.end.y,t);var d=absf(height-reference)
		if d<difference:best=height;difference=d
	return best
func walk_segment_clear(game: Node3D, start: Vector3, end: Vector3, exclude: Array[RID]) -> bool:
	if absf(start.y-end.y)>.4: return false
	if not query_index.ready or query_index.floor_count!=floor_surfaces.size():query_index.rebuild(nav_points,floor_surfaces,map_selection==2)
	if not query_index.segment_on_floor(start,end):
		var count=ceili(start.distance_to(end)/.5)
		for i in range(1,count+1):
			if not has_walk_support(start.lerp(end,float(i)/count),.5): return false
	for height in [.55,1.45]:
		if not game.trace(start+Vector3.UP*height,end+Vector3.UP*height,1,exclude).is_empty(): return false
	return true
func set_site_visual(index: int, stage: String, clock: float) -> void:
	var node=deposits[index]
	var bomb_only=bool(get_meta("bomb_only",false))
	if node.has_node("ObjectivePlinth"):node.get_node("ObjectivePlinth").scale.y=.1 if bomb_only else 1.0
	for body in sealed_bodies[index]: body.collision_layer=1 if not bomb_only and node.visible and stage in ["sealed","planted"] else 0
	node.get_node("Sealed").visible=not bomb_only and stage in ["sealed","planted"]
	node.get_node("Opened").visible=not bomb_only and stage not in ["sealed","planted"]
	node.get_node("Opened/Rotor").rotation.y=clock*8 if stage=="drilling" else 0
	node.get_node("Opened/DrillAnimation").set_working(stage=="drilling")

func apply_map_scale() -> void:
	# Horizontal widening only: player size, jump height and floor elevations stay unchanged.
	var stretch=Vector3(MAP_SCALE*width_multiplier(),MAP_SCALE,MAP_SCALE*length_multiplier())
	scale=stretch;bounds*=Vector2(stretch.x,stretch.z)
	# Widen architecture and placement, keeping weapons, objective art and
	# traversal trigger footprints at their established size.
	var fixed_size: Array=deposits+pad_meshes
	var ship=get_node_or_null("ExtractionShip")
	if ship!=null:fixed_size.append(ship)
	var berth=get_node_or_null("OppositeBerth")
	if berth!=null:fixed_size.append(berth)
	for node in get_children():
		if node is NestManCannon or node.name=="U2Lift":fixed_size.append(node)
	for node in fixed_size:node.scale.x/=width_multiplier();node.scale.z/=length_multiplier()
	var lift=get_node_or_null("U2Lift")
	if lift!=null:lift.map_scale=MAP_SCALE;lift.shaft_position=Vector2(39*stretch.x,0)
	for i in range(sites.size()):sites[i]*=stretch
	for i in range(pads.size()):pads[i]*=stretch
	ship_position*=stretch
	for faction in spawns:
		for i in range(spawns[faction].size()):
			spawns[faction][i]*=stretch
			spawns[faction][i].y+=.08*(1-MAP_SCALE)
	for i in range(nav_points.size()):nav_points[i]*=stretch
	for floor in floor_surfaces:floor.pos*=stretch;floor.size*=Vector2(stretch.x,stretch.z)
	for cover in floor_cover:cover.pos*=stretch;cover.size*=Vector2(stretch.x,stretch.z)
	for path in up_routes:
		path.start*=stretch;path.end*=stretch
		# Width is measured perpendicular to the ramp's horizontal direction.
		var direction=Vector2(path.end.x-path.start.x,path.end.z-path.start.z).normalized()
		var side=Vector2(direction.y/stretch.z,-direction.x/stretch.x).normalized()
		path.width*=Vector2(side.x*stretch.x,side.y*stretch.z).length()
	for path in cannon_routes:path.start*=stretch;path.end*=stretch
	flag_positions.assign([Vector3(0,.08,31)*stretch,Vector3(0,.08,-31)*stretch] if map_selection>=3 else [Vector3(-32,9,.0)*stretch,Vector3(32,9,.0)*stretch] if map_selection==0 else [Vector3(-5,0,33)*stretch,Vector3(0,0,-35)*stretch] if map_selection==2 else [Vector3(0,0,30)*stretch,Vector3(0,0,-32)*stretch])
	# Static physics transforms must be orthonormal. Bake the actual stretched
	# geometry, avoiding enlarged circular colliders or nonuniform-scale surprises.
	if not is_equal_approx(width_multiplier()*length_multiplier(),1.0):bake_stretched_collision()
const STRETCHED_CYLINDER_ERROR_M=.002
static func stretched_cylinder_points(source: CylinderShape3D,world_basis: Basis) -> PackedVector3Array:
	# Bound any radial stretch/shear using the radial plane's Frobenius norm.
	# Include the old debug ring's chord error in the relative error budget.
	var radius_bound=source.radius*sqrt(world_basis.x.length_squared()+world_basis.z.length_squared())
	var reference_error=radius_bound*(1-cos(PI/360.0))
	var vertices=PackedVector3Array()
	if reference_error>=STRETCHED_CYLINDER_ERROR_M:
		# Exceptional huge Forge geometry keeps its original representation.
		var mesh=source.get_debug_mesh()
		for surface in range(mesh.get_surface_count()):vertices.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		return vertices
	var segments=64
	while radius_bound*(1-cos(PI/segments))+reference_error>STRETCHED_CYLINDER_ERROR_M:segments*=2
	for i in range(segments):
		var angle=TAU*float(i)/segments
		var radial=Vector3(sin(angle)*source.radius,0,cos(angle)*source.radius)
		vertices.append(radial+Vector3.UP*source.height*.5)
		vertices.append(radial-Vector3.UP*source.height*.5)
	return vertices
func bake_stretched_collision() -> void:
	for body in find_children("*","StaticBody3D",true,false):
		var shapes=[]
		for collision in body.get_children():
			if not collision is CollisionShape3D or collision.shape==null:continue
			var vertices=PackedVector3Array();var source=collision.shape
			if source is ConvexPolygonShape3D:vertices=source.points
			elif source is ConcavePolygonShape3D:vertices=source.get_faces()
			elif source is BoxShape3D:
				for i in range(8):vertices.append(Vector3(1 if i&1 else -1,1 if i&2 else -1,1 if i&4 else -1)*source.size*.5)
			elif source is CylinderShape3D:
				vertices=stretched_cylinder_points(source,collision.global_basis)
			else:
				var mesh=source.get_debug_mesh()
				for surface in range(mesh.get_surface_count()):vertices.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			var points=PackedVector3Array();var origin: Vector3=body.global_position
			for vertex in vertices:points.append(collision.global_transform*vertex-origin)
			var shape=ConcavePolygonShape3D.new() if source is ConcavePolygonShape3D else ConvexPolygonShape3D.new()
			if shape is ConcavePolygonShape3D:shape.set_faces(points)
			else:shape.points=points
			shapes.append({"node":collision,"shape":shape})
		body.global_transform=Transform3D(Basis.IDENTITY,body.global_position)
		for item in shapes:item.node.transform=Transform3D.IDENTITY;item.node.shape=item.shape

func solid_mesh(parent: Node3D, mesh: MeshInstance3D, material: String="concrete") -> StaticBody3D:
	if forge_editable and mesh.get_parent().has_meta("forge_key"):parent=mesh.get_parent()
	var transform=parent.global_transform.affine_inverse()*mesh.global_transform
	var points=PackedVector3Array()
	for surface in range(mesh.mesh.get_surface_count()):
		for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points.append(transform*vertex)
	var shape=ConvexPolygonShape3D.new();shape.points=points
	var body=StaticBody3D.new();body.name="SolidScenery";body.collision_layer=1;body.set_meta("surface_material",material);parent.add_child(body)
	var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);solid_art_bodies.append(body)
	mesh.set_meta("forge_solid_body",body)
	return body
