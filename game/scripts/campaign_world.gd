class_name NestCampaignWorld
extends NestArena
var region="preparation"
var locations={}
var smoke_volumes=[]
var cover_points=[]
var moving=[]
var charge_mesh: Node3D
var charge_sign: Label3D
var secure_mesh: Node3D
var ancient_light: Node3D
var ambience: Environment
var quality=0
var scene_root: Node3D
var ship_root: Node3D
func map_title() -> String:return "Connectuct • Departure Readiness" if region=="preparation" else "Old Earth • Crash Site"
func _ready():
 pads.clear();pad_meshes.clear();pad_kinds.clear();pad_names.clear();pad_duration_dummy()
 spawns={0:[],1:[]};sites=[Vector3.ZERO,Vector3.ZERO];flag_positions=[Vector3.ZERO,Vector3.ZERO]
 for i in range(2):
  var n=Node3D.new();add_child(n);deposits.append(n);var label=Label3D.new();n.add_child(label);deposit_labels.append(label);sealed_bodies.append([])
 scene_root=Node3D.new();add_child(scene_root)
 environment_setup()
 if region=="preparation":build_preparation()
 else:build_forest()
func pad_duration_dummy():pass
func environment_setup():
 var node=WorldEnvironment.new();ambience=Environment.new();node.environment=ambience;add_child(node)
 var sky=Sky.new();var material=ProceduralSkyMaterial.new();material.sky_top_color=Color("234d68") if region=="preparation" else Color("182c31");material.sky_horizon_color=Color("cfb792") if region=="preparation" else Color("617c73");sky.sky_material=material
 ambience.background_mode=Environment.BG_SKY;ambience.sky=sky;ambience.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;ambience.ambient_light_color=Color("bed6d2");ambience.ambient_light_energy=.6 if region=="preparation" else .48
 ambience.fog_enabled=true;ambience.fog_light_color=Color("47605a");ambience.fog_density=.001 if region=="preparation" else .006;ambience.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-34,-25,0);sun.light_energy=1.0 if region=="preparation" else .7;sun.light_color=Color("ffe4bd");sun.shadow_enabled=quality<2;add_child(sun)
func block(pos: Vector3,size: Vector3,material: Material,solid=true) -> Node3D:
 var node=kit.box(scene_root,pos,size,material,solid)
 if solid:floor_cover.append({"position":pos,"size":size})
 return node
func sign_at(pos: Vector3,text: String,color=Color("aceec9"),size=28) -> Label3D:
 var label=kit.label(scene_root,pos,text,color,size);label.no_depth_test=false;label.visibility_range_end=35;return label
func ground(size: Vector2,material: Material):
 block(Vector3(0,-.4,0),Vector3(size.x,.8,size.y),material)
 floor_surfaces=[{"pos":Vector3.ZERO,"size":size}];bounds=size*.5
func station(id: String,pos: Vector3,text: String):
 locations[id]=pos;block(pos+Vector3(0,.7,0),Vector3(1.1,1.4,.7),kit.dark);block(pos+Vector3(0,1.45,0),Vector3(1.2,.1,.8),kit.gold,false);sign_at(pos+Vector3(0,2.2,0),text)
func build_preparation():
 var white=kit.material(Color("e4e9e6"),.3);ground(Vector2(150,140),white)
 for i in range(14):
  var pos=Vector3(-65+i*10,0,-44-abs(sin(i))*16);var height=14+fmod(i*17,36)
  block(pos+Vector3(0,height*.5,0),Vector3(7,height,9),white);block(pos+Vector3(0,height-2,4.6),Vector3(7,.3,.1),kit.gold,false)
  for j in range(3):block(pos+Vector3(0,3+j*6,4.65),Vector3(5,.12,.1),kit.lamp,false)
 for i in range(4):
  var shuttle=kit.box(scene_root,Vector3(-35+i*22,8,-30),Vector3(6,1.4,2),kit.gold);moving.append({"node":shuttle,"origin":shuttle.position,"phase":i})
 block(Vector3(0,.1,-26),Vector3(125,.3,7),kit.dark);sign_at(Vector3(0,4,-26),"TRANSIT SUSPENDED • COMPONENTS ALLOCATED TO MEDICAL GRID",Color("e7c075"),30)
 station("service",Vector3(-14,0,12),"01 • SUIT / EQUIPMENT CHECK")
 station("calibration",Vector3(-5,0,4),"02 • SHIELD CALIBRATION")
 block(Vector3(-5,1.5,9),Vector3(6,3,.6),white);cover_points.append(Vector3(-5,0,11))
 station("range",Vector3(6,0,3),"03 • SAFE FIRING BAY")
 for x in [3,6,9]:block(Vector3(x,1.4,-10),Vector3(1.1,2.8,.5),kit.gold)
 block(Vector3(6,2,-12),Vector3(15,4,1),white)
 block(Vector3(18,1.6,7),Vector3(.5,3.2,16),white);block(Vector3(24,1.6,7),Vector3(.5,3.2,16),white);block(Vector3(21,3.4,7),Vector3(6.5,.4,16),kit.dark)
 block(Vector3(21,2.5,4),Vector3(6,1.1,.4),kit.dark);block(Vector3(21,.2,10),Vector3(5,.4,.5),kit.gold)
 sign_at(Vector3(21,3,17),"04 • DARK SERVICE PASSAGE / CROUCH • FLASHLIGHT")
 locations["inspection"]=Vector3(21,0,4)
 ship(Vector3(-2,0,-17),false);locations["board"]=Vector3(-2,0,-8);locations["manifest"]=Vector3(-7,0,-8)
 station("manifest",locations.manifest,"05 • SURVEY CARGO / SEALED CHARGE")
 sign_at(Vector3(-2,4,-7),"EXPEDITION • OLD EARTH\nBOARD AFTER PERSONAL READINESS",Color("a8efd0"),32)
 for i in range(4):spawns[0].append(Vector3(-20+i*2,0,19))
 locations["medical"]=Vector3(-34,0,-7);block(Vector3(-34,2,-7),Vector3(9,4,10),white);sign_at(Vector3(-34,5,-1),"MEDICAL • PRIORITY POWER",Color("9beec6"))
 block(Vector3(-34,.55,-.2),Vector3(3,1.1,1.3),white);kit.sphere(scene_root,Vector3(-34,1.45,-.2),.65,kit.material(Color("65c68b")))
 for p in [Vector3(-31,0,1),Vector3(-9,0,-6),Vector3(-15,0,10)]:
  var visual=load(NestCharacterCatalog.by_index(0).visual).instantiate();scene_root.add_child(visual);visual.position=p;visual.scale=Vector3.ONE*NestActor.SIZE
  for animator in visual.find_children("*","AnimationPlayer",true,false):
   for clip in animator.get_animation_list():
    if str(clip).ends_with("idle"):animator.play(clip);break
 for i in range(5):block(Vector3(-8+i*.45,1.1,-6),Vector3(.2,.2,1.8),kit.gold,false)
 for i in range(3):block(Vector3(-35+i,1,-1),Vector3(.7,1.6,1),kit.gold)
 build_routes()
func ship(origin: Vector3,crashed: bool):
 var parent=scene_root;ship_root=Node3D.new();ship_root.name="ExpeditionHull";parent.add_child(ship_root);scene_root=ship_root
 var hull=kit.material(Color("b8c7c3"),.55)
 block(origin+Vector3(0,.12,0),Vector3(12,.24,19),hull)
 for x in [-6,6]:block(origin+Vector3(x,1.9,-1),Vector3(.6,3.8,17),hull)
 block(origin+Vector3(0,3.9,-3),Vector3(12,.35,12),hull);block(origin+Vector3(0,2,-9.4),Vector3(12,4,.5),hull)
 block(origin+Vector3(-14,.9,-3),Vector3(16,.5,6),hull);block(origin+Vector3(14,.9,-3),Vector3(16,.5,6),hull)
 for x in [-4,4]:
  kit.cylinder(scene_root,origin+Vector3(x,1,-11),1.4,3,kit.dark);kit.sphere(scene_root,origin+Vector3(x,1,-12.5),.8,kit.lamp)
 for z in [-5,-1,3]:
  for x in [-4,4]:block(origin+Vector3(x,.8,z),Vector3(1.2,1.6,1),kit.dark)
 sign_at(origin+Vector3(0,3,7),"ANKI • CONNECTUCT EXPEDITION",Color("a7f4d0"),26)
 if crashed:block(origin+Vector3(8,.8,10),Vector3(7,1.6,2),hull)
 scene_root=parent
func build_forest():
 ground(Vector2(150,150),kit.material(Color("333c2c")))
 ship_position=Vector3(0,0,9);ship(ship_position,true)
 locations={"radio":Vector3(-4,0,5),"secure":Vector3(4,0,4),"charge0":Vector3(-13,0,15),"charge1":Vector3(12,0,20),"charge2":Vector3(-8,0,-7),"engine":Vector3(-18,0,-2),"exit":Vector3(0,0,23)}
 station("radio",locations.radio,"EMERGENCY RADIO • LINK DAMAGED")
 station("secure",locations.secure,"SURVIVING CARGO LOCKER")
 charge_mesh=block(locations.charge0+Vector3(0,.45,0),Vector3(1.2,.9,.8),kit.gold,false);charge_sign=sign_at(locations.charge0+Vector3(0,1.6,0),"EXCAVATION CHARGE • ISOLATED",Color("a8efd0"),19)
 secure_mesh=block(locations.secure+Vector3(0,1.8,0),Vector3(.9,.5,.65),kit.gold,false);secure_mesh.visible=false
 station("ammo0",Vector3(-9,0,23),"CARBINE / PISTOL AMMUNITION")
 station("ammo1",Vector3(8,0,25),"ESCAPE SUPPLIES • PISTOL")
 station("ammo2",Vector3(3,0,2),"RESERVE AMMUNITION")
 station("weapon",Vector3(-12,0,8),"DAMAGED CRATE • NAKI PLASMA RIFLE")
 var leaf=kit.material(Color("234e2b"));var bark=kit.material(Color("443e2e"));var rng=RandomNumberGenerator.new();rng.seed=41519
 for i in range(70):
  var angle=i*2.399963;var radius=44+float(i%4)*6;var p=Vector3(cos(angle)*radius,0,sin(angle)*radius)
  var height=rng.randf_range(26,43);kit.cylinder(scene_root,p+Vector3(0,height*.5,0),1.1,height,bark)
  block(p+Vector3(0,.7,0),Vector3(2.1,1.4,2.1),bark)
  for j in range(4):
   var end=p+Vector3(cos(angle+j*1.57)*6,2.2,sin(angle+j*1.57)*6);kit.branch(scene_root,p+Vector3(0,.7,0),end,.5,bark)
   kit.branch(scene_root,p+Vector3(0,height*.68,0),p+Vector3(cos(j*1.7)*7,height*.85,sin(j*1.7)*7),.35,bark)
  for j in range(3):
   var canopy=kit.sphere(scene_root,p+Vector3(cos(j*2)*4,height-2+j*1.6,sin(j*2)*4),5.5,leaf);canopy.scale=Vector3(1.4,.55,1.3)
 for i in range(15):
  var angle=i*TAU/15;var p=Vector3(cos(angle)*34,1,sin(angle)*34);block(p,Vector3(6,2,2),bark);cover_points.append(p+Vector3(0,-1,3))
 for p in [Vector3(-16,1,24),Vector3(16,1,17),Vector3(-19,1,-13),Vector3(19,1,-18),Vector3(0,1,34)]:
  block(p,Vector3(4,2,2.5),kit.stone);cover_points.append(p+Vector3(0,-1,2))
 for x in [-1,1]:
  block(Vector3(x*52,2,0),Vector3(8,4,110),bark)
  block(Vector3(0,2,x*52),Vector3(110,4,8),bark)
 # These opaque engine-smoke columns have identical gameplay occlusion at all quality levels.
 for p in [Vector3(-19,2,-4),Vector3(19,2,-5)]:
  smoke_volumes.append({"center":p,"radius":3.3});var smoke=kit.material(Color("1d2424"))
  for j in range(5):kit.sphere(scene_root,p+Vector3(sin(j)*.8,j*2,cos(j)*.7),2.8+j*.2,smoke)
  var fire=kit.sphere(scene_root,p-Vector3(0,1.5,0),.8,kit.lamp);moving.append({"node":fire,"origin":fire.position,"phase":p.x})
 for i in range(12 if quality==2 else 32):
  var ash=kit.sphere(scene_root,Vector3(rng.randf_range(-30,30),rng.randf_range(1,9),rng.randf_range(-30,30)),.025,kit.gold);moving.append({"node":ash,"origin":ash.position,"phase":i})
 ancient_light=block(Vector3(8,.04,-13),Vector3(4,.08,.12),kit.lamp,false);ancient_light.visible=false
 for i in range(4):spawns[0].append(Vector3(-3+i*2,0,11))
 spawns[1]=[Vector3(-39,0,-22),Vector3(38,0,-18),Vector3(0,0,43)]
 for p in [Vector3(-35,1.8,-21),Vector3(34,1.8,-17),Vector3(0,1.8,38)]:block(p,Vector3(5,3.6,2),kit.stone)
 build_routes()
func build_routes():
 nav_points.clear();nav_graph.clear();nav_links.clear()
 for x in range(-44,45,4):
  for z in range(-44,45,4):
   var p=Vector3(x,0,z)
   if blocked_point(p):continue
   var id=nav_points.size();nav_points.append(p);nav_graph.add_point(id,p)
 for i in range(nav_points.size()):
  for j in range(i):
   if nav_points[i].distance_squared_to(nav_points[j])<=32.1 and segment_open(nav_points[i],nav_points[j]):nav_graph.connect_points(i,j)
func blocked_point(p: Vector3) -> bool:
 for box in floor_cover:
  if box.position.y+box.size.y*.5<=.45 or box.position.y-box.size.y*.5>1.7:continue
  var d=p-box.position
  if absf(d.x)<box.size.x*.5+.55 and absf(d.z)<box.size.z*.5+.55:return true
 return false
func segment_open(a: Vector3,b: Vector3) -> bool:
 for i in range(7):
  if blocked_point(a.lerp(b,i/6.0)):return false
 return true
func route(start: Vector3,finish: Vector3,_avoid: Array=[]) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 if segment_open(start,finish):result.append(finish);return result
 var a=nav_graph.get_closest_point(start);var b=nav_graph.get_closest_point(finish)
 if a>=0 and b>=0:
  for p in nav_graph.get_point_path(a,b):result.append(p)
 return result
func bot_surface_height(_point: Vector3,_reference: float,_max_delta: float=1.5) -> float:return 0.0
func has_walk_support(p: Vector3,_tolerance: float=.5) -> bool:return absf(p.x)<70 and absf(p.z)<70
func validate_navigation(_revision: int):pass
func set_sides(_attacking_faction: int,_names: Array=["NAKI","ANNU"]):pass
func set_site_visual(_index: int,_stage: String,_clock: float):pass
func smoke_blocks(a: Vector3,b: Vector3) -> bool:
 for volume in smoke_volumes:
  var near=Geometry3D.get_closest_point_to_segment(volume.center,a,b)
  if near.distance_to(volume.center)<volume.radius:return true
 return false
func animate(clock: float):
 for item in moving:
  if region=="preparation":item.node.position.x=item.origin.x+sin(clock*.15+item.phase)*12
  else:item.node.position=item.origin+Vector3(sin(clock+item.phase)*.2,sin(clock*.8+item.phase)*.15,0)
