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
var cover_cells={}
var cover_index_ready=false
var palette={}
var station_signs={}
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
 batch_campaign_scenery()
func pad_duration_dummy():pass
func environment_setup():
 var node=WorldEnvironment.new();ambience=Environment.new();node.environment=ambience;add_child(node)
 var sky=Sky.new();var material=ProceduralSkyMaterial.new();material.sky_top_color=Color("234d68") if region=="preparation" else Color("182c31");material.sky_horizon_color=Color("cfb792") if region=="preparation" else Color("617c73");sky.sky_material=material
 if region=="preparation":
  var atmosphere=ShaderMaterial.new();atmosphere.shader=load("res://assets/connectuct_atmosphere.gdshader");atmosphere.set_shader_parameter("weather_noise",load("res://assets/stone_noise.png"));atmosphere.set_shader_parameter("low_detail",quality==0);sky.sky_material=atmosphere;sky.radiance_size=Sky.RADIANCE_SIZE_128;sky.process_mode=Sky.PROCESS_MODE_QUALITY
 ambience.background_mode=Environment.BG_SKY;ambience.sky=sky;ambience.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;ambience.ambient_light_color=Color("bed6d2");ambience.ambient_light_energy=.6 if region=="preparation" else .48
 ambience.fog_enabled=true;ambience.fog_light_color=Color("47605a");ambience.fog_density=.001 if region=="preparation" else .006;ambience.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-34,-25,0);sun.light_energy=1.0 if region=="preparation" else .85;sun.light_color=Color("ffe4bd");sun.shadow_enabled=quality>0;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_max_distance=65;add_child(sun)
 ambience.ambient_light_energy=.38 if region=="preparation" else .35
 ambience.fog_light_color=Color("b4c5bc") if region=="preparation" else Color("697c70")
 ambience.fog_density=.0015 if region=="preparation" else .0035
 ambience.fog_sky_affect=0.0
 palette["panel"]=surface("abbcb9","d5d5bc",1,.25)
 palette["hull"]=surface("718c8d","bdc8b6",1,.55)
 palette["soil"]=surface("3a3025","536345",0)
 palette["bark"]=surface("3c2b23","736348",2)
 palette["leaf"]=surface("193c31","71854a",3)
 palette["rock"]=surface("485456","7b806b",0)
 palette["tower_teal"]=surface("426b78","7a9c9a",1,.2)
 palette["tower_copper"]=surface("825c48","b29c76",1,.3)
 palette["tower_slate"]=surface("555b76","9296a8",1,.25)
func surface(base: String,accent: String,kind: int,metal=0.0) -> ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=load("res://assets/campaign_surface.gdshader");material.set_shader_parameter("noise_texture",load("res://assets/stone_noise.png"));material.set_shader_parameter("base_color",Color(base));material.set_shader_parameter("accent_color",Color(accent));material.set_shader_parameter("surface_kind",float(kind));material.set_shader_parameter("metalness",metal);material.set_shader_parameter("low_detail",quality==0);return material
func block(pos: Vector3,size: Vector3,material: Material,solid=true) -> Node3D:
 var node=kit.box(scene_root,pos,size,material,solid)
 if solid:floor_cover.append({"position":pos,"size":size})
 return node
func sign_at(pos: Vector3,text: String,color=Color("aceec9"),size=28) -> Label3D:
 var label=kit.label(scene_root,pos,text,color,size);label.visible=true;label.no_depth_test=false;label.visibility_range_end=30;return label
func ground(size: Vector2,material: Material):
 block(Vector3(0,-.4,0),Vector3(size.x,.8,size.y),material)
 floor_surfaces=[{"pos":Vector3.ZERO,"size":size}];bounds=size*.5
func station(id: String,pos: Vector3,text: String):
 locations[id]=pos;block(pos+Vector3(0,.7,0),Vector3(1.1,1.4,.7),kit.dark);block(pos+Vector3(0,1.45,0),Vector3(1.2,.1,.8),kit.gold,false);sign_at(pos+Vector3(0,2.2,0),text)
 station_signs[id]=scene_root.get_child(scene_root.get_child_count()-1)
 block(pos+Vector3(0,1.05,.36),Vector3(.72,.35,.025),palette.hull,false)
 for x in [-.24,0,.24]:block(pos+Vector3(x,.48,.36),Vector3(.04,.42,.025),kit.gold,false)
 block(pos+Vector3(.39,1.14,.38),Vector3(.07,.08,.025),kit.lamp,false)
func build_preparation():
 var white=palette.panel;ground(Vector2(150,140),white)
 for i in range(14):
  var pos=Vector3(-65+i*10,0,-44-abs(sin(i))*16);var height=14+fmod(i*17,36)
  var facade=[white,palette.tower_teal,white,palette.tower_copper,palette.tower_slate][i%5]
  block(pos+Vector3(0,height*.5,0),Vector3(7,height,9),facade);block(pos+Vector3(0,height-2,4.6),Vector3(7,.3,.1),kit.gold,false)
  block(pos+Vector3(0,height+.4,-1),Vector3(5,.8,6),palette.hull,false)
  if i%3==0:
   block(pos+Vector3(0,height*.6,5.2),Vector3(8,.35,2.1),kit.dark,false)
   for x in [-2,0,2]:kit.sphere(scene_root,pos+Vector3(x,height*.6+.55,5.2),.7,palette.leaf)
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
 ship(Vector3(-2,0,-17),false);locations["board"]=Vector3(-2,0,-13);locations["manifest"]=Vector3(-7,0,-8);locations["shield_cover"]=Vector3(-5,0,12)
 station("manifest",locations.manifest,"05 • SURVEY CARGO / SEALED CHARGE")
 sign_at(Vector3(-2,4,-7),"EXPEDITION • OLD EARTH\nBOARD AFTER PERSONAL READINESS",Color("a8efd0"),32)
 sign_at(Vector3(-2,2.4,-11),"CABIN • SECURE BOARDING POSITION",Color("93e5ed"),22)
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
 dress_preparation();build_routes()
func ship(origin: Vector3,crashed: bool):
 var parent=scene_root;ship_root=Node3D.new();ship_root.name="ExpeditionHull";parent.add_child(ship_root);scene_root=ship_root
 var hull=palette.hull
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
 # Ribbing, cockpit glass, navigation strips and equipment fasteners stay with the animated hull.
 for z in [-7,-3,1,5]:
  for x in [-5.65,5.65]:block(origin+Vector3(x,2,z),Vector3(.12,3.3,.16),kit.dark,false)
 for x in [-3,0,3]:block(origin+Vector3(x,2.5,-9.08),Vector3(2.5,1.1,.08),kit.dark,false)
 for x in [-5,5]:
  block(origin+Vector3(x,.27,0),Vector3(.12,.035,15),kit.gold,false)
  for z in [-6,0,6]:block(origin+Vector3(x,3.55,z),Vector3(.5,.1,.3),kit.lamp,false)
 scene_root=parent
func build_forest():
 ground(Vector2(150,150),palette.soil)
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
 var leaf=palette.leaf;var bark=palette.bark;var rng=RandomNumberGenerator.new();rng.seed=41519
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
 for i in range(12 if quality==0 else 32):
  var ash=kit.sphere(scene_root,Vector3(rng.randf_range(-30,30),rng.randf_range(1,9),rng.randf_range(-30,30)),.025,kit.gold);moving.append({"node":ash,"origin":ash.position,"phase":i})
 ancient_light=block(Vector3(8,.04,-13),Vector3(4,.08,.12),kit.lamp,false);ancient_light.visible=false
 for i in range(4):spawns[0].append(Vector3(-3+i*2,0,11))
 spawns[1]=[Vector3(-39,0,-22),Vector3(38,0,-18),Vector3(0,0,43)]
 for p in [Vector3(-35,1.8,-21),Vector3(34,1.8,-17),Vector3(0,1.8,38)]:block(p,Vector3(5,3.6,2),kit.stone)
 dress_forest();build_routes()
func build_routes():
 nav_points.clear();nav_graph.clear();nav_links.clear()
 rebuild_cover_index()
 var grid={}
 for x in range(-44,45,4):
  for z in range(-44,45,4):
   var p=Vector3(x,0,z)
   if blocked_point(p):continue
   var id=nav_points.size();nav_points.append(p);nav_graph.add_point(id,p);grid[Vector2i(x,z)]=id
 # Only these four predecessors can pass the former distance <= 32.1 test.
 for cell in grid:
  var i=int(grid[cell])
  for offset in [Vector2i(-4,-4),Vector2i(-4,0),Vector2i(-4,4),Vector2i(0,-4)]:
   var neighbour=cell+offset
   if grid.has(neighbour):
    var j=int(grid[neighbour])
    if segment_open(nav_points[i],nav_points[j]):nav_graph.connect_points(i,j)
func rebuild_cover_index():
 cover_cells.clear()
 for box in floor_cover:
  if box.position.y+box.size.y*.5<=.45 or box.position.y-box.size.y*.5>1.7:continue
  var low=box.position-box.size*.5-Vector3(.55,0,.55);var high=box.position+box.size*.5+Vector3(.55,0,.55)
  for x in range(floori(low.x/8),floori(high.x/8)+1):
   for z in range(floori(low.z/8),floori(high.z/8)+1):
    var cell=Vector2i(x,z)
    if not cover_cells.has(cell):cover_cells[cell]=[]
    cover_cells[cell].append(box)
 cover_index_ready=true
func blocked_point(p: Vector3) -> bool:
 var candidates=cover_cells.get(Vector2i(floori(p.x/8),floori(p.z/8)),[]) if cover_index_ready else floor_cover
 for box in candidates:
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

func dress_preparation():
 # Flush paint and recessed-looking seams add scale without altering routes.
 var teal=kit.material(Color("247b78"),.3);var ochre=kit.material(Color("c28143"),.2)
 for x in [-26,28]:
  block(Vector3(x,.025,3),Vector3(.18,.025,45),teal,false)
  for z in range(-16,24,4):block(Vector3(x+1,.028,z),Vector3(.65,.025,1.5),ochre,false)
 for index in range(14):
  var p=Vector3(-65+index*10,0,-44-abs(sin(index))*16);var h=14+fmod(index*17,36)
  block(p+Vector3(-2.5,h*.5,4.58),Vector3(.55,h-2,.12),teal if index%3 else ochre,false)
  for y in range(2,int(h)-2,3):
   for x in [-1,1]:block(p+Vector3(x*1.3,y,4.57),Vector3(1.8,1.2,.1),kit.dark,false)
 for id in ["service","calibration","range","manifest"]:
  var p=locations[id]
  block(p+Vector3(0,1.12,.37),Vector3(.72,.35,.035),teal,false)
  for x in [-.35,0,.35]:block(p+Vector3(x,.5,.37),Vector3(.04,.6,.025),kit.gold,false)
 for p in [Vector3(-28,0,-12),Vector3(29,0,-15),Vector3(-27,0,26)]:
  block(p+Vector3(0,.3,0),Vector3(3,.6,2),palette.hull,false)
  for i in range(4):kit.sphere(scene_root,p+Vector3(-1+i*.65,.85,0),.6,palette.leaf)
 var glass=kit.material(Color("1b5067"),.72);glass.roughness=.22
 var copper=kit.material(Color("a26046"),.55);var blue=kit.material(Color("326887"),.4)
 # Color-coded bay panels and repair infrastructure make the departure route legible.
 for setup in [[Vector3(-14,0,12),Color("478fa0")],[Vector3(-5,0,4),Color("9068a0")],[Vector3(6,0,3),Color("c68b45")],[Vector3(21,0,4),Color("547d63")]]:
  var p=setup[0];var paint=kit.material(setup[1],.2)
  for side in [-1,1]:block(p+Vector3(side*1.8,.05,1.5),Vector3(.28,.06,3.2),paint,false)
 for side in [-1,1]:
  var p=Vector3(side*39,0,15)
  block(p+Vector3(0,1,0),Vector3(4,2,6),blue,false)
  for i in range(5):block(p+Vector3(0,2.05,-2+i),Vector3(3.7,.08,.65),glass,false)
  for i in range(3):
   kit.cylinder(scene_root,p+Vector3(side*2.5,2.2,-2+i*1.6),.22,4.4,copper)
   kit.branch(scene_root,p+Vector3(side*2.5,4.2,-2+i*1.6),p+Vector3(0,4.2,-2+i*1.6),.12,copper)
  block(p+Vector3(0,4.2,0),Vector3(4.5,.3,5.8),palette.hull,false)
 # An ozone-monitoring tower is scenery only: the atmospheric warning is fictional.
 for side in [-1,1]:
  var p=Vector3(side*47,0,-25)
  kit.cylinder(scene_root,p+Vector3(0,10,0),.55,20,kit.dark)
  for h in [6,11,16]:
   block(p+Vector3(0,h,0),Vector3(5,.25,1),copper,false)
   for x in [-2,2]:block(p+Vector3(x,h+.35,0),Vector3(.2,.5,.2),kit.lamp,false)
  sign_at(p+Vector3(0,4,2),"ATMOSPHERIC SHIELDING\nDEGRADED • REPAIR ALLOCATION PENDING",Color("e2a573"),22)
 # A small number of unshadowed accent lights; emission strips carry most detail.
 accent_light(Vector3(-14,2,12),Color("70c9b7"),.6,5)
 accent_light(Vector3(-34,3,-1),Color("ddac68"),.7,7)

func accent_light(pos: Vector3,color: Color,energy: float,radius: float):
 if quality==0:return
 var light=OmniLight3D.new();light.position=pos;light.light_color=color;light.light_energy=energy;light.omni_range=radius;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=25;light.distance_fade_length=10;scene_root.add_child(light)

func dress_forest():
 var rng=RandomNumberGenerator.new();rng.seed=712405
 # Low opaque fronds have no transparent overdraw, collision or AI occlusion.
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(5):
  var angle=i*TAU/5;var tip=Vector3(cos(angle)*.65,.32,sin(angle)*.65);var side=Vector3(-sin(angle)*.12,0,cos(angle)*.12)
  for vertex in [Vector3(0,.03,0),tip*.55+side,tip,Vector3(0,.03,0),tip,tip*.55-side]:tool.set_normal(Vector3.UP);tool.add_vertex(vertex)
 var frond=tool.commit();var material=kit.material(Color("728455"));material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.vertex_color_use_as_albedo=true
 var groups={}
 for i in range(650 if quality==0 else 1500):
  var p=Vector3(rng.randf_range(-48,48),.025,rng.randf_range(-48,48))
  if absf(p.x)<8 and p.z>-3 and p.z<20:continue
  var near_objective=false
  for location in locations.values():
   if p.distance_squared_to(location)<9:near_objective=true;break
  if near_objective:continue
  var key=Vector2i(floori(p.x/12),floori(p.z/12))
  if not groups.has(key):groups[key]=[]
  var scale=rng.randf_range(.45,1.25);groups[key].append({"transform":Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),p),"color":Color("91a16a").lerp(Color("385e45"),rng.randf())})
 for key in groups:
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=frond;mm.instance_count=groups[key].size()
  var origin=Vector3(key.x*12,0,key.y*12)
  for i in range(mm.instance_count):
   var item=groups[key][i];var transform=item.transform;transform.origin-=origin;mm.set_instance_transform(i,transform);mm.set_instance_color(i,item.color)
  var node=MultiMeshInstance3D.new();node.name="ForestUnderstoryCell";node.multimesh=mm;node.material_override=material;node.position=origin;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=38 if quality==0 else 55;scene_root.add_child(node)
 # Jagged rock clusters and debris hug existing opaque cover; no new blockers.
 for p in [Vector3(-16,0,24),Vector3(16,0,17),Vector3(-19,0,-13),Vector3(19,0,-18),Vector3(0,0,34)]:
  for i in range(5):
   var rock=kit.sphere(scene_root,p+Vector3(rng.randf_range(-2,2),.3,rng.randf_range(-1.2,1.2)),rng.randf_range(.35,.85),palette.rock);rock.scale=Vector3(1.4,.65,1);rock.rotation=Vector3(.2,rng.randf()*TAU,.3)
 for side in [-1,1]:
  for i in range(9):
   var panel=block(Vector3(side*(15+i*.5),.08,-3+i*1.7),Vector3(rng.randf_range(.4,1.3),.1,rng.randf_range(.5,1.5)),palette.hull,false);panel.rotation.y=rng.randf()*TAU
  accent_light(Vector3(side*19,1.6,-4),Color("ed873d"),1.8,7)

func batch_campaign_scenery():
 # Batch each rigid coordinate space independently so the cinematic hull still moves.
 var groups={};var removed=0;var triangles=0
 var dynamic=[charge_mesh,secure_mesh,ancient_light]
 for item in moving:dynamic.append(item.node)
 for parent in [scene_root,ship_root]:
  if parent==null:continue
  for original in parent.get_children():
   if not original is MeshInstance3D or original in dynamic or not original.visible:continue
   var mat=original.material_override
   if mat==null:continue
   var p=original.position;var cell=Vector3i(floori(p.x/16),floori(p.y/12),floori(p.z/16))
   var key="%d:%d:%s:%d"%[parent.get_instance_id(),mat.get_instance_id(),str(cell),original.cast_shadow]
   if not groups.has(key):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(mat);groups[key]={"tool":tool,"parent":parent,"shadow":original.cast_shadow}
   for s in range(original.mesh.get_surface_count()):
    groups[key].tool.append_from(original.mesh,s,original.transform)
    var arrays=original.mesh.surface_get_arrays(s);triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
   original.hide();original.queue_free();removed+=1
 for group in groups.values():
  var node=MeshInstance3D.new();node.name="CampaignSceneryBatch";node.mesh=group.tool.commit();node.cast_shadow=group.shadow;group.parent.add_child(node)
 batch_stats={"original_meshes":removed,"batches":groups.size(),"triangles":triangles}
