class_name NestCampaignFoundryRailDetails
extends RefCounted
# Equipment dressing follows the existing machine footprints and raised service
# decks. The sixteen-metre transit route, consoles and cache approaches stay open.
static func build(w):
 if w.mission_index not in [5,6]:return
 var steel=w.detail_surface(Color("394448"),Color("202a31"),.7)
 var ceramic=w.detail_surface(Color("b9b6a3"),Color("777d73"),.3)
 var rust=w.detail_surface(Color("886044"),Color("503f34"),.35)
 var charcoal=w.detail_surface(Color("353330"),Color("222629"),.15)
 var glass=w.kit.material(Color("274f59"),.65);glass.roughness=.2
 var materials={"steel":steel,"ceramic":ceramic,"rust":rust,"charcoal":charcoal,"glass":glass}
 if w.mission_index==5:foundry(w,materials)
 else:rail(w,materials)

static func bolt_face(w,p: Vector3,radius: float,count: int,mat: Material):
 for i in range(count):
  var a=i*TAU/count
  var bolt=w.tube(p+Vector3(cos(a)*radius,sin(a)*radius,0),.075,.12,mat);bolt.rotation.x=PI*.5

static func dial(w,p: Vector3,mat: Material,angle: float):
 var bezel=w.tube(p,.27,.12,mat);bezel.rotation.x=PI*.5
 var face=w.tube(p+Vector3(0,0,.07),.22,.018,w.palette.hull);face.rotation.x=PI*.5
 for i in range(7):
  var a=-2.3+i*.55
  w.pipe(p+Vector3(sin(a)*.16,cos(a)*.16,.09),p+Vector3(sin(a)*.2,cos(a)*.2,.09),.012,w.kit.dark)
 w.pipe(p+Vector3(0,0,.105),p+Vector3(sin(angle)*.17,cos(angle)*.17,.105),.018,w.warning)

static func hatch(w,p: Vector3,size: Vector2,mat: Material):
 w.block(p,Vector3(size.x,size.y,.12),mat,false)
 for x in [-1,1]:
  for y in [-1,1]:
   var bolt=w.tube(p+Vector3(x*(size.x*.5-.16),y*(size.y*.5-.16),.09),.07,.08,w.copper);bolt.rotation.x=PI*.5
 w.pipe(p+Vector3(.25,-.18,.14),p+Vector3(.25,.18,.14),.045,w.copper)

static func floor_hatch(w,p: Vector3,width: float,length: float,mat: Material):
 w.block(p+Vector3.UP*.025,Vector3(width,.035,length),mat,false)
 for side in [-1,1]:w.block(p+Vector3(side*(width*.5-.08),.05,0),Vector3(.05,.025,length-.12),w.copper,false)
 for i in range(6):w.block(p+Vector3(0,.05,-length*.42+i*length*.168),Vector3(width-.25,.022,.035),w.kit.dark,false)

static func tool_station(w,p: Vector3,m: Dictionary,stage: int):
 # Edge-mounted work bay, clear of the cache in the middle of the service deck.
 w.block(p+Vector3(0,.88,0),Vector3(2.5,.16,.85),m.steel,false)
 for x in [-1,1]:w.block(p+Vector3(x,.4,0),Vector3(.14,.8,.7),m.steel,false)
 w.block(p+Vector3(0,1.7,-.4),Vector3(2.5,1.4,.08),m.ceramic,false)
 for x in [-.85,-.42,0,.42,.85]:
  w.pipe(p+Vector3(x,1.25,-.32),p+Vector3(x,1.95,-.32),.04,w.copper)
  var jaw=w.ring(p+Vector3(x,2,-.32),.11,.035,m.steel);jaw.rotation.x=PI*.5
 w.block(p+Vector3(-.6,1.03,0),Vector3(.7,.14,.42),w.teal,false)
 for i in range(3):w.block(p+Vector3(.3+i*.2,1.02,.08),Vector3(.09,.12,.3),w.kit.gold,false)
 w.narrative_lamp(p+Vector3(.95,2.2,-.3),Vector3(.16,.11,.08),stage)

static func foundry(w,m: Dictionary):
 var furnace_glow=w.kit.material(Color("ce7840"),.25)
 furnace_glow.emission_enabled=true;furnace_glow.emission=Color("ff953f");furnace_glow.emission_energy_multiplier=.55
 w.set_meta("foundry_heat_ports",[]);w.set_meta("foundry_heat_material",furnace_glow)
 for stage in range(4):
  var p=w.stage_center(stage)
  for side in [-1,1]:
   # Refractory inspection doors, bolted bands and a continuous extraction trunk.
   for index in range(3):
    var base=p+Vector3(side*(26+index*9),0,-10)
    for y in [.6,2.1,4.7]:w.ring(base+Vector3(0,y,0),3.15,.1,m.steel)
    var port=base+Vector3(0,2.55,3.14)
    var backing=w.tube(port,.93,.2,m.steel);backing.rotation.x=PI*.5
    var lining=w.ring(port+Vector3(0,0,.13),.71,.16,m.ceramic);lining.rotation.x=PI*.5
    var aperture=w.tube(port+Vector3(0,0,.15),.56,.03,furnace_glow);aperture.rotation.x=PI*.5
    aperture.set_meta("keep_mesh",true)
    w.get_meta("foundry_heat_ports").append({"node":aperture,"stage":stage})
    bolt_face(w,port+Vector3(0,0,.25),.86,8,w.copper)
    for x in [-.3,0,.3]:w.pipe(port+Vector3(x,-.48,.22),port+Vector3(x,.48,.22),.045,m.steel)
    hatch(w,base+Vector3(0,.8,3.15),Vector2(1.7,.7),m.rust)
    dial(w,base+Vector3(1.42,3.25,2.83),m.ceramic,-.5+stage*.42)
    w.pipe(base+Vector3(1.42,3,2.8),base+Vector3(1.42,1.3,2.8),.055,w.copper)
    for y in [7,10.8,13.2]:w.ring(base+Vector3(0,y,0),1.16,.09,m.steel)
    w.pipe(base+Vector3(0,12.8,0),base+Vector3(0,14.4,0),.65,m.rust)
    w.pipe(base+Vector3(0,14.4,0),p+Vector3(side*49,14.4,-10),.65,m.rust)
    for z in [-.8,.8]:w.pipe(base+Vector3(-.85,13.2,z),base+Vector3(.85,13.2,z),.07,m.steel)
   # Coolant is visibly connected to each furnace rather than terminating in space.
   w.pipe(p+Vector3(side*24,6.4,-10),p+Vector3(side*49,6.4,-10),.32,w.teal)
   w.pipe(p+Vector3(side*49,6.4,-10),p+Vector3(side*49,.65,-10),.32,w.teal)
   w.pipe(p+Vector3(side*49,.65,-10),p+Vector3(side*49,.65,6),.32,w.teal)
   for x in [26,35,44]:
    w.pipe(p+Vector3(side*x,6.4,-10),p+Vector3(side*x,5.4,-10),.22,w.teal)
    for y in [5.9,6.25]:w.ring(p+Vector3(side*x,y,-10),.29,.06,w.copper)
   var pump=p+Vector3(side*48,1.35,7)
   w.block(pump,Vector3(3.3,2.7,3),m.steel,false)
   for vent in range(7):w.block(pump+Vector3(0,-.85+vent*.28,1.53),Vector3(2.6,.11,.05),m.charcoal,false)
   dial(w,pump+Vector3(.7,.95,1.58),m.ceramic,1.2)
   w.narrative_lamp(pump+Vector3(-.9,.95,1.6),Vector3(.28,.17,.08),0)
   var fan=Node3D.new();w.scene_root.add_child(fan);fan.position=pump+Vector3.UP*1.48
   w.ring(fan.position,1.15,.09,m.steel)
   for blade in range(4):
    var angle=blade*PI*.5;var paddle=w.kit.box(fan,Vector3(cos(angle)*.54,0,sin(angle)*.54),Vector3(.92,.08,.28),w.copper);paddle.rotation.y=-angle
   NestRigidBatch.build(fan);w.narrative_rotors.append({"node":fan,"stage":0,"speed":1.5})
   conveyor(w,p+Vector3(side*13,0,2),m,stage,side)
   # Narrow service marks sit on the existing floor around the conveyor footing.
   for edge in [-3.5,3.5]:
    w.block(p+Vector3(side*13+edge,.027,2),Vector3(.12,.035,17.5),w.warning,false)
    for z in range(-6,11,2):
     var stripe=w.block(p+Vector3(side*13+edge,.048,z),Vector3(.16,.025,.5),m.charcoal,false);stripe.rotation.y=.35
  # Crane trolley, cable reel, spreader and hook remain well above standing height.
  var crane=p+Vector3(-6+stage*4,10.15,0)
  w.block(crane,Vector3(5.2,1.05,3.2),w.teal,false)
  for z in [-1.8,1.8]:
   w.pipe(p+Vector3(-48,10.55,z),p+Vector3(48,10.55,z),.13,w.copper)
   for x in [-2,2]:
    var wheel=w.tube(crane+Vector3(x,.05,z),.32,.28,m.steel);wheel.rotation.x=PI*.5
  var drum=w.tube(crane+Vector3(0,-.8,0),.52,3.2,m.steel);drum.rotation.z=PI*.5
  for x in [-1.2,1.2]:
   w.pipe(crane+Vector3(x,-.8,0),crane+Vector3(x,-3.7,0),.045,w.copper)
   w.ring(crane+Vector3(x,-.8,0),.55,.08,w.copper).rotation.z=PI*.5
  w.block(crane+Vector3(0,-3.7,0),Vector3(3.4,.4,.6),w.warning,false)
  var hook=w.ring(crane+Vector3(0,-4.25,0),.42,.12,m.steel);hook.rotation.x=PI*.5
  for x in range(-44,45,6):
   w.pipe(p+Vector3(x,10.5,.85),p+Vector3(x+3,11.6,.85),.09,w.copper)
   w.pipe(p+Vector3(x+3,11.6,.85),p+Vector3(x+6,10.5,.85),.09,w.copper)
  var deck: Vector3=w.raised_cache_sites[stage]
  tool_station(w,deck+Vector3(4.8,0,-3.1),m,stage)
  var panel=deck+Vector3(-4.6,.9,-3.5)
  w.block(panel,Vector3(2.5,1.8,.75),m.ceramic,false)
  w.block(panel+Vector3(0,.3,.4),Vector3(1.8,.65,.04),m.glass,false)
  for j in range(4):w.narrative_lamp(panel+Vector3(-.75+j*.5,-.45,.42),Vector3(.16,.12,.06),stage)
  w.sign_at(panel+Vector3(0,1.35,.45),"CRANE / "+str(stage+1)+"\nRECLAIMED STOCK",Color("f0cf9b"),13)
  # Inventory is attached to the same belts and crates the story transfers.
  w.sign_at(p+Vector3(13,3.5,11.2),["SCRAP IN / LIVE CONDUCTORS EXCLUDED","SEPARATE / GOLD-BEARING CONTACTS","CAST / RETIRED STOCK","SEALED / CONNECTUCT FREIGHT"][stage],Color("e4c69a"),16)
  for side in [-1,1]:floor_hatch(w,p+Vector3(side*43,0,18),4,2.5,m.steel)
 w.set_meta("industrial_details",{"mission":5,"inspection_ports":24,"coolant_manifolds":8,"detailed_conveyors":8,"ingot_molds":40,"cranes":4,"control_bays":4,"tool_racks":4,"cooling_fans":8})

static func conveyor(w,base: Vector3,m: Dictionary,stage: int,side: int):
 for x in [-3.05,3.05]:
  w.block(base+Vector3(x,1.92,0),Vector3(.13,.3,16.1),m.steel,false)
  for z in [-6,0,6]:w.block(base+Vector3(x,.8,z),Vector3(.16,1.6,.25),m.rust,false)
 for z in [-7.1,7.1]:
  var drum=w.tube(base+Vector3(0,1.55,z),.35,5.95,m.steel);drum.rotation.z=PI*.5
  for x in [-3.2,3.2]:w.ring(base+Vector3(x,1.55,z),.4,.09,w.copper).rotation.z=PI*.5
 var drive=base+Vector3(side*3.45,1.1,6.3)
 w.block(drive,Vector3(.7,1.2,1.7),w.teal,false)
 for z in [-.6,-.3,0,.3,.6]:w.block(drive+Vector3(side*.39,0,z),Vector3(.06,.85,.06),m.charcoal,false)
 w.pipe(drive+Vector3(0,-.35,.9),base+Vector3(side*3.45,.55,8.3),.08,w.copper)
 for j in range(5):
  var item=base+Vector3(-1.6+j%2*2.7,2.04,-5+j*2.5)
  w.block(item,Vector3(1.55,.11,1.03),m.charcoal,false)
  for x in [-.72,.72]:w.block(item+Vector3(x,.14,0),Vector3(.1,.28,1.0),m.steel,false)
  for z in [-.46,.46]:w.block(item+Vector3(0,.14,z),Vector3(1.5,.28,.08),m.steel,false)
  if stage<2:
   for n in range(3):
    var strip=w.block(item+Vector3(-.42+n*.4,.28,0),Vector3(.13,.09,.73),w.copper,false);strip.rotation.y=-.3+n*.4
  elif stage==3:
   w.block(item+Vector3(0,.45,0),Vector3(1.4,.15,.95),w.teal,false)
   for x in [-.5,.5]:w.block(item+Vector3(x,.46,0),Vector3(.1,.18,1.0),w.copper,false)

static func rail(w,m: Dictionary):
 # Ballast and sleeper hardware follow both descending and ascending trackbeds.
 var rng=RandomNumberGenerator.new();rng.seed=626026
 var stones=0
 for z in range(-195,41,2):
  for j in range(9):
   var p=Vector3(rng.randf_range(-7.5,7.5),0,z+rng.randf_range(-.65,.65));p.y=w.surface_height(p)
   if p.y< -500:continue
   var stone=w.block(p+Vector3.UP*.035,Vector3(rng.randf_range(.12,.35),.06,rng.randf_range(.1,.32)),m.charcoal,false)
   stone.rotation.y=rng.randf()*PI;stones+=1
  if posmod(z+195,4)==0:
   for x in [-6,6]:
    var p=Vector3(x,0,z);p.y=w.surface_height(p)
    w.block(p+Vector3(0,.105,0),Vector3(.62,.09,.64),m.steel,false)
    for edge in [-.23,.23]:w.tube(p+Vector3(edge,.17,.15),.065,.1,w.copper)
 for stage in range(4):
  var p=w.stage_center(stage)
  switch_linkage(w,p,m,stage)
  wagon(w,p+Vector3(35,0,-2),m,stage)
  var deck: Vector3=w.raised_cache_sites[stage]
  signal_cabin(w,deck+Vector3(-4.9,0,-1.1),m,stage)
  # Side treads articulate the existing ramp; its tested central walking surface remains smooth.
  var a=p+Vector3(-12,0,0);var b=p+Vector3(-29,3.2,0)
  for j in range(15):
   var at=a.lerp(b,j/14.0)
   for side in [-1,1]:w.block(at+Vector3(0,-.08,side*4.35),Vector3(.9,.18,.44),m.steel,false)
  for side in [-1,1]:
   var mast=p+Vector3(side*19,10,0)
   for x in [-3,0,3]:
    var insulator=mast+Vector3(x,.4,0)
    w.pipe(insulator-Vector3.UP*.3,insulator+Vector3.UP*.65,.07,m.steel)
    for y in [0,.15,.3,.45]:w.tube(insulator+Vector3.UP*y,.21,.09,m.ceramic)
   var signal_at=p+Vector3(side*7,8.5,.45)
   w.block(signal_at,Vector3(1.1,2.8,.42),m.steel,false)
   for row in range(3):
    var lens=w.tube(signal_at+Vector3(0,-.86+row*.86,.26),.28,.08,w.active_material if row==0 else w.warning);lens.rotation.x=PI*.5
    lens.set_meta("keep_mesh",true);w.narrative_indicators.append({"node":lens,"stage":stage})
    w.block(signal_at+Vector3(0,-.54+row*.86,.39),Vector3(.7,.1,.65),m.steel,false)
   for z in [-17,17]:
    var cabinet=p+Vector3(side*49,1.1,z)
    w.block(cabinet,Vector3(2.4,2.2,1.6),m.ceramic,false)
    hatch(w,cabinet+Vector3(0,0,.85),Vector2(1.9,1.8),m.steel)
    w.narrative_lamp(cabinet+Vector3(-.6,.65,.95),Vector3(.25,.13,.06),stage)
    w.pipe(cabinet+Vector3(side*.7,-.9,0),p+Vector3(side*49,.2,0),.075,m.steel)
   # Local freight is already strapped to the authored wagon and crate stacks.
   for j in range(3):
    var cargo=p+Vector3(side*(29+j*8),0,16)
    for x in [-.65,.65]:w.block(cargo+Vector3(x,1.6,0),Vector3(.1,.09,1.7),w.copper,false)
    var eye=w.ring(cargo+Vector3(0,.12,1.2),.18,.05,m.steel);eye.rotation.x=PI*.5
    w.pipe(cargo+Vector3(-.65,1.6,0),cargo+Vector3(0,.12,1.2),.035,m.steel)
   # Catenary spans match terrace elevations, with visible sag and insulator terminations.
   if stage<3:
    var from=p+Vector3(side*19,10.95,0);var to=w.stage_center(stage+1)+Vector3(side*19,10.95,0)
    for strand in [-1,1]:
     var last=from+Vector3(strand*.42,0,0)
     for segment in range(1,17):
      var u=segment/16.0;var point=from.lerp(to,u)+Vector3(strand*.42,-sin(u*PI)*1.5,0)
      w.pipe(last,point,.035,m.steel);last=point
   for z in [-11,8]:floor_hatch(w,p+Vector3(side*10,0,z),1.4,2.1,m.steel)
  for marker in range(5):
   var paint=w.block(p+Vector3(8,.028,-16+marker*8),Vector3(.3,.035,1.9),w.warning,false);paint.rotation.y=-.18
  w.sign_at(p+Vector3(10,1.2,18),"FREIGHT ONLY\nPASSENGER BRANCH ISOLATED",Color("b9d1d6"),14)
 w.set_meta("industrial_details",{"mission":6,"ballast_stones":stones,"switch_linkages":4,"signal_cabins":4,"detailed_wagons":4,"catenary_spans":12,"live_signal_heads":8})

static func switch_linkage(w,p: Vector3,m: Dictionary,stage: int):
 var motor=p+Vector3(9,.25,-12)
 w.block(motor,Vector3(1.3,.5,2.3),m.steel,false)
 for j in range(5):w.block(motor+Vector3(0,.28,-.85+j*.42),Vector3(1.1,.045,.08),w.copper,false)
 w.pipe(motor+Vector3(-.5,-.08,0),p+Vector3(-6,.17,-12),.06,w.copper)
 for x in [-6,6]:
  w.block(p+Vector3(x,.16,-12),Vector3(.45,.15,2.9),m.steel,false)
  for z in [-13,-11]:w.tube(p+Vector3(x,.28,z),.11,.08,w.copper)
  var blade=w.block(p+Vector3(x-.18,.21,-9),Vector3(.11,.14,8),w.copper,false)
  blade.set_meta("keep_mesh",true);w.narrative_panels.append({"node":blade,"stage":stage,"closed":blade.position,"offset":Vector3(.28,0,0)})
 w.narrative_lamp(motor+Vector3(0,.31,.78),Vector3(.45,.05,.22),stage)

static func wagon(w,p: Vector3,m: Dictionary,stage: int):
 for z in [-4,4]:
  w.pipe(p+Vector3(-4.85,.7,z),p+Vector3(4.85,.7,z),.16,m.steel)
  for side in [-1,1]:
   var hub=w.tube(p+Vector3(side*5.04,.7,z),.28,.11,w.copper);hub.rotation.z=PI*.5
   for y in [.48,.64,.8,.96]:w.pipe(p+Vector3(side*4.45,y,z-.9),p+Vector3(side*4.45,y,z+.9),.055,m.steel)
   w.pipe(p+Vector3(side*4.6,1.3,z-1),p+Vector3(side*4.6,.85,z+1),.11,m.rust)
 for side in [-1,1]:
  for z in [-5,0,5]:
   w.block(p+Vector3(side*4.34,3.2,z),Vector3(.14,2.55,.2),m.rust,false)
   var eye=w.ring(p+Vector3(side*4.58,2.15,z),.2,.055,w.copper);eye.rotation.z=PI*.5
  w.pipe(p+Vector3(side*4.62,1.35,-5.8),p+Vector3(side*4.62,1.35,5.8),.065,m.steel)
  for y in [2.2,4.1]:w.block(p+Vector3(side*4.38,y,0),Vector3(.11,.12,12),m.ceramic,false)
 for z in [-7.1,7.1]:
  w.block(p+Vector3(0,1.1,z),Vector3(1.4,.6,1.3),m.steel,false)
  for x in [-2.8,2.8]:
   w.pipe(p+Vector3(x,1.2,z*.88),p+Vector3(x,1.2,z*1.05),.15,m.steel)
   var buffer=w.tube(p+Vector3(x,1.2,z*1.06),.36,.14,m.rust);buffer.rotation.x=PI*.5
  var previous=p+Vector3(-.9,.9,z*.92)
  for n in range(1,9):
   var u=n/8.0;var point=p+Vector3(-.9+u*.8,.9-sin(u*PI)*.55,z*.92+sin(u*PI)*.4)
   w.pipe(previous,point,.055,m.charcoal);previous=point
 w.block(p+Vector3(-4.42,3.3,2),Vector3(.08,1.0,2.1),m.ceramic,false)
 var plaque=w.sign_at(p+Vector3(-4.5,3.35,2),"R-0"+str(stage+1)+"\nRECLAIMED",Color("8eacaa"),12);plaque.rotation.y=-PI*.5
 for z in [-4.7,4.7]:w.block(p+Vector3(0,4.48,z),Vector3(8.8,.12,.16),w.copper,false)

static func signal_cabin(w,p: Vector3,m: Dictionary,stage: int):
 # The small enclosed booth occupies only the far edge of an existing side deck.
 w.block(p+Vector3(0,.9,0),Vector3(3.2,1.8,3.3),m.ceramic,true)
 w.block(p+Vector3(0,2.35,0),Vector3(3.5,.2,3.6),m.steel,false)
 for x in [-1.48,1.48]:
  for z in [-1.5,1.5]:w.block(p+Vector3(x,2.05,z),Vector3(.16,.6,.16),m.steel,false)
 for z in [-1.57,1.57]:w.block(p+Vector3(0,2.05,z),Vector3(2.8,.5,.06),m.glass,false)
 for x in [-1.55,1.55]:w.block(p+Vector3(x,2.05,0),Vector3(.06,.5,2.8),m.glass,false)
 w.pipe(p+Vector3(1.6,1.1,1.1),p+Vector3(1.6,.1,1.1),.06,w.copper)
 for j in range(4):w.narrative_lamp(p+Vector3(-1.0+j*.65,1.48,1.7),Vector3(.2,.12,.08),stage)
 w.sign_at(p+Vector3(0,2.48,1.6),"SIGNAL "+str(stage+1)+" / QUARANTINE",Color("c6d5cc"),13)
 w.tube(p+Vector3(0,4.2,0),.06,1.6,w.copper)
 for y in [3.65,3.85]:w.ring(p+Vector3(0,y,0),.22,.045,m.ceramic)

static func update_stage(w,stage: int):
 if w.mission_index!=5:return
 for port in w.get_meta("foundry_heat_ports",[]):
  port.node.material_override=w.get_meta("foundry_heat_material") if int(port.stage)<stage else w.kit.dark
