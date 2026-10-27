class_name NestCampaignFloodgateArchiveDetails
extends RefCounted
# Mechanical and archival detail stays against existing solids or above clearance.
# Groups use local coordinates and the normal static batching path.
var w
var k
var root: Node3D
var m={}
var indicators=[]
var needles=[]
var rotors=[]
var freight_water=[]
var residential_water=[]
var stats={"flanges":0,"pipe_runs":0,"shelves":0,"tablets":0,"relief_panels":0,"arches":0}

static func build(world):
 if world.mission_index not in [3,4]:return
 var detail=load("res://scripts/campaign_floodgate_archive_details.gd").new();detail.w=world;detail.k=world.kit;detail.populate()

static func update_stage(world,stage: int):
 for entry in world.get_meta("flood_archive_indicators",[]):
  if is_instance_valid(entry.node):entry.node.material_override=world.active_material if int(entry.stage)<stage else world.warning
 for entry in world.get_meta("flood_archive_needles",[]):
  if is_instance_valid(entry.node):entry.node.rotation.z=-.68 if int(entry.stage)<stage else .72
 for entry in world.get_meta("flood_archive_rotors",[]):
  if is_instance_valid(entry.node):entry.node.rotation.z=PI*.25 if int(entry.stage)<stage else 0.0
 for node in world.get_meta("flood_archive_freight_water",[]):
  if is_instance_valid(node):node.visible=stage<3

func populate():
 m.stone=NestFrontierMaps.mat(w,"b9b7a3" if w.mission_index==4 else "818e8b",0,"garden_stone")
 m.arch=m.stone.duplicate();m.arch.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.worn=NestFrontierMaps.mat(w,"858d83",0,"weathered")
 m.dark=NestFrontierMaps.mat(w,"344146",.55,"dark_alloy")
 m.steel=NestFrontierMaps.mat(w,"9ca6a2",.65,"alloy")
 m.teal=NestFrontierMaps.mat(w,"47777b",.45,"alloy")
 m.copper=NestFrontierMaps.mat(w,"aa7953",.65,"weathered")
 m.gold=NestFrontierMaps.mat(w,"c4a16a",.65,"alloy")
 m.rust=NestFrontierMaps.mat(w,"71513e",.2,"weathered")
 m.moss=NestFrontierMaps.mat(w,"4d6043",0,"moss")
 m.leaf=m.moss.duplicate();m.leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.water=ShaderMaterial.new();m.water.shader=load("res://assets/campaign_river.gdshader")
 m.paper=NestFrontierMaps.mat(w,"c0b68f",0,"garden_stone")
 m.slate=NestFrontierMaps.mat(w,"52626a",.1,"slate")
 m.floor=NestFrontierMaps.mat(w,"a39d85" if w.mission_index==4 else "788a8b",.08,"slate")
 m.black=k.material(Color("162b2f"),.15);m.glass=k.material(Color("183c41"),.4);m.glass.roughness=.18
 m.light=NestFrontierMaps.glow(w,"e8d7a6")
 # Replace broad plain-color blockout faces with the project's weathered textures.
 for node in w.scene_root.get_children():
  if not node is MeshInstance3D:continue
  # Replace the old cylindrical roof ribs with the shaped masonry spans below.
  if w.mission_index==4 and node.mesh is CylinderMesh and node.mesh.top_radius>=.79 and node.mesh.top_radius<=1.01 and (is_equal_approx(absf(node.position.x),11.0) or is_equal_approx(absf(node.position.x),32.5)):
   node.hide();node.queue_free();continue
  if node.material_override==w.palette.rock:node.material_override=m.stone
  elif node.material_override==w.teal:node.material_override=m.teal
  elif node.material_override==w.copper:node.material_override=m.copper
  if (node.mesh is BoxMesh and is_equal_approx(node.mesh.size.y,1.3) and node.mesh.size.x>70) or String(node.name).begins_with("WalkableRampBridge"):node.material_override=m.floor
 for stage in range(4):
  root=Node3D.new();root.name=("FloodgateEngineering" if w.mission_index==3 else "ArchiveCraft")+str(stage);w.scene_root.add_child(root);root.position=w.stage_center(stage)
  if w.mission_index==3:floodgate(stage)
  else:archive(stage)
  NestRigidBatch.build(root)
  for visual in root.find_children("*","MeshInstance3D",true,false):
   visual.visibility_range_end=90.0 if w.quality==0 else 140.0
   visual.visibility_range_end_margin=15.0
 w.set_meta("flood_archive_indicators",indicators);w.set_meta("flood_archive_needles",needles);w.set_meta("flood_archive_rotors",rotors);w.set_meta("flood_archive_freight_water",freight_water);w.set_meta("flood_archive_residential_water",residential_water);w.set_meta("flood_archive_detail_counts",stats)

func box(at: Vector3,size: Vector3,material: Material,parent: Node3D=null):
 return k.box(root if parent==null else parent,at,size,material)

func cylinder(at: Vector3,radius: float,length: float,material: Material,axis=Vector3.UP,parent: Node3D=null):
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=length;shape.radial_segments=12
 var node=k.mesh(root if parent==null else parent,shape,at,material);node.quaternion=Quaternion(Vector3.UP,axis.normalized());return node

func pipe(a: Vector3,b: Vector3,radius: float,material: Material):
 if a.distance_to(b)<.01:return null
 stats.pipe_runs+=1;return cylinder((a+b)*.5,radius,a.distance_to(b),material,(b-a).normalized())

func ring(at: Vector3,radius: float,thickness: float,material: Material,axis=Vector3.UP,parent: Node3D=null):
 var shape=TorusMesh.new();shape.inner_radius=radius-thickness;shape.outer_radius=radius+thickness;shape.rings=20;shape.ring_segments=5
 var node=k.mesh(root if parent==null else parent,shape,at,material);node.quaternion=Quaternion(Vector3.UP,axis.normalized());return node

func elbow(at: Vector3,radius: float,material: Material):
 return k.sphere(root,at,radius,material)

func flange(at: Vector3,axis: Vector3,radius: float):
 stats.flanges+=1;axis=axis.normalized()
 cylinder(at,radius*1.38,.15,m.copper,axis);cylinder(at+axis*.09,radius*1.39,.035,m.dark,axis)
 var side=axis.cross(Vector3.RIGHT if absf(axis.x)<.8 else Vector3.UP).normalized();var vertical=axis.cross(side).normalized()
 for bolt in range(8):
  var angle=bolt*TAU/8;var point=at+(side*cos(angle)+vertical*sin(angle))*radius*1.12
  cylinder(point+axis*.13,.065,.13,m.steel,axis)

func label(at: Vector3,text: String,size=18,parent: Node3D=null):
 var plaque=Node3D.new();(root if parent==null else parent).add_child(plaque);plaque.position=at
 box(Vector3(0,0,-.045),Vector3(maxf(.8,text.length()*size*.006),size*.017,.06),m.dark,plaque)
 var node=k.label(plaque,Vector3(0,0,.005),text,Color("d6d2ae"),size)
 node.visible=true;node.billboard=BaseMaterial3D.BILLBOARD_DISABLED;node.pixel_size=.012;node.modulate=Color("e1dabd");node.no_depth_test=false;node.visibility_range_end=32;return plaque

func gauge(at: Vector3,stage: int,radius=.4):
 cylinder(at,radius,.15,m.copper,Vector3.BACK);cylinder(at+Vector3(0,0,.085),radius*.84,.025,m.paper,Vector3.BACK)
 for mark in range(9):
  var angle=lerpf(-2.35,2.35,mark/8.0);var point=at+Vector3(sin(angle),cos(angle),0)*radius*.68+Vector3(0,0,.105)
  var tick=box(point,Vector3(.023,.085,.015),m.dark);tick.rotation.z=-angle
 var pivot=Node3D.new();pivot.name="PressureGaugeNeedle";root.add_child(pivot);pivot.position=at+Vector3(0,0,.12)
 box(Vector3(0,radius*.27,0),Vector3(.035,radius*.63,.025),m.rust,pivot);cylinder(Vector3.ZERO,.06,.04,m.dark,Vector3.BACK,pivot)
 needles.append({"node":pivot,"stage":stage})

func lamp(at: Vector3,stage: int):
 box(at+Vector3(0,.16,0),Vector3(1.5,.2,.7),m.dark)
 box(at,Vector3(1.2,.12,.43),m.light)
 for x in [-.55,0,.55]:box(at+Vector3(x,-.08,0),Vector3(.045,.12,.5),m.steel)
 var status=box(at+Vector3(.83,0,0),Vector3(.15,.2,.22),w.warning);status.set_meta("keep_mesh",true);indicators.append({"node":status,"stage":stage})

func floodgate(stage: int):
 var pump=Vector3(stage%2*24-12,0,-10)
 box(pump+Vector3(0,.12,0),Vector3(6,.24,5.6),m.worn)
 for x in [-2,2]:
  for z in [-1.8,1.8]:cylinder(pump+Vector3(x,.3,z),.16,.2,m.steel)
 # Motor, shaft, bearing saddles and ventilation fins all attach to the pressure vessel.
 var motor=pump+Vector3(0,1.3,3.4)
 cylinder(motor,1.0,2.4,m.teal,Vector3.FORWARD)
 pipe(pump+Vector3(0,1.3,.7),motor,.32,m.steel)
 for i in range(9):ring(motor+Vector3(0,0,-1.05+i*.25),1.04,.045,m.dark,Vector3.FORWARD)
 for x in [-.7,.7]:
  for z in [-.8,.8]:box(motor+Vector3(x,-.8,z),Vector3(.35,1.0,.45),m.dark)
 cylinder(motor+Vector3(0,0,1.25),.86,.08,m.dark,Vector3.BACK)
 for blade in range(8):
  var angle=blade*TAU/8;pipe(motor+Vector3(0,0,1.31),motor+Vector3(cos(angle)*.8,sin(angle)*.8,1.31),.035,m.steel)
 flange(pump+Vector3(0,4.5,0),Vector3.RIGHT,.65);flange(pump+Vector3(7,4.5,0),Vector3.RIGHT,.65)
 elbow(pump+Vector3(10,4.5,0),.68,m.teal);flange(pump+Vector3(10,1.0,0),Vector3.UP,.65)
 for y in [.6,2.0,3.6]:
  for bolt in range(12):
   var angle=bolt*TAU/12;cylinder(pump+Vector3(cos(angle)*2.41,y,sin(angle)*2.41),.09,.14,m.steel,Vector3(cos(angle),0,sin(angle)))
 # A service gantry and hoist explain how a vessel this large is maintained.
 for side in [-1,1]:
  box(pump+Vector3(side*3.7,3.25,-3.3),Vector3(.35,6.5,.45),m.dark)
  box(pump+Vector3(side*3.7,.12,-3.3),Vector3(1.1,.24,1.2),m.worn)
 box(pump+Vector3(0,6.5,-3.3),Vector3(8.3,.45,.8),m.dark)
 for side in [-1,1]:box(pump+Vector3(0,6.5+side*.22,-3.3),Vector3(8.6,.12,1.1),m.steel)
 box(pump+Vector3(2.4,6.12,-3.3),Vector3(.8,.5,.65),m.copper)
 for strand in [-.12,.12]:pipe(pump+Vector3(2.4+strand,6,-3.3),pump+Vector3(2.4+strand,4.2,-3.3),.035,m.dark)
 ring(pump+Vector3(2.4,4.05,-3.3),.23,.065,m.steel,Vector3.BACK)
 for hose in range(3):ring(pump+Vector3(3.6,.12+ hose*.07,2.8),.6+ hose*.1,.05,m.black)
 for side in [-1,1]:
  for panel in range(4):
   var x=side*(13+panel*12)
   var barrier_z=-26.85 if stage<3 else -36.85
   var barrier_top=7.0+(w.terrace_height(stage+1)-w.terrace_height(stage))*8.0/15.0 if stage<3 else 10.0
   box(Vector3(x,(barrier_top-4)*.5,barrier_z),Vector3(.8,barrier_top+4,.45),m.worn)
   box(Vector3(x,barrier_top-.6,barrier_z+.27),Vector3(2.1,.5,.3),m.copper)
 var control=w.objective_position(stage)-root.position
 gauge(control+Vector3(-.85,2.35,-1.0),stage);gauge(control+Vector3(.85,2.35,-1.0),stage,.3)
 for side in [-1,1]:
  pipe(control+Vector3(side*.85,2.35,-1.1),control+Vector3(side*.85,1.35,-1.1),.055,m.copper)
  pipe(control+Vector3(side*.85,1.35,-1.1),control+Vector3(0,1.35,-1.1),.055,m.copper)
 var valve=w.devices[stage]
 cylinder(Vector3.ZERO,.15,.3,m.dark,Vector3.UP,valve)
 for spoke in range(4):
  var angle=spoke*PI*.5;var arm=box(Vector3(cos(angle)*.37,0,sin(angle)*.37),Vector3(.65,.07,.07),m.gold,valve);arm.rotation.y=-angle
 for side in [-1,1]:
  var material=m.teal if side<0 else m.copper
  var header=Vector3(side*38,9,5)
  pipe(header+Vector3(-6,0,0),header+Vector3(6,0,0),.65,material)
  for offset in [-6,0,6]:
   var inlet=Vector3(side*38+offset,6,-3)
   flange(inlet,Vector3.UP,.6);flange(header+Vector3(offset,0,0),Vector3.RIGHT,.65)
   elbow(header+Vector3(offset,0,0),.66,material)
  var joint=Vector3(side*38,9,-10)
  pipe(header,joint,.65,material);elbow(joint,.67,material)
  pipe(joint,Vector3(pump.x,9,-10),.65,material)
  flange(joint+Vector3(-side*4,0,0),Vector3.RIGHT,.65)
  for z in [-7,5]:
   box(Vector3(side*38,8,z),Vector3(18,.3,.55),m.dark)
   for x in [-8,8]:
    box(Vector3(side*38+x,4,z),Vector3(.3,8,.3),m.dark)
    box(Vector3(side*38+x,.1,z),Vector3(.9,.2,.9),m.worn)
   lamp(Vector3(side*38,7.7,z),stage)
  # Drain grates and sediment reveal flow direction without adding trip hazards.
  box(Vector3(side*23,.026,0),Vector3(1.2,.04,39),m.black)
  for z in range(-19,20):box(Vector3(side*23,.057,z),Vector3(1.2,.055,.1),m.steel)
  for z in [-18,-9,0,9,18]:
   var wall=Vector3(side*51.88,0,z)
   box(wall+Vector3(0,.65,0),Vector3(.08,1.3,6),m.moss)
   for streak in range(5):box(wall+Vector3(-side*.04,1.2+streak*.12,-2.4+streak*1.1),Vector3(.08,1.1+sin(streak*2.3)*.5,.18),m.rust)
  maintenance_panel(Vector3(side*51.5,2.8,-14),side,stage)
 pipe(Vector3(pump.x,9,-10),pump+Vector3(0,4.5,0),.65,m.teal);elbow(Vector3(pump.x,9,-10),.67,m.teal)
 flange(pump+Vector3(0,7.2,0),Vector3.UP,.65)
 label(Vector3(-38,8.45,5.35),"RESIDENTIAL SUPPLY / KEEP PRESSURE",17)
 label(Vector3(38,8.45,5.35),"FREIGHT OVERFLOW / BYPASS",17)
 maintenance_bench(Vector3(-46,0,9),stage)
 lamp(Vector3(-46,3.4,9),stage)
 for z in [7,11]:pipe(Vector3(-46,3.6,z),Vector3(-51.6,3.6,z),.045,m.dark)
 pipe(Vector3(-46,3.6,7),Vector3(-46,3.6,11),.06,m.dark)
 if stage==0:
  for side in [-1,1]:
   var frame=Vector3(side*45,0,-14)
   for z in [-4,4]:box(frame+Vector3(0,1.6,z),Vector3(.28,3.2,.28),m.dark)
   for y in [.25,3.1]:box(frame+Vector3(0,y,0),Vector3(.3,.22,8.4),m.dark)
   for tooth in range(17):box(frame+Vector3(0,1.7,-3.8+tooth*.475),Vector3(.12,2.65,.1),m.steel)
   for debris in range(5):
    var branch=box(frame+Vector3(-side*.25,.22+debris*.06,-2+debris*.7),Vector3(.12,.12,1.4),m.rust);branch.rotation.y=debris*.4
 elif stage==1:
  # The high bypass is braced above the service lane and joins both pressure branches.
  for z in [-8,-6]:
   pipe(Vector3(-22,6.5,z),Vector3(22,6.5,z),.22,m.teal)
   for side in [-1,1]:
    pipe(Vector3(side*22,6.5,z),Vector3(side*22,9,-10),.22,m.teal)
    flange(Vector3(side*18,6.5,z),Vector3.RIGHT,.22)
 elif stage==2:
  for side in [-1,1]:
   var relief_at=Vector3(side*51.4,5,0)
   for y in range(5):
    box(relief_at+Vector3(-side*.1,-2+y,0),Vector3(.12,.09,5),m.gold)
    for z in [-2,2]:cylinder(relief_at+Vector3(-side*.24,-2+y,z),.18,.3,m.paper,Vector3.RIGHT)
 elif stage==3:
  for x in [-5,-2.5,2.5,5]:
   var cabinet=Vector3(x,0,-32)
   box(cabinet+Vector3(0,1.65,0),Vector3(1.8,3.3,.8),m.dark)
   for y in range(8):box(cabinet+Vector3(0,.45+y*.3,.43),Vector3(1.4,.12,.06),m.steel)
   pipe(cabinet+Vector3(0,3.3,0),cabinet+Vector3(0,4,-4.5),.09,m.copper)
   var status=box(cabinet+Vector3(.5,2.95,.48),Vector3(.2,.15,.08),w.warning);status.set_meta("keep_mesh",true);indicators.append({"node":status,"stage":stage})
 for side in [-1,1]:
  # Visible basin surfaces sit inside the existing guarded peripheral beds.
  var water=box(Vector3(side*37,.075,-3),Vector3(21,.035,30),m.water)
  if side>0:water.set_meta("keep_mesh",true);freight_water.append(water)
  else:water.set_meta("keep_mesh",true);residential_water.append(water)
  for z in [-16,-8,0,8]:
   var flow=box(Vector3(side*37,.105,z),Vector3(13,.012,.07),m.steel);flow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   if side>0:flow.set_meta("keep_mesh",true);freight_water.append(flow)

func maintenance_panel(at: Vector3,side: int,stage: int):
 var panel=Node3D.new();root.add_child(panel);panel.position=at;panel.rotation.y=-side*PI*.5
 box(Vector3.ZERO,Vector3(3.2,3.4,.3),m.dark,panel);box(Vector3(0,0,.19),Vector3(2.8,3,.1),m.teal,panel)
 for x in [-1,1]:
  for y in [-1.2,1.2]:cylinder(Vector3(x,y,.28),.075,.08,m.steel,Vector3.BACK,panel)
 for row in range(5):
  box(Vector3(-.45,.9-row*.4,.27),Vector3(1.55,.08,.06),m.black,panel)
  var light=box(Vector3(.75,.9-row*.4,.29),Vector3(.22,.16,.08),w.warning,panel);light.set_meta("keep_mesh",true);indicators.append({"node":light,"stage":stage})
 box(Vector3(.95,-.9,.35),Vector3(.13,.45,.16),m.copper,panel)
 pipe(at+Vector3(-side*.3,-1.7,0),Vector3(at.x-side*.3,.12,at.z),.09,m.dark)

func maintenance_bench(at: Vector3,stage: int):
 box(at+Vector3(0,.09,0),Vector3(3.2,.18,5.8),m.worn)
 box(at+Vector3(0,1.05,0),Vector3(2.4,.18,5),m.steel)
 for x in [-.9,.9]:
  for z in [-2,2]:box(at+Vector3(x,.5,z),Vector3(.15,1,.15),m.dark)
 box(at+Vector3(-.9,2,0),Vector3(.12,1.5,5),m.teal)
 for z in [-1.5,-.7,.1,.9,1.7]:
  pipe(at+Vector3(-.78,2.3,z),at+Vector3(-.78,1.7,z),.035,m.steel)
  ring(at+Vector3(-.78,2.35,z),.1,.035,m.steel,Vector3.RIGHT)
 for item in range(4):cylinder(at+Vector3(.35,1.2,-1.8+item*.32),.1,.18,m.steel)
 ring(at+Vector3(0,1.2,1.2),.45,.08,m.rust)
 box(at+Vector3(.3,1.2,-.3),Vector3(.9,.13,.6),m.dark)
 for x in [-.35,.35]:box(at+Vector3(x,1.25,-.3),Vector3(.08,.18,.62),m.copper)
 var sign=label(at+Vector3(-.75,2.8,0),"MAINTENANCE / BAY "+str(stage+1),15);sign.rotation.y=PI*.5

func archive(stage: int):
 var reader=w.devices[stage]
 reader.position.y=root.position.y+3.8;reader.mesh.inner_radius=1.82;reader.mesh.outer_radius=2.12
 cylinder(Vector3.ZERO,.3,1.5,m.dark,Vector3.UP,reader)
 for spoke in range(8):
  var angle=spoke*TAU/8;var arm=box(Vector3(cos(angle)*1.03,0,sin(angle)*1.03),Vector3(1.65,.12,.12),m.gold,reader);arm.rotation.y=-angle
 # Fluted shafts, stepped capitals and voussoirs make the existing ribs read as architecture.
 for side in [-1,1]:
  for z in [-20,-8,4,16]:
   var base=Vector3(side*43,0,z)
   for level in range(3):box(base+Vector3(0,.14+level*.2,0),Vector3(3.7-level*.25,.25,3.7-level*.25),m.stone)
   for flute in range(12):
    var angle=flute*TAU/12;cylinder(base+Vector3(cos(angle)*1.35,4,sin(angle)*1.35),.14,6.5,m.worn)
   for level in range(3):box(base+Vector3(0,7.45+level*.25,0),Vector3(2.9+level*.45,.3,2.9+level*.45),m.stone)
  for z in [-8.5,8.5]:archive_stack(Vector3(side*48,0,z),side,stage)
  for z in [-17,0,17]:relief(Vector3(side*50.35,4,z),side,stage)
  for z in [-23,22]:
   box(Vector3(side*51.5,3.6,z),Vector3(.9,7.2,1.5),m.worn)
   box(Vector3(side*51.1,7.35,z),Vector3(1.6,.35,2.4),m.stone)
  for y in [.3,7.8,8.3]:box(Vector3(side*51.3,y,0),Vector3(1.3,.25,47),m.stone)
  roots(Vector3(side*49,0,15 if side<0 else -12),side,stage)
  if stage==1:
   var panel=Node3D.new();root.add_child(panel);panel.position=Vector3(side*51.1,9.8,0);panel.rotation.y=-side*PI*.5
   box(Vector3.ZERO,Vector3(16,2.4,.2),m.dark,panel)
   for conductor in range(3):
    box(Vector3(0,-.7+conductor*.7,.2),Vector3(14,.13,.12),m.gold,panel)
    for x in [-6,-3,0,3,6]:
     for disc in range(3):cylinder(Vector3(x,-.7+conductor*.7,.2+disc*.08),.17,.07,m.paper,Vector3.BACK,panel)
   label(Vector3(0,1.08,.2),"LIVING GRID / CONDUCTORS REMAIN IN SERVICE",16,panel)
 for z in [-19,19]:archive_arch(z,stage)
 var control=w.objective_position(stage)-root.position
 box(control+Vector3(0,.25,-1.45),Vector3(3.5,.5,1.6),m.stone)
 for side in [-1,1]:
  box(control+Vector3(side*1.35,1.8,-1.45),Vector3(.42,3.1,.7),m.worn)
  box(control+Vector3(side*1.35,3.4,-1.45),Vector3(.65,.3,.9),m.stone)
 var pivot=Node3D.new();pivot.name="ArchiveAlignmentRotor";root.add_child(pivot);pivot.position=control+Vector3(0,2.6,-1.35)
 ring(Vector3.ZERO,1.14,.12,m.gold,Vector3.BACK,pivot);ring(Vector3.ZERO,.8,.04,m.steel,Vector3.BACK,pivot)
 for spoke in range(6):
  var angle=spoke*TAU/6;var bar=box(Vector3(cos(angle)*.65,sin(angle)*.65,0),Vector3(.9,.08,.1),m.copper,pivot);bar.rotation.z=angle
 cylinder(Vector3.ZERO,.3,.45,m.dark,Vector3.BACK,pivot);rotors.append({"node":pivot,"stage":stage})
 pipe(control+Vector3(-1.3,2.6,-1.55),control+Vector3(1.3,2.6,-1.55),.065,m.dark)
 box(control+Vector3(0,3.85,-1.45),Vector3(3.8,.3,1.0),m.stone)
 label(control+Vector3(0,4.15,-1.25),["DEPARTURE CHRONICLE","LIVING GRID / PROTECTED","RETIRED STOCK / RECLAIMABLE","RESERVE COORDINATES"][stage],17)
 var indicator=box(control+Vector3(0,.83,-.72),Vector3(.7,.09,.09),w.warning);indicator.set_meta("keep_mesh",true);indicators.append({"node":indicator,"stage":stage})
 # Inlaid conduits lead from the reading instrument to the central archive circuit.
 for offset in [-.2,.2]:
  pipe(control+Vector3(offset,.05,-1.4),Vector3(control.x,.05,-18+offset),.04,m.copper)
  pipe(Vector3(control.x,.05,-18+offset),Vector3(0,.05,-18+offset),.04,m.copper)
 for side in [-1,1]:
  var rubble=Vector3(side*49,.12,22)
  for piece in range(5):
   var slab=box(rubble+Vector3(-side*(piece%2)*1.2,.1+piece*.06,-piece*.7),Vector3(1.5,.25,.85),m.worn);slab.rotation=Vector3(.12*piece,.3*piece,.08)
 if stage in [1,2]:
  var evidence=w.locations["evidence"+str(stage-1)]-root.position
  for side in [-1,1]:
   box(evidence+Vector3(side*1.45,1.6,-.8),Vector3(.35,3.2,.6),m.worn)
   box(evidence+Vector3(side*1.45,.2,-.8),Vector3(.7,.4,.9),m.stone)
   var page=box(evidence+Vector3(side*.32,1.57,-.05),Vector3(.62,.065,.72),m.paper);page.rotation.z=side*.10
   for line in range(5):box(evidence+Vector3(side*.32,1.64+side*.03,-.3+line*.12),Vector3(.43,.015,.022),m.copper)
  box(evidence+Vector3(0,3.28,-.8),Vector3(3.7,.3,.9),m.stone)
  lamp(evidence+Vector3(0,3.02,-.65),stage)
 if stage==3:
  # The destination map is physically inset into the rear wall, not a floating seal.
  var map_at=Vector3(0,5,-36.75)
  box(map_at+Vector3(0,0,-.15),Vector3(10,8,.22),m.worn)
  cylinder(map_at,3.2,.16,m.dark,Vector3.BACK)
  ring(map_at+Vector3(0,0,.12),3.05,.09,m.gold,Vector3.BACK)
  for n in range(4):
   var angle=n*PI*.5;var site=map_at+Vector3(cos(angle)*2.25,sin(angle)*2.25,.2)
   ring(site,.45,.07,m.gold,Vector3.BACK)
   var line=box(map_at+Vector3(cos(angle)*1.0,sin(angle)*1.0,.2),Vector3(1.5,.07,.08),m.gold);line.rotation.z=angle
  cylinder(map_at+Vector3(0,0,.23),.5,.12,w.active_material,Vector3.BACK)
  label(map_at+Vector3(0,4.25,.05),"RECLAMATION / ACTIVE GRID PROTECTED",20)

func archive_stack(at: Vector3,side: int,stage: int):
 var shelf=Node3D.new();root.add_child(shelf);shelf.position=at;shelf.rotation.y=-side*PI*.5
 box(Vector3(0,2.4,0),Vector3(7,4.8,.4),m.worn,shelf)
 for x in [-3.5,3.5]:box(Vector3(x,2.5,.7),Vector3(.3,5,1.5),m.stone,shelf)
 for level in range(5):
  var y=.25+level*1.05;box(Vector3(0,y,.7),Vector3(7.1,.18,1.55),m.stone,shelf);box(Vector3(0,y+.12,1.4),Vector3(6.8,.06,.07),m.copper,shelf)
  if level==4:continue
  stats.shelves+=1
  for item in range(12):
   if posmod(item+level+stage,9)==0:continue
   var x=-3.0+item*.55;var height=.57+posmod(item*3+level,4)*.08
   box(Vector3(x,y+.14+height*.5,.84),Vector3(.35,height,.87),[m.paper,m.slate,m.rust][posmod(item+level,3)],shelf)
   box(Vector3(x,y+.33,1.29),Vector3(.2,.035,.025),m.copper,shelf);stats.tablets+=1
 box(Vector3(0,5.08,.6),Vector3(7.8,.3,2.0),m.stone,shelf)
 label(Vector3(0,4.75,1.48),["DEPARTURES / SETTLEMENT","WATER / CARE / HABITAT","CONDUCTOR SERVICE / RETIRED","CUSTODIAL AUTHORIZATIONS"][stage],14,shelf)

func relief(at: Vector3,side: int,stage: int):
 stats.relief_panels+=1
 var panel=Node3D.new();root.add_child(panel);panel.position=at;panel.rotation.y=-side*PI*.5
 box(Vector3.ZERO,Vector3(9,5.6,.18),m.paper,panel)
 for x in [-4.5,4.5]:box(Vector3(x,0,.17),Vector3(.17,5.7,.18),m.copper,panel)
 for y in [-2.8,2.8]:box(Vector3(0,y,.17),Vector3(9.1,.17,.18),m.copper,panel)
 for row in range(3):
  for mark in range(17):
   var x=-4.0+mark*.49;var y=-2.1+row*.33
   box(Vector3(x,y,.15),Vector3(.25,.035,.06),m.rust,panel)
   if (mark+row+stage)%3==0:box(Vector3(x-.07,y+.08,.15),Vector3(.035,.16,.06),m.rust,panel)
 if stage==0:
  # A departure vessel above a settled skyline, with no new person depicted.
  for tower in range(9):box(Vector3(-3.4+tower*.8,-.65+absf(sin(tower*1.7))*.4,.18),Vector3(.45,.4+absf(sin(tower*1.7))*.8,.22),m.worn,panel)
  var hull=box(Vector3(0,1.25,.25),Vector3(3.4,.4,.3),m.copper,panel);hull.rotation.z=-.12
  for wing in [-1,1]:var plate=box(Vector3(wing*.7,.92,.24),Vector3(.3,1.1,.25),m.copper,panel);plate.rotation.z=wing*.7
  for star in range(9):cylinder(Vector3(-3.7+star*.9,1.7+sin(star*2)*.6,.21),.055,.07,m.copper,Vector3.BACK,panel)
 elif stage==1:
  for x in [-2.7,0,2.7]:
   box(Vector3(x,.65,.2),Vector3(1.4,1.8,.2),m.worn,panel)
   box(Vector3(x,1.0,.35),Vector3(.85,.2,.08),m.copper,panel);box(Vector3(x,1.0,.35),Vector3(.2,.85,.08),m.copper,panel)
  box(Vector3(0,-.65,.28),Vector3(7.4,.08,.08),m.copper,panel)
  for x in [-2.7,0,2.7]:box(Vector3(x,-.25,.28),Vector3(.08,.9,.08),m.copper,panel)
 elif stage==2:
  for column in range(5):
   for row in range(3):box(Vector3(-3+column*1.5,-.6+row*.7,.25),Vector3(1.15,.36,.22),m.copper if column<3 else m.slate,panel)
 else:
  for mark in range(5):
   var at_mark=Vector3(-3.2+mark*1.6,.5+sin(mark*1.5)*.8,.25)
   ring(at_mark,.24,.05,m.copper,Vector3.BACK,panel)
   if mark<4:var segment=box(at_mark+Vector3(.75,.05,0),Vector3(1.1,.07,.08),m.copper,panel);segment.rotation.z=.2*cos(mark)

func archive_arch(z: float,stage: int):
 stats.arches+=1
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Separate stones leave a fine mortar gap, with every spring anchored on a capital.
 for part in range(30):
  var a=part*PI/30+.0005;var b=(part+1)*PI/30-.0005
  var corners=[]
  for depth in [-.75,.75]:
   for angle in [a,b]:
    corners.append(Vector3(cos(angle)*42.8,8.1+sin(angle)*10.8,z+depth))
    corners.append(Vector3(cos(angle)*43.5,8.1+sin(angle)*11.7,z+depth))
  for indices in [[0,2,1],[1,2,3],[4,5,6],[5,7,6],[0,1,4],[1,5,4],[2,6,3],[3,6,7],[0,4,2],[2,4,6],[1,3,5],[3,7,5]]:
   var normal=(corners[indices[1]]-corners[indices[0]]).cross(corners[indices[2]]-corners[indices[0]]).normalized()
   for index in [indices[0],indices[2],indices[1]]:tool.set_normal(normal);tool.set_uv(Vector2(corners[index].x,corners[index].y)*.25);tool.add_vertex(corners[index])
 var arch=k.mesh(root,tool.commit(),Vector3.ZERO,m.arch);arch.name="ArchiveStoneVoussoirs";arch.set_meta("keep_mesh",true)
 box(Vector3(0,19.4,z),Vector3(1.9,2.0,2.1),m.worn)
 box(Vector3(0,19.3,z+.83),Vector3(.65,1.0,.5),m.copper)
 if stage==1 and z>0:lamp(Vector3(0,18.3,z),stage)

func roots(at: Vector3,side: int,stage: int):
 for strand in range(5):
  var previous=at+Vector3(0,.35,0)
  for point in range(1,7):
   var next=at+Vector3(-side*(point*.55+sin(point+strand)*.4),.10+absf(sin(point*1.3+strand))*.13,(strand-2)*point*.75)
   pipe(previous,next,.19-point*.022,m.rust);previous=next
  var moss=box(previous+Vector3(0,-.025,0),Vector3(1.7,.08,2.1),m.moss);moss.rotation.y=strand*.6
 for strand in range(3):
  var previous=at+Vector3(side*2.4,.2,strand)
  for point in range(1,7):
   var next=at+Vector3(side*2.4,point*1.2,strand+sin(point*1.7+stage)*.35)
   pipe(previous,next,.13,m.rust);previous=next
   for leaf in range(3):
    var foliage=k.mesh(root,k.leaf_mesh,next+Vector3(-side*.15,(leaf-1)*.24,(leaf-1)*.18),m.leaf)
    foliage.scale=Vector3(.85,1,1.2);foliage.rotation=Vector3(.45+leaf*.2,leaf*2.1+point,side*PI*.35)
