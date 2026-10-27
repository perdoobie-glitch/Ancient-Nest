class_name NestCampaignChapterWorld
extends NestCampaignWorld
# Authored expedition spaces. The controller owns objectives, damage and saves;
# this world owns reproducible geometry and the visible state of each machine.
var mission_index=3
var current_stage=0
var chapter_data={}
var devices=[]
var water_planes=[]
var status_lights=[]
var bird_root: Node3D
var boss_root: Node3D
var boss_arms=[]
var boss_warnings=[]
var boss_cores=[]
var rng=RandomNumberGenerator.new()
var scenery: NestCampaignScenery
var copper: Material
var teal: Material
var warning: Material
var active_material: Material
var water_material: Material
var road_data={}
var stage_gates=[]
var seal_fragments=[]
var terrain_patches=[]
var terrain_cells={}
var cache_anchors: Array[Vector3]=[]
var raised_cache_sites=[]
var detail_modules=[]
var narrative_indicators=[]
var narrative_rotors=[]
var narrative_panels=[]
var terrain_stats={"platforms":0,"ramps":0,"min_height":0.0,"max_height":0.0}
const TERRACE_HEIGHTS={3:[0.0,5.0,10.0,4.0],4:[0.0,6.0,12.0,18.0],5:[4.0,0.0,7.0,13.0],6:[0.0,6.0,1.0,9.0],7:[2.0,9.0,16.0,24.0],8:[8.0,3.0,-2.0,-7.0]}

func map_title() -> String:return "Old Earth / "+str(chapter_data.get("title","Return Expedition"))

func _ready():
 region="chapter_"+str(mission_index);rng.seed=260026+mission_index
 var book=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_chapters.json"))
 for entry in book.chapters:
  if int(entry.index)==mission_index:chapter_data=entry
 pads.clear();pad_meshes.clear();pad_kinds.clear();pad_names.clear()
 spawns={0:[],1:[]};sites=[Vector3.ZERO,Vector3.ZERO];flag_positions=[Vector3.ZERO,Vector3.ZERO]
 for i in range(2):
  var deposit=Node3D.new();add_child(deposit);deposits.append(deposit)
  var label=Label3D.new();deposit.add_child(label);deposit_labels.append(label);sealed_bodies.append([])
 scene_root=Node3D.new();scene_root.name="ChapterArchitecture";add_child(scene_root)
 environment_setup();configure_environment()
 copper=kit.material(Color("a16c42"),.55);teal=kit.material(Color("3e777d"),.25)
 warning=kit.material(Color("e69b3b"),.1);active_material=kit.material(Color("72d49e"),.2)
 active_material.emission_enabled=true;active_material.emission=Color("45b784");active_material.emission_energy_multiplier=.4
 water_material=kit.material(Color("214f5c"),.45);water_material.roughness=.21
 scenery=NestCampaignScenery.new(self)
 if mission_index==2:
  var bike_script=load("res://scripts/campaign_motorcycle_world.gd")
  bike_script.build_world(self)
 else:
  build_layout()
  match mission_index:
   3:build_floodgate()
   4:build_sanctuary()
   5:build_foundry()
   6:build_rail()
   7:build_sky_mirror()
   8:build_reserve()
   9:build_ancient_nest()
  enrich_environment();build_vertical_details();build_objectives();build_narrative_details()
  var detail_paths={3:"res://scripts/campaign_floodgate_archive_details.gd",4:"res://scripts/campaign_floodgate_archive_details.gd",5:"res://scripts/campaign_foundry_rail_details.gd",6:"res://scripts/campaign_foundry_rail_details.gd"}
  for detail_path in ([detail_paths[mission_index]] if detail_paths.has(mission_index) else []):
   if FileAccess.file_exists(detail_path):
    var detail_script=load(detail_path);detail_script.build(self);detail_modules.append(detail_script)
  build_routes();build_birds()
 for device in devices:device.set_meta("rest_basis",device.basis)
 set_stage(0);batch_campaign_scenery()

func configure_environment():
 var colors={3:"7c9a9d",4:"a59a78",5:"6b5144",6:"29384c",7:"aa7e71",8:"536875",9:"544d56"}
 ambience.fog_light_color=Color(colors.get(mission_index,"5e7d70"));ambience.fog_density=.0027
 ambience.ambient_light_energy=.46 if mission_index in [3,4,7] else .37
 sun.light_color=Color("ffd5a2") if mission_index in [4,5,7,9] else Color("c0dbe5")
 sun.light_energy=.8 if mission_index in [3,4,7] else .55
 if mission_index==6:sun.rotation_degrees=Vector3(-12,-35,0)
 elif mission_index==7:sun.rotation_degrees=Vector3(-9,45,0)
 var stone_colors={3:"657b7f",4:"a39a7b",5:"5c6265",6:"4d5d6b",7:"8b7770",8:"626b73",9:"4f4b53"}
 palette.rock=kit.material(Color(stone_colors.get(mission_index,"697c70")),.08)
 palette.rock.roughness=.9
 if mission_index>=7:palette.rock=detail_surface(Color(stone_colors[mission_index]),Color(stone_colors[mission_index]).darkened(.26))
 var sky_material=ambience.sky.sky_material
 if sky_material is ProceduralSkyMaterial:
  sky_material.sky_top_color=Color("1f2839") if mission_index in [6,8,9] else Color("567c8d")
  sky_material.sky_horizon_color=Color(colors.get(mission_index,"738c7e"))
  sky_material.ground_horizon_color=sky_material.sky_horizon_color

func stage_center(stage: int) -> Vector3:
 if mission_index==9:return Vector3(0,0,-55)
 return Vector3(0,terrace_height(stage),-55*clampi(stage,0,3))

func terrace_height(stage: int) -> float:
 return float(TERRACE_HEIGHTS.get(mission_index,[0.0,0.0,0.0,0.0])[clampi(stage,0,3)])

func objective_position(stage: int) -> Vector3:
 if mission_index==9:return [Vector3(-28,4,-38),Vector3(28,8,-65),Vector3(-25,12,-88),Vector3(0,6,-166)][clampi(stage,0,3)]
 if mission_index==7:return stage_center(stage)+Vector3(-12 if stage%2==0 else 12,0,-8)
 return stage_center(stage)+Vector3(-22 if stage%2==0 else 22,0,-8)

func checkpoint_spawn(stage: int,slot: int) -> Vector3:
 if mission_index==2:return NestCampaignMotorcycleWorld.spawn(stage,slot)
 var base=Vector3(0,terrace_height(0)+.25,30) if stage==0 else stage_center(stage)+Vector3(0,.25,18)
 if mission_index==9:base=Vector3(0,.25,14)
 return base+Vector3((posmod(slot-1,4)-1.5)*1.7,0,0)

func encounter_spawns(stage: int) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 if mission_index==2:
  return NestCampaignMotorcycleWorld.encounter_spawns(stage)
 var center=stage_center(stage)
 if mission_index==9:center=Vector3(0,6,-156) if stage==3 else Vector3(0,0,-55)
 for offset in [Vector3(-38,0,-14),Vector3(38,0,-14),Vector3(-34,0,6),Vector3(34,0,6),Vector3(-16,0,-21),Vector3(16,0,-21),Vector3(-38,0,14),Vector3(38,0,14),Vector3(-12,0,-10),Vector3(12,0,-10),Vector3(-30,0,-20),Vector3(30,0,-20)]:
  var candidate=center+offset
  candidate.y=surface_height(candidate)
  if not blocked_point(candidate):result.append(candidate+Vector3.UP*.25)
 # Deterministic, navigable replacements when a mission's machinery occupies an approach.
 var wanted=maxi(12,int(chapter_data.stages[clampi(stage,0,chapter_data.stages.size()-1)].enemies))
 for x in range(-38,39,4):
  for z in range(-20,21,8):
   var candidate=center+Vector3(x,0,z)
   candidate.y=surface_height(candidate)
   if result.size()<wanted and not blocked_point(candidate) and candidate.distance_to(objective_position(stage))>5:result.append(candidate+Vector3.UP*.25)
 return result

func route_encounter_spawns(stage: int,band: int=0) -> Array[Vector3]:
 if mission_index==2:return NestCampaignMotorcycleWorld.encounter_spawns(stage)
 var result: Array[Vector3]=[];var center=Vector3(0,6,-156) if mission_index==9 and stage==3 else stage_center(stage)
 var ahead=[14.0,0.0,-15.0][posmod(band,3)]
 for x in [-36,-28,-20,20,28,36,-12,12]:
  var p=center+Vector3(x,0,ahead);p.y=surface_height(p)
  if not blocked_point(p):result.append(p+Vector3.UP*.25)
 if band>=3 and stage<3 and mission_index!=9:
  for x in [-5,5]:
   var p=Vector3(x,0,center.z-25);p.y=surface_height(p)
   if not blocked_point(p):result.append(p+Vector3.UP*.25)
 if result.is_empty():return encounter_spawns(stage)
 return result

func build_layout():
 var floor_colors={3:"50666a",4:"777b68",5:"3d454a",6:"34424e",7:"746d62",8:"394653",9:"302f37"}
 var floor_material=kit.material(Color(floor_colors.get(mission_index,"50605a")),.12)
 floor_material.roughness=.88
 if mission_index>=7:floor_material=detail_surface(Color(floor_colors[mission_index]),Color(floor_colors[mission_index]).lightened(.12),.3)
 build_playable_terrain(floor_material)
 for side in [-1,1]:
  for level in range(4):
   var height=terrace_height(level)
   block(Vector3(side*56,height+6,-level*55),Vector3(8,12,55),palette.rock)
  for i in range(12):
   var p=Vector3(side*(59+rng.randf_range(1,9)),rng.randf_range(4,8),32-i*22)
   var rock=kit.sphere(scene_root,p,rng.randf_range(8,14),palette.rock);rock.scale=Vector3(.8,1.6,1.3)
 block(Vector3(0,terrace_height(0)+5,48),Vector3(118,10,4),palette.rock)
 block(Vector3(0,(6 if mission_index==9 else terrace_height(3))+5,-204),Vector3(118,10,4),palette.rock)
 for i in range(4):spawns[0].append(Vector3((i-1.5)*1.7,terrace_height(0),30))
 spawns[1]=[Vector3(-34,terrace_height(0),-10),Vector3(34,terrace_height(0),-10)]
 for i in range(4):
  var p=stage_center(i)
  if mission_index==9 and i>0:continue
  for side in [-1,1]:
   for j in range(3):
    var cover=p+Vector3(side*(12+j*13),.8,9 if j%2==0 else -18)
    block(cover,Vector3(4.5,1.6,1.1),palette.rock);cover_points.append(cover+Vector3(0,-.8,2))
    for k in range(3):block(cover+Vector3(-1.3+k*1.2,.83,0),Vector3(.8,.08,1.2),copper,false)
  for z in range(-20,24,6):
   block(p+Vector3(-2,.025,z),Vector3(.08,.035,2.3),kit.gold,false)
   block(p+Vector3(2,.025,z),Vector3(.08,.035,2.3),kit.gold,false)
  if i<3 and mission_index!=9:
   var arch=Vector3(0,lerpf(terrace_height(i),terrace_height(i+1),8.0/15.0),-28-i*55)
   for side in [-1,1]:block(arch+Vector3(side*9,4,0),Vector3(1.8,8,2.1),palette.rock)
   block(arch+Vector3(0,8,0),Vector3(20,1.5,2.1),palette.rock)
   var abutment_bottom=minf(terrace_height(i),terrace_height(i+1))-8
   var abutment_top=arch.y+7
   for side in [-1,1]:block(Vector3(side*32,(abutment_bottom+abutment_top)*.5,arch.z),Vector3(46,abutment_top-abutment_bottom,2),palette.rock)
   make_stage_gate(arch,i)
   sign_at(arch+Vector3(0,6.2,1.2),"0"+str(i+2)+"  /  "+str(chapter_data.title).to_upper(),Color("dec69b"),20)
 scenery.mountain_range()

func make_stage_gate(at: Vector3,index: int):
 var gate=Node3D.new();gate.name="RouteInterlock"+str(index);scene_root.add_child(gate);gate.position=at
 kit.box(gate,Vector3(0,3,0),Vector3(16,6,.8),palette.rock if mission_index==8 else palette.tower_slate)
 for x in range(-7,8,2):kit.box(gate,Vector3(x,3,.43),Vector3(.12,5.8,.08),copper)
 kit.box(gate,Vector3(0,4,.5),Vector3(5,.13,.06),warning)
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;gate.add_child(body)
 var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(16,6,.8);collider.shape=shape;collider.position.y=3;body.add_child(collider)
 stage_gates.append({"root":gate,"shape":collider,"at":at,"index":index})
 if mission_index==8 and index==0:
  sign_at(at+Vector3(0,5.2,1),"SEALED GALLERY / SURVEY CHARGE ACCESS",Color("e7cb85"),23)
  for i in range(12):
   var fragment=block(at+Vector3(-7+i*1.2,.2,1.8+sin(i)*1.2),Vector3(.7,.4,.8),palette.rock,false)
   fragment.set_meta("keep_mesh",true);fragment.hide();seal_fragments.append(fragment)

func add_terrace(at: Vector3,size: Vector2,mat: Material):
 kit.box(scene_root,at-Vector3.UP*.65,Vector3(size.x,1.3,size.y),mat,true)
 if size.x>70:
  # Exposed retaining foundations connect the changing floor levels to the canyon bed.
  var bottom=-22.0;var top=at.y-1.2
  kit.box(scene_root,Vector3(at.x,(bottom+top)*.5,at.z),Vector3(size.x-.8,top-bottom,size.y-.8),palette.rock,true)
 terrain_patches.append({"kind":"flat","at":at,"size":size})
 floor_surfaces.append({"pos":at,"size":size})
 terrain_stats.platforms+=1;terrain_stats.min_height=minf(terrain_stats.min_height,at.y);terrain_stats.max_height=maxf(terrain_stats.max_height,at.y)
 # A structural skirt makes the plateau read as masonry, not a hovering floor.
 for side in [-1,1]:
  var edge=at+Vector3(side*(size.x*.5-.25),-2.0,0)
  kit.box(scene_root,edge,Vector3(.5,3.9,size.y),palette.rock,false)

func add_ramp(start: Vector3,finish: Vector3,width: float,mat: Material):
 var direction=(finish-start);direction.y=0;direction=direction.normalized()
 var side=Vector3(-direction.z,0,direction.x)*width*.5
 var a=start-side;var b=start+side;var c=finish-side;var d=finish+side
 var bottom=minf(start.y,finish.y)-1.3
 var aa=Vector3(a.x,bottom,a.z);var bb=Vector3(b.x,bottom,b.z);var cc=Vector3(c.x,bottom,c.z);var dd=Vector3(d.x,bottom,d.z)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var triangles=[]
 for tri in [[a,b,c],[b,d,c],[aa,cc,bb],[bb,cc,dd],[a,aa,b],[b,aa,bb],[c,d,cc],[d,dd,cc],[a,c,aa],[c,cc,aa],[b,bb,d],[d,bb,dd]]:
  triangles.append_array(tri)
  var normal=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  for point in tri:tool.set_normal(normal);tool.set_uv(Vector2(point.x,point.z)*.12);tool.add_vertex(point)
 var mesh=kit.mesh(scene_root,tool.commit(),Vector3.ZERO,mat);mesh.name="WalkableRampBridge"
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;scene_root.add_child(body);body.position=(start+finish)*.5
 var faces=PackedVector3Array()
 for point in triangles:faces.append(point-body.position)
 var collision=CollisionShape3D.new();var hull=ConcavePolygonShape3D.new();hull.set_faces(faces);hull.backface_collision=true;collision.shape=hull;body.add_child(collision)
 terrain_patches.append({"kind":"ramp","a":start,"b":finish,"width":width})
 terrain_stats.ramps+=1
 for edge_side in [-1,1]:
  # Handrails run above both edges; a central sixteen-metre lane stays clear.
  var offset=side*edge_side
  pipe(start+offset+Vector3.UP*1.1,finish+offset+Vector3.UP*1.1,.07,copper)
  for step in range(6):
   var at=start.lerp(finish,step/5.0)+offset
   block(at+Vector3.UP*.55,Vector3(.14,1.1,.14),copper,true)
 for step in range(1,9):
  var at=start.lerp(finish,step/9.0)+Vector3.UP*.025
  # Side studs identify the incline without resembling a barrier across the lane.
  for edge_side in [-1,1]:block(at+side*edge_side*.88,Vector3(.16,.035,.16),warning,false)

func build_playable_terrain(mat: Material):
 terrain_patches.clear();terrain_cells.clear();floor_surfaces.clear();cache_anchors.clear();raised_cache_sites.clear();bounds=Vector2(54,205)
 terrain_stats={"platforms":0,"ramps":0,"min_height":INF,"max_height":-INF}
 if mission_index==9:
  add_terrace(Vector3(0,0,-28),Vector2(104,146),mat)
  add_terrace(Vector3(0,6,-166),Vector2(104,72),mat)
  add_ramp(Vector3(0,0,-101),Vector3(0,6,-130),20,palette.panel)
  for spec in [[Vector3(-30,4,-37),Vector2(24,20),Vector3(-2,0,-37),Vector3(-18,4,-37)], [Vector3(30,8,-65),Vector2(24,22),Vector3(2,0,-65),Vector3(18,8,-65)], [Vector3(-27,12,-90),Vector2(22,20),Vector3(8,0,-90),Vector3(-16,12,-90)]]:
   add_terrace(spec[0],spec[1],palette.tower_slate);add_ramp(spec[2],spec[3],10,palette.panel)
  cache_anchors.assign([Vector3(-34,4,-31),Vector3(35,8,-72),Vector3(-33,12,-96),Vector3(-30,0,12),Vector3(30,0,-20),Vector3(19,6,-147)])
 else:
  for stage in range(4):
   var center=stage_center(stage)
   var platform_center=center+Vector3(0,0,13 if stage==0 else -8 if stage==3 else 0)
   add_terrace(platform_center,Vector2(104,66 if stage==0 else 56 if stage==3 else 40),mat)
   if stage<3:
    add_ramp(center+Vector3(0,0,-20),stage_center(stage+1)+Vector3(0,0,20),16,palette.panel)
   var side=-1 if stage%2 else 1
   var deck=center+Vector3(side*32,3.2,16)
   var start=center+Vector3(side*17,0,16)
   var finish=center+Vector3(side*25,3.2,16)
   if mission_index==6:
    deck=center+Vector3(-36,3.2,0);start=center+Vector3(-12,0,0);finish=center+Vector3(-29,3.2,0)
   add_terrace(deck,Vector2(14,10),palette.tower_slate);add_ramp(start,finish,8,palette.panel)
   raised_cache_sites.append(deck)
   cache_anchors.append(deck+Vector3(0,0,-1.4))
   cache_anchors.append(center+Vector3(-7,0,4))
 # The visible underside does not catch players who deliberately jump out of the guarded route.
 var low=-22.0
 kit.box(scene_root,Vector3(0,low,-80),Vector3(150,1,280),palette.rock,false)
 index_terrain_patches()
 set_meta("vertical_terrain",terrain_stats)

func index_terrain_patches():
 # Query only the few platforms/bridges in a sixteen-metre cell. This preserves
 # the exact analytic surface while avoiding a full patch scan for each nav sample.
 terrain_cells.clear()
 for patch in terrain_patches:
  var low: Vector2;var high: Vector2
  if patch.kind=="flat":
   var center=Vector2(patch.at.x,patch.at.z);low=center-patch.size*.5;high=center+patch.size*.5
  else:
   var a=Vector2(patch.a.x,patch.a.z);var b=Vector2(patch.b.x,patch.b.z)
   var along=b-a;var side=Vector2(-along.y,along.x).normalized()*patch.width*.5
   patch["along"]=along;patch["length_squared"]=along.length_squared();patch["unit_along"]=along.normalized()
   low=a.min(b)-side.abs();high=a.max(b)+side.abs()
  low-=Vector2.ONE*.05;high+=Vector2.ONE*.05
  for x in range(floori(low.x/16),floori(high.x/16)+1):
   for z in range(floori(low.y/16),floori(high.y/16)+1):
    var key=Vector2i(x,z)
    if not terrain_cells.has(key):terrain_cells[key]=[]
    terrain_cells[key].append(patch)

func surface_height(point: Vector3) -> float:
 if mission_index==2:return NestCampaignMotorcycleWorld.surface_height(point)
 var result=-1000.0
 var candidates=terrain_cells.get(Vector2i(floori(point.x/16),floori(point.z/16)),[]) if not terrain_cells.is_empty() else terrain_patches
 for patch in candidates:
  if patch.kind=="flat":
   var delta=point-patch.at
   if absf(delta.x)<=patch.size.x*.5+.015 and absf(delta.z)<=patch.size.y*.5+.015:result=maxf(result,patch.at.y)
  else:
   var along=patch.get("along",Vector2(patch.b.x-patch.a.x,patch.b.z-patch.a.z));var offset=Vector2(point.x-patch.a.x,point.z-patch.a.z)
   var progress=offset.dot(along)/float(patch.get("length_squared",along.length_squared()));var across=absf(offset.cross(patch.get("unit_along",along.normalized())))
   if progress>=-.001 and progress<=1.001 and across<=patch.width*.5+.015:result=maxf(result,lerpf(patch.a.y,patch.b.y,clampf(progress,0,1)))
 return result

func weapon_cache_points() -> Array[Vector3]:
 if mission_index==2:return NestCampaignMotorcycleWorld.weapon_cache_points()
 return cache_anchors.duplicate()

func boss_attack_origin() -> Vector3:return Vector3(0,16,-55)

func build_objectives():
 for i in range(chapter_data.stages.size()):
  var p=objective_position(i);var entry=chapter_data.stages[i]
  station("objective"+str(i),p,str(entry.title).to_upper())
  var indicator=block(p+Vector3(0,1.7,-.2),Vector3(.6,.14,.16),warning,false)
  indicator.set_meta("keep_mesh",true);status_lights.append(indicator)
  var supply=stage_center(i)+Vector3(8,0,14)
  if mission_index==9:supply=Vector3(-35+i*21,0,17)
  station("supply"+str(i),supply,"EXPEDITION RESUPPLY")
  scenery.cargo(supply+Vector3(2,0,-.3),teal,i)
  var marker=ring(p+Vector3(0,.05,1.6),2.1,.05,kit.gold);marker.rotation.x=0
 locations["exit"]=Vector3(0,6 if mission_index==9 else terrace_height(3),-190)
 for i in range(2):
  var evidence=Vector3(18 if i==0 else -18,0,-42 if i==0 else -114)
  if mission_index==9:evidence=Vector3(32,0,-35) if i==0 else Vector3(-34,12,-84)
  evidence.y=surface_height(evidence)
  station("evidence"+str(i),evidence,"ARCHIVE / OPTIONAL FIELD RECORD")
  block(evidence+Vector3(0,1.5,-.3),Vector3(2,.2,1),copper,false)
 sign_at(Vector3(0,terrace_height(0)+4,39),"EXPEDITION / "+str(mission_index).pad_zeros(2)+"\n"+str(chapter_data.title).to_upper(),Color("c2ebda"),32)

func ring(p: Vector3,radius: float,thickness: float,mat: Material) -> MeshInstance3D:
 var shape=TorusMesh.new();shape.inner_radius=maxf(.01,radius-thickness);shape.outer_radius=radius+thickness;shape.rings=20;shape.ring_segments=6
 return kit.mesh(scene_root,shape,p,mat)

func tube(p: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=12
 return kit.mesh(scene_root,shape,p,mat)

func solid_cylinder(p: Vector3,radius: float,height: float,mat: Material):
 kit.cylinder(scene_root,p,radius,height,mat,true)
 floor_cover.append({"position":p,"size":Vector3(radius*2,height,radius*2)})

func pipe(a: Vector3,b: Vector3,radius: float,mat: Material):
 var length=a.distance_to(b)
 if length<.001:return
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=length;shape.radial_segments=10
 var node=kit.mesh(scene_root,shape,(a+b)*.5,mat);node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func build_floodgate():
 for i in range(4):
  var p=stage_center(i)
  for side in [-1,1]:
   var basin=block(p+Vector3(side*37,-.05,0),Vector3(24,.12,40),water_material,false);basin.set_meta("keep_mesh",true);basin.set_meta("rest_y",basin.position.y);water_planes.append(basin)
   block(p+Vector3(side*25,.35,0),Vector3(1,.7,43),palette.rock)
   for j in range(5):
    block(p+Vector3(side*25,1.1,-19+j*9),Vector3(.12,1.5,.12),copper,false)
   block(p+Vector3(side*25,1.85,0),Vector3(.12,.12,43),copper,false)
  var pump=p+Vector3(i%2*24-12,0,-10)
  solid_cylinder(pump+Vector3(0,2.1,0),2.3,4.2,teal)
  for y in [.3,1.6,3.2,4.15]:ring(pump+Vector3(0,y,0),2.4,.12,copper)
  pipe(pump+Vector3(0,4.5,0),pump+Vector3(10,4.5,0),.65,teal)
  pipe(pump+Vector3(10,4.5,0),pump+Vector3(10,.2,0),.65,teal)
  var valve=ring(objective_position(i)+Vector3(0,1.35,-1),.7,.1,copper);valve.rotation.x=PI*.5;valve.set_meta("keep_mesh",true);devices.append(valve)
  var valve_at=objective_position(i)+Vector3(0,1.35,-1)
  pipe(valve_at,valve_at+Vector3(0,0,-1.6),.22,teal)
  pipe(valve_at+Vector3(0,0,-1.6),Vector3(pump.x,valve_at.y,pump.z),.3,teal)
  for side in [-1,1]:scenery.cargo(p+Vector3(side*41,0,19),palette.tower_slate,i)
  sign_at(p+Vector3(0,3,-23),["INTAKE / BACK PRESSURE","BYPASS / LOWER BASIN","FREIGHT CAUSEWAY","DOWNSTREAM ACCESS"][i],Color("93c7ce"),22)
 for i in range(9):block(Vector3(-40+i*10,terrace_height(3)+2.3,-195),Vector3(5,4.6,3),teal)

func build_sanctuary():
 for i in range(4):
  var p=stage_center(i)
  for side in [-1,1]:
   for j in range(4):
    var pillar=p+Vector3(side*43,0,-20+j*12)
    solid_cylinder(pillar+Vector3(0,4,0),1.4,8,palette.rock)
    ring(pillar+Vector3(0,1,0),1.5,.12,kit.gold);ring(pillar+Vector3(0,7,0),1.5,.14,kit.gold)
   block(p+Vector3(side*43,8.3,0),Vector3(4,1,45),palette.rock)
  for j in range(7):
   var path=p+Vector3(-18+j*6,.06,-4)
   block(path,Vector3(3.4,.07,.1),kit.gold,false)
  var plinth=p+Vector3(17,.8,-14);block(plinth,Vector3(8,1.6,5),palette.rock)
  var disc=ring(plinth+Vector3(0,2,0),3,.18,copper);disc.rotation.x=PI*.5;disc.set_meta("keep_mesh",true);devices.append(disc)
  block(plinth+Vector3(0,1.5,-.6),Vector3(1.2,3.8,1),palette.rock,false)
  pipe(plinth+Vector3(0,2,-.7),plinth+Vector3(0,2,.35),.35,copper)
  for j in range(3):
   block(p+Vector3(-20+j*5,4,-17),Vector3(2.7,5,.5),palette.rock)
   for line in range(4):block(p+Vector3(-20+j*5,2.4+line*.8,-16.7),Vector3(1.7,.08,.05),kit.gold,false)
  tree(p+Vector3(-49,0,15),12+i*2);tree(p+Vector3(49,0,-12),16)
 sign_at(Vector3(0,5,-194),"THE RESERVE BELONGS TO THE LIVING",Color("c8ba82"),27)

func build_foundry():
 for i in range(4):
  var p=stage_center(i)
  for side in [-1,1]:
   for j in range(3):
    var furnace=p+Vector3(side*(26+j*9),0,-10)
    solid_cylinder(furnace+Vector3(0,3,0),3.1,6,palette.tower_slate)
    tube(furnace+Vector3(0,9,0),1.1,9,copper)
    ring(furnace+Vector3(0,5.3,0),3.2,.18,warning)
    for vent in range(4):block(furnace+Vector3(-1.2+vent*.8,3,3.1),Vector3(.35,2,.08),kit.dark,false)
  for side in [-1,1]:
   var belt=p+Vector3(side*13,.9,2)
   block(belt,Vector3(6,1.8,16),palette.panel)
   for j in range(9):
    var roller=tube(belt+Vector3(0,.94,-7+j*1.7),.21,5.6,copper);roller.rotation.z=PI*.5
   for j in range(5):block(belt+Vector3(-1.6+j%2*2.7,1.2,-5+j*2.5),Vector3(1.2,.35,.7),kit.gold,false)
  var flywheel=ring(objective_position(i)+Vector3(0,2,-2),1.4,.2,copper);flywheel.rotation.x=PI*.5;flywheel.set_meta("keep_mesh",true);devices.append(flywheel)
  block(objective_position(i)+Vector3(0,.6,-2.6),Vector3(3.4,1.2,2),palette.panel)
  block(objective_position(i)+Vector3(0,2,-2.8),Vector3(2.8,2.6,1),palette.tower_slate)
  pipe(objective_position(i)+Vector3(0,2,-3),objective_position(i)+Vector3(0,2,-1.8),.3,copper)
  block(p+Vector3(0,11,0),Vector3(103,1.1,2),palette.tower_slate)
  for side in [-1,1]:block(p+Vector3(side*50,5.5,0),Vector3(1.1,11,2),palette.tower_slate)
  sign_at(p+Vector3(0,8.5,0),["RECYCLE / COOLANT BEFORE CURRENT","SORTING / CONDUCTOR SALVAGE","REFINING / RETIRED STOCK ONLY","FREIGHT / CONNECTUCT ALLOCATION"][i],Color("f4bc70"),23)

func build_rail():
 for z in range(-195,42,4):
  var height=surface_height(Vector3(0,0,z))
  block(Vector3(0,height+.035,z),Vector3(15,.07,.45),palette.tower_slate,false)
  for x in [-6,6]:pipe(Vector3(x,height+.12,z),Vector3(x,surface_height(Vector3(x,0,z-4))+.12,z-4),.1,copper)
 for i in range(4):
  var p=stage_center(i)
  for side in [-1,1]:
   scenery.cargo(p+Vector3(side*35,0,-16),teal,i)
   for j in range(3):scenery.cargo(p+Vector3(side*(29+j*8),0,16),palette.tower_slate,j)
   block(p+Vector3(side*19,5,0),Vector3(.8,10,.8),palette.tower_slate)
   block(p+Vector3(side*13,10,0),Vector3(13,.4,.5),palette.tower_slate,false)
   var lamp=block(p+Vector3(side*7,9.75,0),Vector3(1.4,.2,.7),warning,false);lamp.set_meta("keep_mesh",true);devices.append(lamp)
  var wagon=p+Vector3(35,0,-2)
  block(wagon+Vector3(0,1,0),Vector3(9,2,13),palette.tower_slate)
  block(wagon+Vector3(0,3.2,0),Vector3(8.5,2.4,12),teal)
  for z in [-4,4]:
   for x in [-4.8,4.8]:
    var wheel=tube(wagon+Vector3(x,.7,z),.8,.4,kit.dark);wheel.rotation.z=PI*.5
  for j in range(6):block(wagon+Vector3(-4.3,3.2,-5+j*2),Vector3(.1,2.4,.12),copper,false)
  sign_at(p+Vector3(-37,5,0),["YARD 01 / SIGNAL DEAD","YARD 02 / SWITCH HEATING","YARD 03 / FREIGHT RESERVED","YARD 04 / ORBITAL FEED"][i],Color("aac9e0"),22)
  accent_light(p+Vector3(0,8,0),Color("95aec6"),1.4,28)

func build_sky_mirror():
 for i in range(4):
  var p=stage_center(i)
  var dish_position=p+Vector3(i%2*40-20,0,-10)
  scenery.dish(dish_position)
  var dish_basis=Basis.from_euler(Vector3(deg_to_rad(-25),0,deg_to_rad(12)))
  var ring_node=ring(dish_position+Vector3(0,6.2,0)+dish_basis*Vector3(0,.91,0),3.6,.12,kit.gold)
  ring_node.basis=dish_basis;ring_node.set_meta("keep_mesh",true);devices.append(ring_node)
  for side in [-1,1]:
   for j in range(3):
    var panel=p+Vector3(side*(29+j*8),.8,15)
    block(panel,Vector3(5.5,.3,7),palette.tower_slate)
    for stripe in range(4):block(panel+Vector3(-2+stripe*1.3,.17,0),Vector3(.04,.04,6.7),copper,false)
    for z in [-2.5,2.5]:block(panel+Vector3(0,-.4,z),Vector3(.3,.8,.3),palette.panel)
  var tower=p+Vector3(45,0,-11)
  for side in [-1,1]:block(tower+Vector3(side*2.5,10,0),Vector3(.4,20,.4),copper)
  for y in range(2,21,3):pipe(tower+Vector3(-2.5,y,0),tower+Vector3(2.5,y+2.6,0),.12,copper)
  tube(tower+Vector3(0,22,0),.15,5,copper)
  sign_at(p+Vector3(0,4,-22),["AZIMUTH / THE OLD APPROACH","ELEVATION / CORRECT THE RECORD","POWER / RECOVER THE CORRIDOR","RELAY / OPEN THE SKY"][i],Color("edcfad"),22)

func build_reserve():
 for i in range(4):
  var p=stage_center(i)
  block(p+Vector3(0,12,0),Vector3(112,2,43),palette.rock)
  for side in [-1,1]:
   for j in range(3):
    var vault=p+Vector3(side*44,0,-17+j*16)
    block(vault+Vector3(0,3,0),Vector3(10,6,9),palette.rock)
    for y in range(1,6):
     block(vault+Vector3(-side*5.1,y,0),Vector3(.15,.2,7.5),kit.gold,false)
    ring(vault+Vector3(-side*5.3,3,0),1.5,.1,copper).rotation.z=PI*.5
  var seal=ring(objective_position(i)+Vector3(0,2,-2),2,.25,copper);seal.rotation.x=PI*.5;seal.set_meta("keep_mesh",true);devices.append(seal)
  block(objective_position(i)+Vector3(0,2.1,-2.85),Vector3(4.7,4.2,.85),palette.tower_slate)
  for side in [-1,1]:block(objective_position(i)+Vector3(side*2.5,2.2,-2.7),Vector3(.35,4.4,1.1),palette.rock)
  pipe(objective_position(i)+Vector3(0,2,-3),objective_position(i)+Vector3(0,2,-1.6),.4,copper)
  for angle in [0,PI*.5,PI,PI*1.5]:
   var handle=objective_position(i)+Vector3(cos(angle)*1.5,2+sin(angle)*1.5,-2)
   pipe(objective_position(i)+Vector3(0,2,-2),handle,.09,copper)
  for j in range(3):
   var case=p+Vector3(-16+j*16,0,-17)
   scenery.cargo(case,palette.hull,j)
   for bar in range(3):block(case+Vector3(-.6+bar*.6,1.65,0),Vector3(.4,.18,.85),kit.gold,false)
  accent_light(p+Vector3(0,9,0),Color("dfc57e"),2,32)
  sign_at(p+Vector3(0,7,18),["SEALED / OBSOLETE TRANSFER GALLERY","STOCK REGISTER / RETIRED CONDUCTORS","RESERVE / NEVER THE LIFE-SUPPORT GRID","TRANSFER / KEEP THE CARGO SAFE"][i],Color("e3d6ae"),22)

func build_ancient_nest():
 var center=Vector3(0,0,-55)
 for radius in [18,24,42]:ring(center+Vector3(0,.04,0),radius,.12,kit.gold)
 for i in range(12):
  if i==3:continue # Keep the entrance's view of the reclamation engine clear.
  var angle=i*TAU/12;var p=center+Vector3(cos(angle)*46,0,sin(angle)*46)
  solid_cylinder(p+Vector3(0,8,0),1.6,16,palette.rock)
  ring(p+Vector3(0,11,0),1.8,.2,copper)
  pipe(p+Vector3(0,15,0),center+Vector3(0,20,0),.3,copper)
 block(center+Vector3(0,2.5,0),Vector3(12,5,12),palette.rock)
 boss_root=Node3D.new();boss_root.name="AncientAIReclamationEngine";scene_root.add_child(boss_root);boss_root.position=center
 var old_parent=scene_root;scene_root=boss_root
 for y in [6,10,14]:
  var halo=ring(Vector3(0,y,0),7-y*.15,.4,copper);halo.set_meta("keep_mesh",true);boss_arms.append(halo)
 var core=kit.sphere(scene_root,Vector3(0,10,0),4.8,active_material);core.scale=Vector3(.8,1.4,.8)
 for i in range(3):
  var arm=Node3D.new();scene_root.add_child(arm);arm.position=Vector3(0,7+i*1.1,0);arm.rotation.y=i*TAU/3
  kit.box(arm,Vector3(9,0,0),Vector3(17,.65,1.1),copper)
  kit.box(arm,Vector3(17,-1.6,0),Vector3(2,3.3,2),palette.tower_slate)
  boss_arms.append(arm)
 scene_root=old_parent
 for i in range(3):
  var weak=boss_weakpoint(i)
  var shell=kit.sphere(scene_root,weak,1.1,warning);shell.set_meta("keep_mesh",true);boss_cores.append(shell)
  pipe(weak,center+Vector3(0,9,0),.28,copper)
  var strip=build_boss_warning(i);strip.set_meta("keep_mesh",true);strip.hide();boss_warnings.append(strip)
 for side in [-1,1]:
  for z in [-18,-50,-82]:
   var height=surface_height(Vector3(side*18,0,z))
   block(Vector3(side*18,height+1.6,z),Vector3(5,3.2,2),palette.rock)
   cover_points.append(Vector3(side*18,height,z+2))
 sign_at(Vector3(0,19,-55),"ANCIENT AI / CUSTODIAL RECLAMATION",Color("e4c482"),35)
 sign_at(Vector3(0,5,-132),"CONDUCTOR RESERVE / CONNECTUCT RETURN",Color("a1d9c5"),27)
 for i in range(5):scenery.cargo(Vector3(-12+i*6,6,-152),palette.hull,i)
 # Reuse the expedition hull asset for the Relay's extraction ship, without a new pilot/cast.
 ship_position=Vector3(0,6,-179);ship(ship_position,false)

func enrich_environment():
 # Large shapes establish function; smaller seams/fasteners reward closer inspection.
 # These additions stay on floors, existing wall faces or above head clearance.
 var seam=kit.material(Color("202d32"));var edge=kit.material(Color("a6aaa2"),.3)
 for stage in range(4):
  var p=stage_center(stage)
  if mission_index==9 and stage>0:continue
  for x in range(-46,47,8):
   block(p+Vector3(x,.012,0),Vector3(.06,.018,49),seam,false)
  for z in range(-24,25,8):block(p+Vector3(0,.014,z),Vector3(99,.018,.06),seam,false)
  for side in [-1,1]:
   for j in range(5):
    var wall=p+Vector3(side*51.8,0,-20+j*10)
    block(wall+Vector3(0,4,0),Vector3(.22,7.5,.13),copper,false)
    block(wall+Vector3(0,1.1,0),Vector3(.25,.16,6),edge,false)
    block(wall+Vector3(0,7.3,0),Vector3(.25,.22,6),edge,false)
   for z in [-22,22]:
    for n in range(6):
     var stripe=block(p+Vector3(side*(28+n*3.3),.035,z),Vector3(1.7,.025,.42),warning,false);stripe.rotation.y=.45
  match mission_index:
   3:
    for side in [-1,1]:
     var intake=p+Vector3(side*38,0,-3)
     for j in range(3):
      var at=intake+Vector3(-6+j*6,3,0)
      tube(at,1.1,5.8,teal);ring(at+Vector3(0,2.8,0),1.2,.14,copper)
      pipe(at+Vector3(0,3,0),at+Vector3(0,6,8),.6,teal)
     for z in [-12,12]:
      block(intake+Vector3(0,6,z),Vector3(23,.7,.8),palette.panel,false)
      for x in [-10,10]:block(intake+Vector3(x,3,z),Vector3(.6,6,.6),palette.panel,false)
     for x in range(-10,11,2):block(intake+Vector3(x,1.5,14),Vector3(.13,3,.2),edge,false)
   4:
    for side in [-1,1]:
     for j in range(3):
      var tablet=p+Vector3(side*50.7,4,-17+j*17)
      block(tablet,Vector3(.5,6,11),palette.rock,false)
      for line in range(6):
       for mark in range(4):block(tablet+Vector3(-side*.28,-2+line*.75,-3.8+mark*2.1),Vector3(.08,.09,.7+float(posmod(line+mark,3))*.25),copper,false)
    for z in [-19,19]:
     for side in [-1,1]:
      pipe(p+Vector3(side*43,8,z),p+Vector3(side*22,16,z),1,palette.rock)
      pipe(p+Vector3(side*22,16,z),p+Vector3(0,19,z),.8,palette.rock)
    ring(p+Vector3(0,.05,0),12,.08,kit.gold)
    for n in range(8):
     var angle=n*TAU/8;block(p+Vector3(cos(angle)*12,.04,sin(angle)*12),Vector3(.5,.035,1.7),copper,false)
   5:
    for z in [-18,18]:
     block(p+Vector3(0,10,z),Vector3(101,1.3,1.2),palette.tower_slate,false)
     for x in range(-48,49,8):
      pipe(p+Vector3(x,9.5,z-.8),p+Vector3(x+6,11,z+.8),.12,copper)
    for side in [-1,1]:
     pipe(p+Vector3(side*19,8,-25),p+Vector3(side*19,8,25),.8,palette.panel)
     for z in [-16,0,16]:
      ring(p+Vector3(side*19,8,z),.92,.13,copper).rotation.x=PI*.5
      pipe(p+Vector3(side*4,9,z),p+Vector3(side*4,5,z),.055,copper)
      ring(p+Vector3(side*4,4.7,z),.35,.08,copper).rotation.x=PI*.5
     for j in range(5):
      var rack=p+Vector3(side*50,2.5,-18+j*9)
      block(rack,Vector3(2.5,5,6),palette.tower_slate,false)
      for vent in range(7):block(rack+Vector3(-side*1.3,-1.8+vent*.5,0),Vector3(.1,.15,4.8),kit.dark,false)
   6:
    for side in [-1,1]:
     pipe(p+Vector3(side*19,10,-27),p+Vector3(side*19,10,27),.05,copper)
     block(p+Vector3(side*43,6,0),Vector3(19,.6,47),palette.tower_slate,false)
     for z in [-20,20]:
      pipe(p+Vector3(side*51,2,z),p+Vector3(side*35,6,z),.22,copper)
     for j in range(5):
      block(p+Vector3(side*43,6.4,-18+j*9),Vector3(17,.2,2.4),palette.panel,false)
    for z in [-21,21]:
     var arrow=block(p+Vector3(0,.035,z),Vector3(1.2,.025,3),edge,false)
     for side in [-1,1]:
      var tip=block(p+Vector3(side*.7,.036,z-1),Vector3(.3,.03,1.8),edge,false);tip.rotation.y=side*-.7
   7:
    for side in [-1,1]:
     var dish=stage_center(stage)+Vector3(side*40,7,-15)
     solid_cylinder(dish-Vector3(0,3.5,0),.5,7,palette.tower_slate)
     for leg in [-1,1]:pipe(dish+Vector3(leg*5,-7,3),dish-Vector3(0,2,0),.22,copper)
     var frame=ring(dish,7,.16,edge);frame.rotation.x=.65
     for n in range(8):
      var angle=n*TAU/8
      pipe(dish, dish+Vector3(cos(angle)*6.5,sin(angle)*4,sin(angle)*5),.06,copper)
    for z in [-18,18]:
     pipe(p+Vector3(-50,.15,z),p+Vector3(50,.15,z),.09,kit.dark)
     for x in [-49,49]:block(p+Vector3(x,3,z),Vector3(3,6,2),palette.tower_slate,false)
   8:
    for side in [-1,1]:
     for x in [18,27,36]:
      pipe(p+Vector3(side*x,10.5,-26),p+Vector3(side*x,10.5,26),.25,copper)
      for z in [-18,0,18]:ring(p+Vector3(side*x,10.5,z),.34,.1,kit.gold).rotation.x=PI*.5
     for z in [-21,21]:
      pipe(p+Vector3(side*50,6,z),p+Vector3(side*30,11,z),.7,palette.rock)
      pipe(p+Vector3(side*30,11,z),p+Vector3(0,11,z),.6,palette.rock)
    for z in [-15,15]:
     tube(p+Vector3(0,8,z),.75,.5,kit.gold)
     pipe(p+Vector3(0,8,z),p+Vector3(0,11,z),.08,copper)
   9:
    var center=Vector3(0,0,-55)
    for i in range(16):
     var angle=i*TAU/16
     var point=center+Vector3(cos(angle)*37,11,sin(angle)*37)
     var deck=block(point,Vector3(14,.6,3.5),palette.tower_slate,false);deck.rotation.y=-angle+PI*.5
     var rail=block(point+Vector3(0,1.2,0),Vector3(14,.14,.14),copper,false);rail.rotation.y=deck.rotation.y
     var pier=posmod(roundi(angle*12/TAU),12)
     if pier==3:pier=2 if i<=4 else 4
     var pier_angle=pier*TAU/12
     pipe(point,center+Vector3(cos(pier_angle)*46,15,sin(pier_angle)*46),.25,copper)
    for side in [-1,1]:
     for j in range(4):
      var bank=center+Vector3(side*49,3.4,-18+j*12)
      block(bank,Vector3(4,6.8,8),palette.tower_slate,false)
      for n in range(4):tube(bank+Vector3(-side*2.3,-2+n*1.3,0),.5,1,kit.gold).rotation.z=PI*.5
    var old_parent=scene_root;scene_root=boss_root
    for n in range(8):
     var angle=n*TAU/8;var point=Vector3(cos(angle)*5.8,10,sin(angle)*5.8)
     tube(point,.36,12,copper);ring(point+Vector3(0,4.7,0),.5,.1,kit.gold)
    for y in [5,15]:ring(Vector3(0,y,0),7,.6,palette.tower_slate)
    tube(Vector3(0,17.5,0),.45,5,copper)
    kit.sphere(scene_root,Vector3(0,20,0),.7,kit.gold)
    scene_root=old_parent
 if mission_index==3:
  block(Vector3(0,14,-208),Vector3(128,28,9),palette.rock,false)
  for x in range(-50,51,20):
   block(Vector3(x,11,-202.8),Vector3(12,20,.6),teal,false)
   for y in range(3,22,3):block(Vector3(x,y,-202.3),Vector3(12,.35,.8),copper,false)
   block(Vector3(x,5,-201.8),Vector3(7,8,.2),water_material,false)

func boss_weakpoint(stage: int) -> Vector3:
 var p=[Vector3(-16,0,-40),Vector3(16,0,-64),Vector3(-10,0,-90)][clampi(stage,0,2)]
 p.y=surface_height(p)+3.3;return p

func build_vertical_details():
 var steel=kit.material(Color("303e46"),.55);var cream=kit.material(Color("a8ae9d"),.2)
 for stage in range(4):
  if mission_index==9:break
  var p=stage_center(stage);var deck: Vector3=raised_cache_sites[stage]
  for side in [-1,1]:
   for z in [-16,16]:
    var foot=p+Vector3(side*47,-3.7,z)
    block(foot,Vector3(3,7.4,4),palette.rock,false)
    pipe(foot+Vector3(0,3.5,0),foot+Vector3(-side*14,1,0),.38,copper)
   for j in range(4):
    var fitting=p+Vector3(side*51.6,2.6,-15+j*10)
    var boss=tube(fitting,.75,.2,copper);boss.rotation.z=PI*.5
    for n in range(5):block(fitting+Vector3(-side*.14,-1.9+n*.75,0),Vector3(.12,.14,3.6),steel,false)
  # Real raised side decks hold exploration rewards. Keep their ramp mouths open.
  for z in [-4.8,4.8]:
   block(deck+Vector3(0,1.05,z),Vector3(13.8,.12,.12),copper,false)
   for x in [-6,-2,2,6]:block(deck+Vector3(x,.53,z),Vector3(.1,1.06,.1),steel,true)
  var away=1 if deck.x>0 else -1
  block(deck+Vector3(away*6.8,1.05,0),Vector3(.12,.12,9.6),copper,false)
  for z in [-3,0,3]:block(deck+Vector3(away*6.8,.53,z),Vector3(.12,1.06,.12),steel,true)
  for side in [-1,1]:
   var support=deck+Vector3(side*5.3,-1.6,0)
   block(support,Vector3(.65,3.2,8),steel,false)
   for z in [-3,3]:pipe(deck+Vector3(side*6,-3,z),deck+Vector3(-side*4,-.3,z),.13,copper)
  sign_at(deck+Vector3(0,2.7,4.6),["INTAKE SERVICE DECK","ARCHIVE OVERLOOK","GANTRY MAINTENANCE","SIGNAL GALLERY","MIRROR SERVICE DECK","RESERVE INSPECTION"][clampi(mission_index-3,0,5)],Color("d8d5a8"),18)
  var lamp=block(deck+Vector3(away*5,2.4,-3.7),Vector3(.45,.18,.5),active_material,false)
  block(deck+Vector3(away*5,1.2,-3.7),Vector3(.12,2.4,.12),steel,false)
  for x in [-4,4]:
   block(deck+Vector3(x,.06,0),Vector3(.08,.05,8),warning,false)
   for z in [-3.5,3.5]:ring(deck+Vector3(x,.08,z),.2,.05,copper)
  # Smaller authored clusters break up the combat floor without occupying its centre.
  for side in [-1,1]:
   var case=p+Vector3(side*7,0,-12)
   scenery.cargo(case,teal,stage)
   block(case+Vector3(side*1.5,.45,.4),Vector3(.7,.9,.8),palette.tower_slate)
   var coil=ring(case+Vector3(0,1.75,0),.45,.08,copper);coil.rotation.x=.2
   for k in range(3):block(case+Vector3(-.45+k*.45,1.61,.4),Vector3(.17,.08,.35),cream,false)
  if stage<3:
   var a=p+Vector3(0,0,-20);var b=stage_center(stage+1)+Vector3(0,0,20)
   var midpoint=a.lerp(b,.5)
   sign_at(a+Vector3(0,3,2),"SERVICE BRIDGE / "+("DESCEND " if b.y<a.y else "CLIMB ")+str(int(absf(b.y-a.y)))+" m",Color("f0d293"),20)
   for side in [-1,1]:
    for section in range(4):
     var at=a.lerp(b,section/3.0)+Vector3(side*7.6,-1,0)
     block(at,Vector3(.5,2.1,.7),steel,false)
    pipe(a+Vector3(side*7.8,-1,0),b+Vector3(side*7.8,-1,0),.32,copper)
   if mission_index==3:
    block(midpoint+Vector3(0,-7,0),Vector3(102,.08,14),water_material,false)
    for side in [-1,1]:
     pipe(midpoint+Vector3(side*23,-4,-6),midpoint+Vector3(side*23,-4,6),1.3,teal)
   elif mission_index==5:
    for side in [-1,1]:
     tube(midpoint+Vector3(side*30,-1,0),4.8,15,palette.tower_slate)
     for y in [-6,-2,2,6]:ring(midpoint+Vector3(side*30,y,0),4.9,.22,copper)
   elif mission_index==8:
    var roof=block(midpoint+Vector3.UP*12,Vector3(112,1.7,a.distance_to(b)+3),palette.rock,false)
    roof.rotation.x=atan2(b.y-a.y,absf(b.z-a.z))
    for side in [-1,1]:
     block(midpoint+Vector3(side*53,7,0),Vector3(5,16,20),palette.rock)
     pipe(a+Vector3(side*14,5,0),b+Vector3(side*14,5,0),1.0,copper)
     for n in range(5):
      var collar=ring(a.lerp(b,n/4.0)+Vector3(side*14,5,0),1.14,.15,kit.gold);collar.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
     for x in [18,27,36]:
      var pipe_start=p+Vector3(side*x,10.5,-26);var pipe_finish=stage_center(stage+1)+Vector3(side*x,10.5,26)
      pipe(pipe_start,pipe_finish,.25,copper)
     for endpoint in [a,b]:
      pipe(endpoint+Vector3(side*14,5,0),endpoint+Vector3(side*14,10,0),1,copper)
      block(endpoint+Vector3(side*14,10.9,0),Vector3(3.1,1.8,3.1),palette.tower_slate,false)
 # The finale's tall maintenance decks create real vertical approaches and solid cover.
 if mission_index==9:
  for side in [-1,1]:
   for z in [-10,5,27]:
    var bank=Vector3(side*43,0,z)
    block(bank+Vector3(0,2,0),Vector3(5,4,7),palette.tower_slate)
    for j in range(4):
     var conductor=bank+Vector3(-side*2.55,1+j*.65,0)
     block(conductor,Vector3(.18,.24,5.8),copper,false)
     for z_offset in [-2,2]:ring(conductor+Vector3(-side*.13,0,z_offset),.35,.07,kit.gold).rotation.z=PI*.5
   block(Vector3(side*43,7,0),Vector3(1.1,14,1.5),palette.rock)
   pipe(Vector3(side*43,13,0),Vector3(0,19,0),.65,copper)
   pipe(Vector3(side*48,4,30),Vector3(side*48,4,-18),.7,copper)
  for z in range(-20,37,7):
   for side in [-1,1]:
    var marker=block(Vector3(side*4,.035,z),Vector3(.45,.025,2.2),kit.gold,false);marker.rotation.y=side*.3
  for stage in range(3):
   var at=objective_position(stage)
   for side in [-1,1]:
    var shield=at+Vector3(side*4,1.6,3)
    block(shield,Vector3(2.8,3.2,1.1),palette.rock)
    for band in range(3):block(shield+Vector3(0,-1+band,.58),Vector3(2.6,.1,.07),copper,false)
   sign_at(at+Vector3(0,3,-3),"MAINTENANCE LEVEL "+str(int(at.y))+" m",Color("d9c189"),18)
  for side in [-1,1]:
   for z in range(-130,-99,5):
    var at=Vector3(side*10,0,z);at.y=surface_height(at)
    block(at+Vector3.UP*.55,Vector3(.18,1.1,.18),steel,true)
   pipe(Vector3(side*10,1.1,-101),Vector3(side*10,7.1,-130),.1,copper)
  sign_at(Vector3(0,10,-145),"RETURN SHIP / RECOVERED CARGO",Color("bde3cf"),26)

func build_boss_warning(lane: int) -> MeshInstance3D:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-6,6,2):
  for z in range(-32,32,2):
   var points=[]
   for offset in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z+2)]:
    var point=Vector3(-24+lane*24+offset.x,0,-55+offset.y);point.y=surface_height(point)+.055;points.append(point)
   for index in [0,2,1,1,2,3]:tool.set_normal(Vector3.UP);tool.add_vertex(points[index])
 return kit.mesh(scene_root,tool.commit(),Vector3.ZERO,warning)

func narrative_lamp(position: Vector3,size: Vector3,stage: int) -> MeshInstance3D:
 var lamp=block(position,size,warning,false)
 lamp.set_meta("keep_mesh",true);narrative_indicators.append({"node":lamp,"stage":stage})
 return lamp

func detail_surface(color: Color,accent: Color,metal: float=0.0) -> ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=load("res://assets/campaign_surface.gdshader")
 material.set_shader_parameter("noise_texture",load("res://assets/stone_noise.png"))
 material.set_shader_parameter("base_color",color);material.set_shader_parameter("accent_color",accent)
 material.set_shader_parameter("metalness",metal);material.set_shader_parameter("surface_kind",1.0 if metal>.2 else 0.0)
 material.set_shader_parameter("low_detail",quality==0);return material

func rotated_detail_wall(at: Vector3,size: Vector3,yaw: float,material: Material) -> MeshInstance3D:
 var visual=block(at,size,material,false);visual.rotation.y=yaw
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;scene_root.add_child(body);body.position=at;body.rotation.y=yaw
 var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider)
 var extent=Vector3(absf(cos(yaw))*size.x+absf(sin(yaw))*size.z,size.y,absf(sin(yaw))*size.x+absf(cos(yaw))*size.z)
 floor_cover.append({"position":at,"size":extent});return visual

func build_narrative_details():
 # Machinery is attached to the equipment it serves. The main walking corridor,
 # reward approaches and all physical cover are established before this pass.
 if mission_index==7:build_relay_details()
 elif mission_index==8:build_reserve_details()
 elif mission_index==9:build_custodian_details()

func build_relay_details():
 var ceramic=detail_surface(Color("9eafa8"),Color("627e7b"),.35)
 var weathered=detail_surface(Color("7c7067"),Color("534f50"))
 var steel=detail_surface(Color("333e45"),Color("1f2b34"),.65)
 for stage in range(4):
  var p=stage_center(stage);var base=p+Vector3(stage%2*40-20,0,-10)
  # A real azimuth gearbox, bolted dish cradle and connected receiver cabinet.
  tube(base+Vector3(0,4.08,0),2.7,.24,steel)
  for tooth in range(20):
   var angle=tooth*TAU/20
   var shoe=block(base+Vector3(cos(angle)*2.55,4.26,sin(angle)*2.55),Vector3(.26,.22,.45),copper,false);shoe.rotation.y=-angle
  for side in [-1,1]:
   block(base+Vector3(side*1.65,5.0,0),Vector3(.45,2,.7),ceramic,false)
   pipe(base+Vector3(side*1.65,4.4,0),base+Vector3(side*3.1,6.5,-.5),.12,copper)
   var bearing=tube(base+Vector3(side*1.9,5.55,0),.62,.5,steel);bearing.rotation.z=PI*.5
   ring(base+Vector3(side*2.17,5.55,0),.45,.07,copper).rotation.z=PI*.5
  block(base+Vector3(0,2.3,3.6),Vector3(6.3,2.5,.13),steel,false)
  for n in range(3):
   var face=base+Vector3(-2.15+n*2.15,2.35,3.7)
   block(face,Vector3(1.7,1.75,.12),ceramic,false)
   for line in range(6):block(face+Vector3(0,-.58+line*.2,.08),Vector3(1.4,.055,.045),steel,false)
   narrative_lamp(face+Vector3(.56,.65,.1),Vector3(.25,.12,.06),stage)
  # Open-air cable trays stay on the wall side of the mirror foundation.
  var side=-1 if base.x<0 else 1
  var cable_a=base+Vector3(side*4.2,1.1,0);var cable_b=Vector3(side*48,p.y+1.1,base.z)
  for strand in range(3):pipe(cable_a+Vector3(0,strand*.17,0),cable_b+Vector3(0,strand*.17,0),.055,copper)
  for x in range(24,49,4):block(Vector3(side*x,p.y+.75,base.z),Vector3(.15,.7,.6),steel,false)
  pipe(cable_b,Vector3(side*48,p.y+7,base.z),.18,steel)
  # The contradictory flight orders are visible on the relay's physical recorder.
  var board=p+Vector3(-46,4.8,2)
  block(board,Vector3(.6,5.4,17),weathered,false)
  for row in range(3):
   var stamp=block(board+Vector3(.33,-1.8+row*1.8,0),Vector3(.06,.9,14),steel,false)
   narrative_lamp(board+Vector3(.42,-1.8+row*1.8,5.8),Vector3(.09,.25,.4),stage)
  var label=sign_at(board+Vector3(.45,.1,0),["APPROACH RECORD\nQUARANTINE: HOLD\nFLIGHT HANDOFF: CONFLICT","CALIBRATION / 02\nRECORDER: VERIFIED\nCORRIDOR: BLOCKED","POWER / 03\nOLD ORDER: ISOLATED\nRETURN ROUTE: AVAILABLE","RELAY / 04\nCONNECTUCT: ACQUIRED\nTRANSFER: STANDBY"][stage],Color("cad6c9"),19);label.rotation.y=PI*.5
  # Wind louvers and feeder cabinets tie the solar field into the existing mast.
  for x in [30,38,46]:
   var inverter=p+Vector3(x,1.8,19.5)
   block(inverter,Vector3(4,3.6,1.1),ceramic,false)
   for vent in range(7):block(inverter+Vector3(0,-1.2+vent*.35,.57),Vector3(3.2,.12,.08),steel,false)
   pipe(inverter+Vector3(0,-1.4,-.55),inverter+Vector3(0,-1.4,-4.5),.1,steel)
   narrative_lamp(inverter+Vector3(1.4,1.35,.6),Vector3(.3,.2,.1),stage)
  # A shuttered signal beacon opens only after this station's restored handoff.
  var beacon=p+Vector3(45,22,-11)
  narrative_lamp(beacon,Vector3(.6,.65,.6),stage)
  for side_shutter in [-1,1]:
   var shutter=block(beacon+Vector3(side_shutter*.48,0,0),Vector3(.3,1.2,1.2),steel,false)
   shutter.set_meta("keep_mesh",true);narrative_panels.append({"node":shutter,"stage":stage,"closed":shutter.position,"offset":Vector3(side_shutter*.9,0,0)})
  var rotor=Node3D.new();scene_root.add_child(rotor);rotor.position=base+Vector3(0,4.6,0)
  kit.box(rotor,Vector3(2.8,0,0),Vector3(1.4,.12,.18),kit.gold)
  narrative_rotors.append({"node":rotor,"stage":stage,"speed":.12})
  for z in [-21,21]:
   var curb=p+Vector3(49,.22,z)
   block(curb,Vector3(5,.42,.65),weathered,false)
   for bolt in [-1.6,1.6]:tube(curb+Vector3(bolt,.24,0),.1,.08,steel)

func build_reserve_details():
 var vault_stone=detail_surface(Color("687482"),Color("424c5a"))
 var steel=detail_surface(Color("303946"),Color("1d2530"),.6)
 var insulated=detail_surface(Color("a39268"),Color("605739"),.35)
 for stage in range(4):
  var p=stage_center(stage)
  # Each descending gallery has an unbroken overhead conductor trunk. A parallel
  # labelled life-support bus remains powered while only the retired bank opens.
  for side in [-1,1]:
   for z in [-16,0,16]:
    var vault=p+Vector3(side*44,0,z-1)
    block(vault+Vector3(-side*5.15,3,0),Vector3(.35,5.6,8.8),steel,false)
    for rib in [-3.7,0,3.7]:block(vault+Vector3(-side*5.4,3,rib),Vector3(.25,5.5,.18),insulated,false)
    for y in [1,5]:
     for zz in [-3,3]:
      var stud=tube(vault+Vector3(-side*5.61,y,zz),.16,.14,copper);stud.rotation.z=PI*.5
    # Small pressure/electrical gauges are fastened to the vault face.
    for gauge in [-1.6,1.6]:
     var gauge_at=vault+Vector3(-side*5.65,3,gauge)
     var housing=tube(gauge_at,.46,.2,insulated);housing.rotation.z=PI*.5
     ring(gauge_at+Vector3(-side*.12,0,0),.34,.045,kit.gold).rotation.z=PI*.5
     pipe(gauge_at+Vector3(-side*.16,-.2,-.1),gauge_at+Vector3(-side*.16,.18,.13),.025,kit.dark)
    narrative_lamp(vault+Vector3(-side*5.65,5.1,0),Vector3(.1,.25,2.2),stage)
   pipe(p+Vector3(side*48,7.6,-21),p+Vector3(side*48,7.6,21),.34,insulated)
   for z in [-17,-1,15]:
    pipe(p+Vector3(side*48,7.6,z),p+Vector3(side*44,7.6,z),.34,insulated)
    pipe(p+Vector3(side*44,7.6,z),p+Vector3(side*44,6,z),.34,insulated)
   # Permanently green live bus is segregated high on the wall, above the cargo.
   block(p+Vector3(side*51.4,8.5,0),Vector3(.24,.15,38),active_material,false)
   var notice=sign_at(p+Vector3(side*51.15,9.3,0),"ACTIVE LIFE SUPPORT / KEEP CONNECTED",Color("9ce3b5"),17);notice.rotation.y=-side*PI*.5
  # Ceiling ribs and hangers make the depth and changing roof level legible.
  for z in [-17,-1,15]:
   block(p+Vector3(0,10.85,z),Vector3(101,.35,.55),steel,false)
   for x in [-36,-18,18,36]:
    pipe(p+Vector3(x,10.5,z),p+Vector3(x,11.2,z),.11,steel)
    block(p+Vector3(x,11.3,z),Vector3(.65,.16,.65),insulated,false)
  # An opened obsolete rack physically exposes its gold inventory; it never
  # disconnects or drains the live green bus on the opposing wall.
  var op=objective_position(stage);var rack=op+Vector3(0,5.6,-3.3)
  block(rack,Vector3(5.7,2.1,1.5),steel,false)
  for bar in range(6):block(rack+Vector3(-2.15+bar*.86,0,.82),Vector3(.42,1.5,.25),kit.gold,false)
  for side in [-1,1]:
   var shutter=block(rack+Vector3(side*1.43,0,1.04),Vector3(2.8,2.1,.16),vault_stone,false)
   shutter.set_meta("keep_mesh",true);narrative_panels.append({"node":shutter,"stage":stage,"closed":shutter.position,"offset":Vector3(side*2.8,0,0)})
   pipe(op+Vector3(side*3,0,-3),op+Vector3(side*3,6.7,-3),.12,copper)
  sign_at(rack+Vector3(0,1.65,1.1),"RETIRED CONDUCTORS / RELEASE "+str(stage+1),Color("e5d4a8"),17)
  # Recessed drainage and repair seams follow the lower gallery floor.
  for x in [-4.5,4.5]:
   block(p+Vector3(x,.018,0),Vector3(.65,.022,38),steel,false)
   for z in range(-18,19,2):block(p+Vector3(x,.036,z),Vector3(.65,.024,.12),insulated,false)
  var census=sign_at(p+Vector3(0,9.1,-19),"GALLERY "+str(stage+1)+"   /   DATUM "+str(int(p.y))+" m\nRETIRED STOCK ONLY",Color("d1c7a8"),19)
  for side in [-1,1]:
   pipe(p+Vector3(side*4,10.8,-19),p+Vector3(side*4,9.4,-19),.05,steel)
  # Wall surface overlays preserve all functional collision and clear approaches.
  for side in [-1,1]:block(p+Vector3(side*51.98,4,0),Vector3(.04,7.8,39),vault_stone,false)

func build_custodian_details():
 var basalt=detail_surface(Color("4d4e5b"),Color("272c3b"))
 var steel=detail_surface(Color("3d4852"),Color("1b2430"),.65)
 var ceramic=detail_surface(Color("b5afa1"),Color("6f7b80"),.3)
 var center=Vector3(0,0,-55)
 # A segmented enclosure grounds the huge AI engine and frames the entrance.
 for i in range(12):
  var angle=i*TAU/12
  if i in [2,3,4,8,9,10]:continue # Full-width entry and extraction approaches remain open.
  var at=center+Vector3(cos(angle)*58,8,sin(angle)*58)
  var panel=rotated_detail_wall(at,Vector3(21,15,.8),-angle+PI*.5,basalt)
  for y in [-5,5]:
   var rib=block(at+Vector3(0,y,0),Vector3(20,.3,1.2),copper,false);rib.rotation.y=panel.rotation.y
  var lug=at+Vector3(-cos(angle)*.8,0,-sin(angle)*.8)
  pipe(lug+Vector3(0,-5.5,0),lug+Vector3(0,5.5,0),.45,steel)
  ring(lug+Vector3(0,4.7,0),.6,.1,kit.gold)
 # Feed conductors enter the core through visible insulators and locked clamps.
 for stage in range(3):
  var at=objective_position(stage);var switch=at+Vector3(0,5.1,-4)
  block(switch,Vector3(6.6,2.2,2.4),steel,false)
  for x in [-2.3,0,2.3]:
   tube(switch+Vector3(x,1.75,0),.36,1.6,ceramic)
   for y in [1.2,1.55,1.9,2.25]:ring(switch+Vector3(x,y,0),.57,.1,copper)
   narrative_lamp(switch+Vector3(x,-.05,1.27),Vector3(.5,.9,.1),stage)
  pipe(switch+Vector3(0,2.6,0),center+Vector3(0,18+stage*.7,0),.22,copper)
  pipe(at+Vector3(-3.4,0,-4),switch+Vector3(-3.4,0,0),.25,steel)
  pipe(at+Vector3(3.4,0,-4),switch+Vector3(3.4,0,0),.25,steel)
  for side in [-1,1]:
   var breaker=block(switch+Vector3(side*1.6,.2,1.4),Vector3(2.9,1.6,.2),ceramic,false)
   breaker.set_meta("keep_mesh",true);narrative_panels.append({"node":breaker,"stage":stage,"closed":breaker.position,"offset":Vector3(side*3.1,0,0)})
  sign_at(switch+Vector3(0,3.4,1.1),["ISOLATE / RECLAMATION ORDER","ISOLATE / QUARANTINE ORDER","RESTORE / CUSTODIAL CONSENSUS"][stage],Color("e2d2aa"),18)
 # The emitter's three physical apertures correspond to the three warning lanes.
 for lane in range(3):
  var at=center+Vector3(-2.8+lane*2.8,16,3.7)
  block(at,Vector3(2,1.4,2),steel,false)
  ring(at+Vector3(0,0,1.05),.56,.11,copper).rotation.x=PI*.5
  narrative_lamp(at+Vector3(0,0,1.1),Vector3(.55,.55,.12),lane)
  pipe(at+Vector3(0,.7,0),center+Vector3(0,20,0),.17,copper)
 # Approach alcoves display custody balances as visible slots, never new actors.
 for side in [-1,1]:
  var board=Vector3(side*43,5.5,16)
  block(board,Vector3(8,3,1),basalt,false)
  for cell in range(6):
   block(board+Vector3(-3+cell*1.2,0,.56),Vector3(.65,1.9,.15),kit.gold if side<0 else active_material,false)
  sign_at(board+Vector3(0,2,.6),"RETIRED RESERVE / RELEASE" if side<0 else "ANNU LIFE SUPPORT / PROTECTED",Color("a9d5c2") if side>0 else Color("e7cd8d"),17)
  for x in [-3.5,3.5]:pipe(board+Vector3(x,-5.5,0),board+Vector3(x,-1.5,0),.2,steel)
 # A sheltered loading apron and cargo straps make the final defense destination
 # read as an extraction space rather than a bare fourth combat rectangle.
 for side in [-1,1]:
  for z in [-145,-167,-190]:
   block(Vector3(side*46,11,z),Vector3(1.1,10,1.1),basalt,false)
   pipe(Vector3(side*46,15.5,z),Vector3(side*27,20,z),.65,steel)
  block(Vector3(side*39,20,-168),Vector3(25,.65,52),steel,false)
  for z in range(-191,-143,6):
   block(Vector3(side*39,20.4,z),Vector3(25,.3,.5),ceramic,false)
   block(Vector3(side*27,19.55,z),Vector3(1.4,.14,1.5),active_material,false)
  for z in [-147,-157]:
   var dock=Vector3(side*40,6,z)
   block(dock+Vector3(0,.35,0),Vector3(8,.7,7),steel,false)
   for n in range(3):
    var cargo=dock+Vector3(-2.5+n*2.5,1.6,0)
    block(cargo,Vector3(2.1,1.8,4.8),ceramic,false)
    for zz in [-1.6,1.6]:block(cargo+Vector3(0,0,zz),Vector3(2.2,1.9,.12),copper,false)
 for z in range(-136,-195,-6):
  for side in [-1,1]:block(Vector3(side*4,6.03,z),Vector3(.3,.04,2.5),active_material,false)

func update_narrative_details(stage: int):
 for entry in narrative_indicators:entry.node.material_override=active_material if int(entry.stage)<stage else warning
 for entry in narrative_panels:entry.node.position=entry.closed+(entry.offset if int(entry.stage)<stage else Vector3.ZERO)

func set_boss_state(stage: int,clock: float):
 if boss_root==null:return
 for i in range(boss_arms.size()):
  boss_arms[i].rotation.y=clock*(.17+i*.035)*(1 if i%2==0 else -1)
 for i in range(boss_warnings.size()):
  boss_warnings[i].visible=stage<3 and i==posmod(int(clock/6),3) and fmod(clock,6)>3.2
 for i in range(boss_cores.size()):boss_cores[i].visible=i>=stage

func set_stage(stage: int):
 var changed=current_stage!=stage
 current_stage=stage
 for i in range(status_lights.size()):status_lights[i].material_override=active_material if i<stage else warning
 for i in range(water_planes.size()):water_planes[i].position.y=float(water_planes[i].get_meta("rest_y",-.05))-minf(stage,4)*.2
 for i in range(devices.size()):
  var device=devices[i]
  if mission_index==6:device.material_override=active_material if i/2<stage else warning
  elif mission_index in [7,8]:device.material_override=active_material if i<stage else warning
  else:device.basis=device.get_meta("rest_basis",device.basis)*Basis(Vector3.UP,PI*.5 if i<stage else 0)
 for gate in stage_gates:
  var opened=int(gate.index)<stage
  gate.root.position=gate.at+Vector3(0,7.5 if opened else 0,0)
  gate.shape.set_deferred("disabled",opened)
  if mission_index==8 and int(gate.index)==0:gate.root.visible=not opened
 for fragment in seal_fragments:fragment.visible=stage>0
 update_narrative_details(stage)
 for detail_script in detail_modules:
  if detail_script.has_method("update_stage"):detail_script.update_stage(self,stage)
 if changed and mission_index!=2:update_gate_navigation()

func tree(p: Vector3,height: float):
 solid_cylinder(p+Vector3(0,height*.5,0),.8,height,palette.bark)
 for j in range(3):
  var crown=kit.sphere(scene_root,p+Vector3(sin(j*2.3)*2,height-2+j*1.1,cos(j*2.3)*2),3.8,palette.leaf);crown.scale=Vector3(1.4,.65,1.2)

func build_birds():
 if mission_index in [5,8,9]:return
 bird_root=Node3D.new();bird_root.name="OccasionalDistantBirds";scene_root.add_child(bird_root)
 for i in range(3):
  var bird=Node3D.new();bird_root.add_child(bird);bird.position=Vector3(i*2,.4*i,i*1.2)
  kit.box(bird,Vector3.ZERO,Vector3(.18,.12,.6),kit.dark)
  var left=kit.box(bird,Vector3(-.6,0,0),Vector3(1.1,.06,.25),kit.dark);left.rotation.z=-.2
  var right=kit.box(bird,Vector3(.6,0,0),Vector3(1.1,.06,.25),kit.dark);right.rotation.z=.2

func animate(clock: float):
 for rotor in narrative_rotors:
  rotor.node.rotation.y=clock*float(rotor.speed) if int(rotor.stage)<current_stage else -.5
 if bird_root!=null:
  var pass_time=fmod(clock+mission_index*8,83)
  bird_root.visible=pass_time<3.4
  if bird_root.visible:bird_root.position=Vector3(-80+pass_time*48,26+sin(clock)*.4,-60-clock*.03)
 if mission_index==9:set_boss_state(current_stage,clock)
 elif mission_index==5:
  for i in range(devices.size()):
   if i<current_stage:devices[i].basis=devices[i].get_meta("rest_basis",Basis.IDENTITY)*Basis(Vector3.UP,clock*1.3)

func build_routes():
 if mission_index==2:return
 var begin=Time.get_ticks_usec();var saved_stage=current_stage
 current_stage=4 # Build static terrain connectivity once; shutter rows are toggled below.
 nav_points.clear();nav_graph.clear();nav_links.clear();rebuild_cover_index()
 var grid={}
 for x in range(-48,49,4):
  for z in range(-196,41,4):
   var p=Vector3(x,0,z);p.y=surface_height(p)
   if blocked_at_height(p,p.y):continue
   var id=nav_points.size();nav_points.append(p);nav_graph.add_point(id,p);grid[Vector2i(x,z)]=id
 for cell in grid:
  for offset in [Vector2i(-4,-4),Vector2i(-4,0),Vector2i(-4,4),Vector2i(0,-4)]:
   var other=cell+offset
   if grid.has(other) and segment_open(nav_points[grid[cell]],nav_points[grid[other]]):nav_graph.connect_points(grid[cell],grid[other])
 current_stage=saved_stage;update_gate_navigation();set_meta("navigation_build_usec",Time.get_ticks_usec()-begin)

func update_gate_navigation():
 for i in range(nav_points.size()):
  var p=nav_points[i];var closed=false
  for gate in stage_gates:
   if int(gate.index)>=current_stage and absf(p.z-gate.at.z)<3.2 and absf(p.x)<9:closed=true;break
  nav_graph.set_point_disabled(i,closed)

func has_walk_support(p: Vector3,_tolerance: float=.5) -> bool:
 if mission_index==2:return NestCampaignMotorcycleWorld.supported(p)
 return surface_height(p)>-100 and absf(p.x)<52 and p.z> -202 and p.z<46

func route(start: Vector3,finish: Vector3,avoid: Array=[]) -> Array[Vector3]:
 if mission_index==2:return NestCampaignMotorcycleWorld.route(start,finish)
 return super.route(start,finish,avoid)

func blocked_point(p: Vector3) -> bool:
 return blocked_at_height(p,surface_height(p))

func blocked_at_height(p: Vector3,height: float) -> bool:
 if height< -100:return true
 if current_stage<3:
  for gate in stage_gates:
   if int(gate.index)>=current_stage and absf(p.z-gate.at.z)<1.1 and absf(p.x)<8.55:return true
 var candidates=cover_cells.get(Vector2i(floori(p.x/8),floori(p.z/8)),[]) if cover_index_ready else floor_cover
 for box in candidates:
  if box.position.y+box.size.y*.5<=height+.4 or box.position.y-box.size.y*.5>height+NestActor.STAND_HEIGHT:continue
  var offset=p-box.position
  if absf(offset.x)<box.size.x*.5+.55 and absf(offset.z)<box.size.z*.5+.55:return true
 return false

func rebuild_cover_index():
 cover_cells.clear()
 for box in floor_cover:
  var low=box.position-box.size*.5-Vector3(.55,0,.55);var high=box.position+box.size*.5+Vector3(.55,0,.55)
  for x in range(floori(low.x/8),floori(high.x/8)+1):
   for z in range(floori(low.z/8),floori(high.z/8)+1):
    var cell=Vector2i(x,z)
    if not cover_cells.has(cell):cover_cells[cell]=[]
    cover_cells[cell].append(box)
 cover_index_ready=true

func segment_open(a: Vector3,b: Vector3) -> bool:
 var distance=Vector2(a.x-b.x,a.z-b.z).length()
 var steps=maxi(8,ceili(distance/.2));var last_height=surface_height(a)
 var allowed_grade=distance/steps*.72+.025
 for i in range(steps+1):
  var p=a.lerp(b,float(i)/steps);p.y=surface_height(p)
  if blocked_at_height(p,p.y) or absf(p.y-last_height)>allowed_grade:return false
  last_height=p.y
 return true

func bot_surface_height(point: Vector3,reference: float,_max_delta: float=1.5) -> float:
 var height=surface_height(point)
 return height if height>-100 else reference
