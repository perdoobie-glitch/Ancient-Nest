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
  enrich_environment();build_objectives();build_routes();build_birds()
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
 var sky_material=ambience.sky.sky_material
 if sky_material is ProceduralSkyMaterial:
  sky_material.sky_top_color=Color("1f2839") if mission_index in [6,8,9] else Color("567c8d")
  sky_material.sky_horizon_color=Color(colors.get(mission_index,"738c7e"))
  sky_material.ground_horizon_color=sky_material.sky_horizon_color

func stage_center(stage: int) -> Vector3:
 if mission_index==9:return Vector3(0,0,-55)
 return Vector3(0,0,-55*clampi(stage,0,3))

func objective_position(stage: int) -> Vector3:
 if mission_index==9:return [Vector3(-28,0,-38),Vector3(28,0,-65),Vector3(-21,0,-88),Vector3(0,0,-166)][clampi(stage,0,3)]
 if mission_index==7:return stage_center(stage)+Vector3(-12 if stage%2==0 else 12,0,-8)
 return stage_center(stage)+Vector3(-22 if stage%2==0 else 22,0,-8)

func checkpoint_spawn(stage: int,slot: int) -> Vector3:
 if mission_index==2:return NestCampaignMotorcycleWorld.spawn(stage,slot)
 var base=Vector3(0,.25,30) if stage==0 else stage_center(stage)+Vector3(0,.25,22)
 if mission_index==9:base=Vector3(0,.25,14)
 return base+Vector3((posmod(slot-1,4)-1.5)*1.7,0,0)

func encounter_spawns(stage: int) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 if mission_index==2:
  return NestCampaignMotorcycleWorld.encounter_spawns(stage)
 var center=stage_center(stage)
 if mission_index==9:center=Vector3(0,0,-55)
 for offset in [Vector3(-38,0,-14),Vector3(38,0,-14),Vector3(-34,0,6),Vector3(34,0,6),Vector3(-16,0,-21),Vector3(16,0,-21),Vector3(-38,0,14),Vector3(38,0,14),Vector3(-12,0,-10),Vector3(12,0,-10),Vector3(-30,0,-20),Vector3(30,0,-20)]:
  var candidate=center+offset
  if not blocked_point(candidate):result.append(candidate+Vector3.UP*.25)
 # Deterministic, navigable replacements when a mission's machinery occupies an approach.
 for x in range(-38,39,4):
  for z in range(-20,21,8):
   var candidate=center+Vector3(x,0,z)
   if result.size()<12 and not blocked_point(candidate) and candidate.distance_to(objective_position(stage))>5:result.append(candidate+Vector3.UP*.25)
 return result

func build_layout():
 var floor_colors={3:"50666a",4:"777b68",5:"3d454a",6:"34424e",7:"746d62",8:"394653",9:"302f37"}
 var floor_material=kit.material(Color(floor_colors.get(mission_index,"50605a")),.12)
 floor_material.roughness=.88;ground(Vector2(150,440),floor_material)
 for side in [-1,1]:
  block(Vector3(side*56,5,-78),Vector3(8,10,268),palette.rock)
  for i in range(12):
   var p=Vector3(side*(59+rng.randf_range(1,9)),rng.randf_range(4,8),32-i*22)
   var rock=kit.sphere(scene_root,p,rng.randf_range(8,14),palette.rock);rock.scale=Vector3(.8,1.6,1.3)
 block(Vector3(0,4,48),Vector3(118,8,4),palette.rock)
 block(Vector3(0,4,-204),Vector3(118,8,4),palette.rock)
 for i in range(4):spawns[0].append(Vector3((i-1.5)*1.7,0,30))
 spawns[1]=[Vector3(-34,0,-10),Vector3(34,0,-10)]
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
   var arch=Vector3(0,0,-28-i*55)
   for side in [-1,1]:block(arch+Vector3(side*9,4,0),Vector3(1.8,8,2.1),palette.rock)
   block(arch+Vector3(0,8,0),Vector3(20,1.5,2.1),palette.rock)
   for side in [-1,1]:block(arch+Vector3(side*32,3.5,0),Vector3(46,7,2),palette.rock)
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

func build_objectives():
 for i in range(chapter_data.stages.size()):
  var p=objective_position(i);var entry=chapter_data.stages[i]
  station("objective"+str(i),p,str(entry.title).to_upper())
  var indicator=block(p+Vector3(0,1.7,-.2),Vector3(.6,.14,.16),warning,false)
  indicator.set_meta("keep_mesh",true);status_lights.append(indicator)
  var supply=stage_center(i)+Vector3(8,0,18)
  if mission_index==9:supply=Vector3(-35+i*21,0,17)
  station("supply"+str(i),supply,"EXPEDITION RESUPPLY")
  scenery.cargo(supply+Vector3(2,0,-.3),teal,i)
  var gun=NestWeaponArt.create("plasma_pistol" if i%2==0 else "rifle",0);scene_root.add_child(gun);gun.position=supply+Vector3(0,1.8,0);gun.scale=Vector3.ONE*.6
  var marker=ring(p+Vector3(0,.05,1.6),2.1,.05,kit.gold);marker.rotation.x=0
 locations["exit"]=Vector3(0,0,-190)
 for i in range(2):
  var evidence=Vector3(32 if i==0 else -32,0,-35-i*80)
  station("evidence"+str(i),evidence,"ARCHIVE / OPTIONAL FIELD RECORD")
  block(evidence+Vector3(0,1.5,-.3),Vector3(2,.2,1),copper,false)
 sign_at(Vector3(0,4,39),"EXPEDITION / "+str(mission_index).pad_zeros(2)+"\n"+str(chapter_data.title).to_upper(),Color("c2ebda"),32)

func ring(p: Vector3,radius: float,thickness: float,mat: Material) -> MeshInstance3D:
 var shape=TorusMesh.new();shape.inner_radius=maxf(.01,radius-thickness);shape.outer_radius=radius+thickness;shape.rings=20;shape.ring_segments=6
 return kit.mesh(scene_root,shape,p,mat)

func tube(p: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=12
 return kit.mesh(scene_root,shape,p,mat)

func solid_cylinder(p: Vector3,radius: float,height: float,mat: Material):
 kit.cylinder(scene_root,p,radius,height,mat,true)
 floor_cover.append({"position":p,"size":Vector3(radius*2,height,radius*2)})

func pipe(a: Vector3,b: Vector3,radius: float,mat: Material):kit.branch(scene_root,a,b,radius,mat)

func build_floodgate():
 for i in range(4):
  var p=stage_center(i)
  for side in [-1,1]:
   var basin=block(p+Vector3(side*37,-.05,0),Vector3(24,.12,42),water_material,false);basin.set_meta("keep_mesh",true);water_planes.append(basin)
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
  for side in [-1,1]:scenery.cargo(p+Vector3(side*41,0,19),palette.tower_slate,i)
  sign_at(p+Vector3(0,3,-23),["INTAKE / BACK PRESSURE","BYPASS / LOWER BASIN","FREIGHT CAUSEWAY","DOWNSTREAM ACCESS"][i],Color("93c7ce"),22)
 for i in range(9):block(Vector3(-40+i*10,2.3,-195),Vector3(5,4.6,3),teal)

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
  var plinth=p+Vector3(0,.8,-14);block(plinth,Vector3(8,1.6,5),palette.rock)
  var disc=ring(plinth+Vector3(0,2,0),3,.18,copper);disc.rotation.x=PI*.5;disc.set_meta("keep_mesh",true);devices.append(disc)
  for j in range(3):
   block(p+Vector3(-4+j*4,4,-20),Vector3(2.7,5,.5),palette.rock)
   for line in range(4):block(p+Vector3(-4+j*4,2.4+line*.8,-19.7),Vector3(1.7,.08,.05),kit.gold,false)
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
  block(p+Vector3(0,11,0),Vector3(103,1.1,2),palette.tower_slate)
  for side in [-1,1]:block(p+Vector3(side*50,5.5,0),Vector3(1.1,11,2),palette.tower_slate)
  sign_at(p+Vector3(0,8.5,0),["RECYCLE / COOLANT BEFORE CURRENT","SORTING / CONDUCTOR SALVAGE","REFINING / RETIRED STOCK ONLY","FREIGHT / CONNECTUCT ALLOCATION"][i],Color("f4bc70"),23)

func build_rail():
 for x in [-6,6]:block(Vector3(x,.08,-78),Vector3(.22,.16,245),copper,false)
 for z in range(-195,42,4):block(Vector3(0,.035,z),Vector3(15,.07,.45),palette.tower_slate,false)
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
  var ring_node=ring(dish_position+Vector3(0,6.2,0),5.5,.2,kit.gold);ring_node.rotation.x=.45;ring_node.set_meta("keep_mesh",true);devices.append(ring_node)
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
  var strip=block(center+Vector3(-24+i*24,.045,0),Vector3(13,.07,66),warning,false);strip.set_meta("keep_mesh",true);strip.hide();boss_warnings.append(strip)
 for side in [-1,1]:
  for z in [-18,-50,-82]:
   block(Vector3(side*18,1.6,z),Vector3(5,3.2,2),palette.rock)
   cover_points.append(Vector3(side*18,0,z+2))
 sign_at(Vector3(0,19,-55),"ANCIENT AI / CUSTODIAL RECLAMATION",Color("e4c482"),35)
 sign_at(Vector3(0,5,-132),"CONDUCTOR RESERVE / CONNECTUCT RETURN",Color("a1d9c5"),27)
 for i in range(5):scenery.cargo(Vector3(-12+i*6,0,-152),palette.hull,i)
 # Reuse the expedition hull asset for the Relay's extraction ship, without a new pilot/cast.
 ship(Vector3(0,0,-179),false)

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
      for z in [-18,0,18]:ring(p+Vector3(side*x,10.5,z),.42,.1,kit.gold).rotation.x=PI*.5
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
     pipe(point,center+Vector3(cos(angle)*48,16,sin(angle)*48),.25,copper)
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
    scene_root=old_parent
 if mission_index==3:
  block(Vector3(0,14,-208),Vector3(128,28,9),palette.rock,false)
  for x in range(-50,51,20):
   block(Vector3(x,11,-202.8),Vector3(12,20,.6),teal,false)
   for y in range(3,22,3):block(Vector3(x,y,-202.3),Vector3(12,.35,.8),copper,false)
   block(Vector3(x,5,-201.8),Vector3(7,8,.2),water_material,false)

func boss_weakpoint(stage: int) -> Vector3:
 return [Vector3(-16,3.3,-42),Vector3(16,3.3,-64),Vector3(-10,3.3,-79)][clampi(stage,0,2)]

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
 for i in range(water_planes.size()):water_planes[i].position.y=-.05-minf(stage,4)*.2
 for i in range(devices.size()):
  var device=devices[i]
  if mission_index==6:device.material_override=active_material if i/2<stage else warning
  elif i<stage:device.rotation.z=PI*.5
 for gate in stage_gates:
  var opened=int(gate.index)<stage
  gate.root.position=gate.at+Vector3(0,7.5 if opened else 0,0)
  gate.shape.set_deferred("disabled",opened)
  if mission_index==8 and int(gate.index)==0:gate.root.visible=not opened
 for fragment in seal_fragments:fragment.visible=stage>0
 if changed and mission_index!=2:build_routes()

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
 if bird_root!=null:
  var pass_time=fmod(clock+mission_index*8,83)
  bird_root.visible=pass_time<3.4
  if bird_root.visible:bird_root.position=Vector3(-80+pass_time*48,26+sin(clock)*.4,-60-clock*.03)
 if mission_index==9:set_boss_state(current_stage,clock)
 elif mission_index==5:
  for i in range(devices.size()):
   if i<current_stage:devices[i].rotation.z=clock*1.3

func build_routes():
 if mission_index==2:return
 nav_points.clear();nav_graph.clear();nav_links.clear();rebuild_cover_index()
 var grid={}
 for x in range(-48,49,4):
  for z in range(-196,41,4):
   var p=Vector3(x,0,z)
   if blocked_point(p):continue
   var id=nav_points.size();nav_points.append(p);nav_graph.add_point(id,p);grid[Vector2i(x,z)]=id
 for cell in grid:
  for offset in [Vector2i(-4,-4),Vector2i(-4,0),Vector2i(-4,4),Vector2i(0,-4)]:
   var other=cell+offset
   if grid.has(other) and segment_open(nav_points[grid[cell]],nav_points[grid[other]]):nav_graph.connect_points(grid[cell],grid[other])

func has_walk_support(p: Vector3,_tolerance: float=.5) -> bool:
 if mission_index==2:return NestCampaignMotorcycleWorld.supported(p)
 return absf(p.x)<52 and p.z> -202 and p.z<46

func route(start: Vector3,finish: Vector3,avoid: Array=[]) -> Array[Vector3]:
 if mission_index==2:return NestCampaignMotorcycleWorld.route(start,finish)
 return super.route(start,finish,avoid)

func blocked_point(p: Vector3) -> bool:
 for gate in stage_gates:
  if int(gate.index)>=current_stage and absf(p.z-gate.at.z)<1.1 and absf(p.x)<8.55:return true
 return super.blocked_point(p)
