class_name NestCampaignMotorcycleWorld
extends RefCounted
# The entire road is deterministic. Physics remains present outside render range.
const ROAD_LENGTH=7900.0
const SECTORS=6
const SECTOR_LENGTH=ROAD_LENGTH/SECTORS
const ROAD_WIDTH=22.0
const SECTOR_NAMES=["WRECK RUN","ROOT SLALOM","BROKEN VIADUCT","FLOODED CUT","ASH RIDGE","FLOODGATE APPROACH"]
static func center_x(distance: float) -> float:
 return sin(distance*.003)*14.0+sin(distance*.009)*5.0
static func point(distance: float,side=0.0) -> Vector3:
 return Vector3(center_x(distance)+side,0,-distance)
static func heading(distance: float) -> float:
 var direction=point(distance+2)-point(distance)
 return atan2(-direction.x,-direction.z)
static func spawn(stage: int,slot: int) -> Vector3:
 var distance=clampi(stage,0,5)*SECTOR_LENGTH+8
 return point(distance,(slot-2.5)*3.0)+Vector3.UP*.25
static func encounter_spawns(stage: int) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 for index in range(8):
  var distance=clampi(stage,0,5)*SECTOR_LENGTH+110+index*150
  result.append(point(distance,(-1 if index%2==0 else 1)*(12.8+index%3)))
 return result
static func supported(at: Vector3) -> bool:
 return at.z<40 and at.z> -ROAD_LENGTH-90 and absf(at.x)<75
static func route(start: Vector3,finish: Vector3) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 if start.distance_to(finish)<60:result.append(finish);return result
 var from=clampf(-start.z,0,ROAD_LENGTH);var to=clampf(-finish.z,0,ROAD_LENGTH)
 var direction=1 if to>from else -1
 var distance=from+direction*24
 while absf(distance-from)<absf(to-from):
  result.append(point(distance));distance+=direction*24
 result.append(finish);return result
static func ramp_info(distance: float) -> Dictionary:
 var index=floori((distance-180)/240)
 if index<0:return {}
 var start=180.0+index*240.0
 if distance<start or distance>start+13:return {}
 return {"start":start,"x":center_x(start)+(-3.6 if index%2==0 else 3.6),"width":7.4,"crest":start+11.6}
static func build_world(w):
 w.ambience.fog_density=.0022;w.ambience.fog_light_color=Color("728777")
 var ground=w.kit.material(Color("35443a"));var road=w.kit.material(Color("8b7353"));var gravel=w.kit.material(Color("a39b7d"));var bark=w.palette.bark;var leaf=w.palette.leaf
 w.kit.box(w.scene_root,Vector3(0,-.5,-ROAD_LENGTH*.5),Vector3(150,1,ROAD_LENGTH+180),ground,true)
 w.floor_surfaces.assign([{"pos":Vector3(0,0,-ROAD_LENGTH*.5),"size":Vector2(150,ROAD_LENGTH+180)}]);w.bounds=Vector2(75,ROAD_LENGTH+100)
 w.set_meta("bike_road_length",ROAD_LENGTH)
 var rng=RandomNumberGenerator.new();rng.seed=2026102602
 var chunks=[]
 for section in range(80):
  var chunk=Node3D.new();chunk.name="CanopySector_%02d"%section;w.scene_root.add_child(chunk);chunks.append(chunk)
  var d=section*100.0+40
  w.kit.box(chunk,point(d)+Vector3(0,.012,0),Vector3(ROAD_WIDTH,.024,104),road)
  for side in [-1,1]:
   w.kit.box(chunk,point(d,side*11.7)+Vector3(0,.02,0),Vector3(1.3,.04,104),gravel)
  for tree in range(10):
   var td=section*100.0+rng.randf_range(0,100)
   var side=-1 if tree%2==0 else 1
   var offset=side*rng.randf_range(15,52)
   if tree==2 and section>0:
    offset=(-4.8 if section%2==0 else 4.8)
    var nearest_ramp=180.0+roundf((td-180)/240)*240.0
    if absf(td-nearest_ramp)<48:offset=side*18.0
   var at=point(td,offset);var height=rng.randf_range(12,22)
   w.kit.cylinder(chunk,at+Vector3.UP*height*.5,rng.randf_range(.55,1.1),height,bark,true)
   for tier in range(2):
    var cone=CylinderMesh.new();cone.top_radius=.2;cone.bottom_radius=4.5-tier;cone.height=7;cone.radial_segments=7
    w.kit.mesh(chunk,cone,at+Vector3.UP*(height-2+tier*3),leaf)
   if tree%3==0:
    w.kit.branch(chunk,at+Vector3(0,.4,0),at+Vector3(side*3,.1,2),.25,bark)
  var near_ramp=180.0+roundf((d+22-180)/240)*240.0
  if section>0 and absf(d+22-near_ramp)>38:
   var obstacle=point(d+22,(-1 if section%2==0 else 1)*7)
   var rock=w.kit.sphere(chunk,obstacle+Vector3.UP*.65,1.2,w.palette.rock);rock.scale=Vector3(1.5,.7,1.0)
   w.kit.box(chunk,obstacle+Vector3.UP*.55,Vector3(2.6,1.1,1.6),w.palette.rock,true)
  if section%3==0:
   for side in [-1,1]:
    var at=point(d,side*13)
    w.kit.box(chunk,at+Vector3.UP*.8,Vector3(.2,1.6,.2),w.kit.dark,true)
    w.kit.box(chunk,at+Vector3(0,1.5,0),Vector3(.7,.18,.12),w.kit.gold)
  # Native visibility ranges cull whole rigid batches; collisions are unchanged.
  NestRigidBatch.build(chunk)
  for mesh in chunk.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=210;mesh.visibility_range_end_margin=35
 for index in range(32):
  var d=180.0+index*240.0
  if d>ROAD_LENGTH-100:break
  var ramp=Node3D.new();ramp.name="JumpRamp_%02d"%index;w.scene_root.add_child(ramp);ramp.position=point(d+6,(-3.6 if index%2==0 else 3.6))+Vector3.UP*.95;ramp.rotation.x=atan(2.0/12.0)
  w.kit.box(ramp,Vector3.ZERO,Vector3(7.4,.22,12.2),w.palette.panel,true)
  for side in [-1,1]:w.kit.box(ramp,Vector3(side*3.35,.15,0),Vector3(.13,.08,11.8),w.kit.gold)
  for z in [-3.0,0.0,3.0]:w.kit.box(ramp,Vector3(0,.15,z),Vector3(5,.06,.18),w.kit.lamp)
  NestRigidBatch.build(ramp)
  for mesh in ramp.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=210
  var sign=w.sign_at(point(d-20,10)+Vector3.UP*3,"JUMP / RELEASE THROTTLE IN AIR",Color("ffcf7d"),23);sign.visibility_range_end=55
  if index%3==1:
   # Fallen cross-trail timber makes ten of the marked jumps actual obstacles.
   # The slower shoulder is a recovery route, never an invisible kill volume.
   var log_at=point(d+20)+Vector3.UP*.5
   w.kit.box(w.scene_root,log_at,Vector3(23,1,1.3),bark,true)
   w.kit.branch(w.scene_root,log_at+Vector3(-10,.1,0),log_at+Vector3(10,.15,.2),.55,bark)
   w.sign_at(point(d-44,-11)+Vector3.UP*2.5,"FALLEN TIMBER / TAKE RAMP",Color("ffce82"),22).visibility_range_end=70
 for sector in range(SECTORS):
  var start=sector*SECTOR_LENGTH
  var finish=(sector+1)*SECTOR_LENGTH
  w.locations["objective"+str(sector)]=point(finish,-7)
  w.locations["supply"+str(sector)]=point(start+12,18)
  w.station("supply"+str(sector),w.locations["supply"+str(sector)],"FIELD CACHE / AMMUNITION")
  w.sign_at(point(start+50)+Vector3.UP*5,"%02d / %s\nFLOODGATE %0.1f KM"%[sector+1,SECTOR_NAMES[sector],(ROAD_LENGTH-start)/1000],Color("d5e5ba"),27).visibility_range_end=95
  for at in encounter_spawns(sector):
   var side=signf(at.x-center_x(-at.z));var cover=at+Vector3(side*1.8,.7,0)
   w.kit.box(w.scene_root,cover,Vector3(1.2,1.4,3.4),w.palette.rock,true);w.cover_points.append(at)
   w.kit.box(w.scene_root,cover+Vector3(side*.2,1.2,0),Vector3(.12,1.2,3),w.kit.dark)
  # Rest bays, dismantled freight hardware and abandoned Annu roadblocks.
  for side in [-1,1]:
   var at=point(start+52,side*24)
   w.kit.box(w.scene_root,at+Vector3.UP*1.4,Vector3(7,2.8,12),w.palette.hull,true)
   for x in [-2.5,0,2.5]:w.kit.box(w.scene_root,at+Vector3(x,3,0),Vector3(.12,.1,10),w.kit.gold)
  if sector in [2,4]:
   for j in range(8):
    var at=point(start+220+j*8,20)
    w.kit.box(w.scene_root,at+Vector3.UP*5,Vector3(4,10,3),w.palette.rock,true)
    w.kit.box(w.scene_root,at+Vector3(-5,10,0),Vector3(14,1.2,3),w.palette.panel)
 for slot in range(1,5):w.spawns[0].append(spawn(0,slot))
 w.spawns[1]=encounter_spawns(0)
 w.locations["exit"]=point(ROAD_LENGTH,-7)
 w.sign_at(point(ROAD_LENGTH)+Vector3.UP*5,"FLOODGATE / END OF FOREST CORRIDOR",Color("a4e8dd"),30).visibility_range_end=100
 # Physical end wall prevents escaping the course and provides a braking landmark.
 w.kit.box(w.scene_root,point(ROAD_LENGTH+35)+Vector3.UP*4,Vector3(60,8,3),w.palette.rock,true)
 w.sign_at(point(22)+Vector3.UP*3.8,"FOUR EXPEDITION MOTORCYCLES\nHOLD INTERACT TO MOUNT / W THROTTLE / S BRAKE\nA D STEER / SPACE HOP / RELEASE W IN AIR",Color("e3e5c1"),26).visibility_range_end=45
