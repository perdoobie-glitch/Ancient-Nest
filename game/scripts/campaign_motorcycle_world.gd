class_name NestCampaignMotorcycleWorld
extends RefCounted
# The entire road is deterministic. Physics remains present outside render range.
const ROAD_LENGTH=7900.0
const SECTORS=6
const SECTOR_LENGTH=ROAD_LENGTH/SECTORS
const ROAD_WIDTH=22.0
const TERRAIN_STEP=4.0
const ELEVATION_DISTANCE=[0.0,120.0,420.0,900.0,1320.0,1740.0,2150.0,2640.0,3060.0,3450.0,3950.0,4380.0,4780.0,5260.0,5690.0,6100.0,6580.0,6980.0,7380.0,7900.0,8000.0]
const ELEVATION_HEIGHT=[0.0,0.0,26.0,8.0,48.0,78.0,28.0,12.0,66.0,96.0,40.0,10.0,54.0,30.0,80.0,106.0,48.0,16.0,52.0,20.0,20.0]
const BRIDGES=[[2150.0,2320.0],[4060.0,4240.0],[6220.0,6400.0]]
const SLALOM_START=144.0
const SLALOM_SPACING=24.0
const SLALOM_AMPLITUDE=2.4
static var _branches_cache: Array=[]
static var _slalom_cache: Array=[]
const SECTOR_NAMES=["WRECK RUN","ROOT SLALOM","BROKEN VIADUCT","FLOODED CUT","ASH RIDGE","FLOODGATE APPROACH"]
static func center_x(distance: float) -> float:
 return sin(distance*.003)*14.0+sin(distance*.009)*5.0
static func point(distance: float,side=0.0) -> Vector3:
 return Vector3(center_x(distance)+side,terrain_height(distance,side),-distance)
static func road_height(distance: float) -> float:
 var d=clampf(distance,0,8000)
 for i in range(ELEVATION_DISTANCE.size()-1):
  if d<=ELEVATION_DISTANCE[i+1]:
   var u=(d-float(ELEVATION_DISTANCE[i]))/(float(ELEVATION_DISTANCE[i+1])-float(ELEVATION_DISTANCE[i]))
   var height=lerpf(float(ELEVATION_HEIGHT[i]),float(ELEVATION_HEIGHT[i+1]),smoothstep(0,1,u))
   # Small rollers between the major hills produce visible suspension travel.
   return height+sin(d*TAU/180.0)*1.1*smoothstep(120,300,d)
 return 20.0
static func bridge_index(distance: float) -> int:
 for i in range(BRIDGES.size()):
  if distance>=BRIDGES[i][0] and distance<=BRIDGES[i][1]:return i
 return -1
static func terrain_height(distance: float,side=0.0) -> float:
 var height=road_height(distance);var side_abs=absf(side)
 if side_abs<=12:return height
 var shoulder=smoothstep(12,24,side_abs)
 var ridge=smoothstep(24,60,side_abs)
 var bank=3.0+sin(distance*.018+signf(side)*1.7)*2.5
 var outer=sin(distance*.007+signf(side))*12.0+7.0
 if bridge_index(distance)>=0:
  var span=BRIDGES[bridge_index(distance)];var edge=minf(distance-float(span[0]),float(span[1])-distance)
  return maxf(-7,height-shoulder*22*smoothstep(0,24,edge)-ridge*9)
 return maxf(-7,height+shoulder*bank+ridge*outer)
static func surface_height(at: Vector3) -> float:
 return terrain_height(-at.z,at.x-center_x(-at.z))
static func recovery_height(at: Vector3) -> float:
 var height=surface_height(at);var ramp=ramp_info(-at.z)
 if not ramp.is_empty() and absf(at.x-float(ramp.x))<float(ramp.width)*.5:
  var middle=float(ramp.start)+6
  height=maxf(height,road_height(middle)+1.07+(-at.z-middle)*(road_grade(middle)+2.0/12.0))
 return height
static func road_grade(distance: float) -> float:
 return (road_height(distance+2)-road_height(distance-2))/4.0
static func weapon_cache_points() -> Array[Vector3]:
 var points: Array[Vector3]=[]
 for i in range(8):points.append(point(80.0+i*970.0,17.0 if i%2==0 else -17.0)+Vector3.UP*.25)
 return points
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
static func branch_hazards() -> Array:
 if not _branches_cache.is_empty():return _branches_cache
 var hazards=[]
 for i in range(16):
  for entry in [[300.0+i*480.0,"duck"],[540.0+i*480.0,"hop"]]:
   if float(entry[0])<ROAD_LENGTH-65:hazards.append({"distance":float(entry[0]),"type":str(entry[1])})
 _branches_cache=hazards;return hazards
static func nearest_branch(distance: float) -> Dictionary:
 var best={};var separation=INF
 for hazard in branch_hazards():
  var gap=absf(float(hazard.distance)-distance)
  if gap<separation:separation=gap;best=hazard
 return best
static func slalom_strength(distance: float) -> float:
 if distance<125 or distance>ROAD_LENGTH-55:return 0
 var ramp=180.0+roundf((distance-186.0)/240.0)*240.0+6
 var branch=nearest_branch(distance)
 var branch_gap=absf(distance-float(branch.get("distance",-1000)))
 return minf(smoothstep(27,35,absf(distance-ramp)),smoothstep(18,26,branch_gap))
static func expert_lane(distance: float) -> float:
 var lane=cos((distance-SLALOM_START)*PI/SLALOM_SPACING)*SLALOM_AMPLITUDE*slalom_strength(distance)
 var ramp_index=maxi(0,roundi((distance-186)/240));var ramp_middle=186.0+ramp_index*240.0
 var weight=1-smoothstep(18,35,absf(distance-ramp_middle))
 return lane+(-3.6 if ramp_index%2==0 else 3.6)*weight
static func slalom_groups() -> Array:
 if not _slalom_cache.is_empty():return _slalom_cache
 var groups=[]
 for i in range(323):
  var d=SLALOM_START+i*SLALOM_SPACING
  if d>=ROAD_LENGTH-55 or slalom_strength(d)<.99:continue
  var lane=cos((d-SLALOM_START)*PI/SLALOM_SPACING)*SLALOM_AMPLITUDE
  groups.append({"distance":d,"lane":lane,"index":i})
 _slalom_cache=groups;return groups
static func build_world(w):
 w.ambience.fog_density=.0022;w.ambience.fog_light_color=Color("728777")
 var ground=w.kit.material(Color("35443a"));var road=w.kit.material(Color("8b7353"));var gravel=w.kit.material(Color("a39b7d"));var bark=w.palette.bark;var leaf=w.palette.leaf
 w.floor_surfaces.clear();w.bounds=Vector2(90,ROAD_LENGTH+100)
 w.set_meta("bike_road_length",ROAD_LENGTH)
 var rng=RandomNumberGenerator.new();rng.seed=2026102602
 var chunks=[]
 for section in range(80):
  var chunk=Node3D.new();chunk.name="CanopySector_%02d"%section;chunk.set_meta("terrain_origin",point(section*100.0+50));w.scene_root.add_child(chunk);chunks.append(chunk)
  var d=section*100.0+40
  terrain_chunk(w,chunk,section*100.0-40.0 if section==0 else section*100.0,section*100.0+100.0,ground,road,gravel)
  for tree in range(16):
   var td=section*100.0+rng.randf_range(0,100)
   var side=-1 if tree%2==0 else 1
   var offset=side*rng.randf_range(15,52)
   if tree==2 and section>0:
    offset=(-4.8 if section%2==0 else 4.8)
    var nearest_ramp=180.0+roundf((td-180)/240)*240.0
    if absf(td-nearest_ramp)<48:offset=side*18.0
   if near_cache(td,offset):offset=side*36.0
   var at=point(td,offset);var height=rng.randf_range(12,29)
   w.kit.cylinder(chunk,at+Vector3.UP*height*.5,rng.randf_range(.55,1.1),height,bark,true)
   if tree%4==0:
    for crown in range(3):
     var canopy=w.kit.sphere(chunk,at+Vector3(sin(crown*2.1)*3,height-2+cos(crown*1.9)*2,cos(crown*2.1)*3),4.4,leaf);canopy.scale=Vector3(1.3,.7,1.1)
     w.kit.branch(chunk,at+Vector3.UP*(height*.6),at+Vector3(sin(crown*2.1)*4,height-3,cos(crown*2.1)*4),.24,bark)
   else:
    for tier in range(3):
     var cone=CylinderMesh.new();cone.top_radius=.2;cone.bottom_radius=5.0-tier;cone.height=7;cone.radial_segments=8
     w.kit.mesh(chunk,cone,at+Vector3.UP*(height-5+tier*3),leaf)
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
  dress_roadside(w,chunk,section,rng)
  build_slalom_trees(w,chunk,section)
  # Native visibility ranges cull whole rigid batches; collisions are unchanged.
  rebase_group(chunk,chunk.get_meta("terrain_origin"))
  NestRigidBatch.build(chunk)
  for mesh in chunk.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=280;mesh.visibility_range_end_margin=45
 for index in range(32):
  var d=180.0+index*240.0
  if d>ROAD_LENGTH-100:break
  var ramp=Node3D.new();ramp.name="JumpRamp_%02d"%index;w.scene_root.add_child(ramp);ramp.position=point(d+6,(-3.6 if index%2==0 else 3.6))+Vector3.UP*.95;ramp.rotation.x=atan(2.0/12.0+road_grade(d+6))
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
 build_bridges(w)
 build_cache_bays(w)
 build_branches(w)
 w.set_meta("road_dodge_tree_count",slalom_groups().size()*6)
 w.spawns[1]=encounter_spawns(0)
 w.locations["exit"]=point(ROAD_LENGTH,-7)
 w.sign_at(point(ROAD_LENGTH)+Vector3.UP*5,"FLOODGATE / END OF FOREST CORRIDOR",Color("a4e8dd"),30).visibility_range_end=100
 # Physical end wall prevents escaping the course and provides a braking landmark.
 w.kit.box(w.scene_root,point(ROAD_LENGTH+35)+Vector3.UP*4,Vector3(60,8,3),w.palette.rock,true)
 w.sign_at(point(22)+Vector3.UP*3.8,"FOUR EXPEDITION MOTORCYCLES\nHOLD INTERACT TO MOUNT / W THROTTLE / S BRAKE\nA D STEER / SPACE HOP / RELEASE W IN AIR",Color("e3e5c1"),26).visibility_range_end=45
static func near_cache(distance: float,side: float) -> bool:
 for i in range(8):
  if absf(distance-(80+i*970))<13 and absf(side-(17 if i%2==0 else -17))<11:return true
 return false
static func terrain_chunk(w,parent: Node3D,start: float,finish: float,soil: Material,road: Material,gravel: Material):
 var origin: Vector3=parent.get_meta("terrain_origin",Vector3.ZERO)
 var sections=[-75.0,-52.0,-34.0,-24.0,-17.0,-12.0,-11.0,0.0,11.0,12.0,17.0,24.0,34.0,52.0,75.0]
 var tools=[]
 for material in [soil,road,gravel]:
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(material);tools.append(surface)
 var faces=PackedVector3Array();var distance=start
 while distance<finish-.001:
  var end=minf(finish,distance+TERRAIN_STEP)
  for index in range(sections.size()-1):
   var side_a=float(sections[index]);var side_b=float(sections[index+1]);var middle=(side_a+side_b)*.5
   var surface=tools[1 if absf(middle)<11 else 2 if absf(middle)<17 else 0]
   var a=point(distance,side_a);var b=point(distance,side_b);var c=point(end,side_a);var d=point(end,side_b)
   # Godot front faces use clockwise winding; these face upward for raycasts
   # and the one-sided physical triangle mesh as well as rendering.
   for vertex in [a,c,b,b,c,d]:
    surface.set_uv(Vector2(vertex.x*.08,vertex.z*.08));surface.add_vertex(vertex-origin);faces.append(vertex-origin)
  distance=end
 var mesh=ArrayMesh.new()
 for surface in tools:surface.generate_normals();surface.commit(mesh)
 var visible=MeshInstance3D.new();visible.name="HillsideAndRoad";visible.mesh=mesh;parent.add_child(visible);visible.position=origin
 var body=StaticBody3D.new();body.name="PhysicalHillside";body.collision_layer=1;body.collision_mask=2;body.set_meta("surface_material","dirt");parent.add_child(body);body.position=origin
 var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
 w.floor_surfaces.append({"pos":point((start+finish)*.5),"size":Vector2(ROAD_WIDTH,finish-start)})
static func dress_roadside(w,parent: Node3D,index: int,rng: RandomNumberGenerator):
 var d=index*100.0+45;var k=w.kit;var bark=w.palette.bark;var stone=w.palette.rock;var panel=w.palette.panel
 var plant=k.material(Color("556d45"));var moss=k.material(Color("6c7555"));var rust=k.material(Color("775444"),.35)
 # Strata, exposed roots, fern beds and drainage rubble vary by road sector.
 for n in range(9):
  var td=index*100+rng.randf_range(3,97);var side=-1 if n%2==0 else 1;var lateral=side*rng.randf_range(18,55)
  if near_cache(td,lateral):continue
  var p=point(td,lateral)
  if n%3==0:
   var rock=k.sphere(parent,p+Vector3.UP*rng.randf_range(.3,.7),rng.randf_range(.6,1.5),stone);rock.scale=Vector3(1.7,.6,1.2)
   for fern in range(3):
    var stem=Vector3(cos(fern*TAU/3),.65,sin(fern*TAU/3))*1.1
    k.branch(parent,p,p+stem,.045,plant)
    for leaf in range(2):
     var frond=k.box(parent,p+stem*(.5+leaf*.25),Vector3(.8,.04,.23),plant);frond.rotation.y=fern*TAU/3
  elif n%3==1:
   k.cylinder(parent,p+Vector3.UP*.4,.45,.8,bark)
   for root in range(3):k.branch(parent,p+Vector3.UP*.2,p+Vector3(cos(root*2.1)*2,.05,sin(root*2.1)*2),.12,bark)
  else:
   k.branch(parent,p+Vector3.UP*.2,p+Vector3(side*4,.25,3),.22,bark)
   for mushroom in range(3):
    k.cylinder(parent,p+Vector3(mushroom*.24,.13,.25),.035,.25,k.dark)
    var cap=k.sphere(parent,p+Vector3(mushroom*.24,.27,.25),.13,moss);cap.scale.y=.35
 # Road ruts and runoff lines lie on the actual grade, never float above valleys.
 for side in [-1,1]:
  for n in range(5):
   var td=index*100+n*20+6;var rut=k.box(parent,point(td,side*4)+Vector3.UP*.024,Vector3(.16,.035,8),rust);rut.rotation.x=atan(road_grade(td))
  var ridge=point(d,side*45)
  var cliff=k.sphere(parent,ridge+Vector3.UP*4,7,stone);cliff.scale=Vector3(1.8,1.4,2.8)
  if index%4==0:
   for layer in range(3):
    var at=point(d+layer*3,side*16.5)+Vector3.UP*(.3+layer*.45)
    k.box(parent,at,Vector3(1.8,.65,18-layer*2),stone,true)
  if index%5==0:
   var at=point(d,side*14)
   k.box(parent,at+Vector3.UP*1.6,Vector3(.15,3.2,.15),k.dark,true)
   k.box(parent,at+Vector3(0,2.7,0),Vector3(.8,.6,.12),k.gold)
   k.box(parent,at+Vector3(0,2.7,.08),Vector3(.16,.46,.02),k.lamp)
 if index%7==0:
  # An abandoned freight tractor with no new occupant or character asset.
  var at=point(d+18,29);k.box(parent,at+Vector3.UP*1.2,Vector3(3,1.4,6),rust,true)
  k.box(parent,at+Vector3(0,2.4,-1.4),Vector3(2.8,1.8,2.4),panel,true)
  k.box(parent,at+Vector3(0,2.7,-2.63),Vector3(2.2,.7,.03),k.dark)
  for x in [-1.6,1.6]:
   for z in [-1.8,1.8]:
    var wheel=k.cylinder(parent,at+Vector3(x,.65,z),.66,.42,k.dark);wheel.rotation.z=PI*.5
  for n in range(3):k.box(parent,at+Vector3((n%2-.5)*1.4,2.2,1+n*.8),Vector3(1.2,.9,.8),w.palette.hull)
 if index%9==0:
  var at=point(d,-31)
  for x in [-2,2]:
   k.branch(parent,at+Vector3(x,0,0),at+Vector3(x+5,12,-3),.18,rust)
  for n in range(5):
   var p=at+Vector3(n,2+n*2,-n*.6)
   k.branch(parent,p+Vector3(-2,0,0),p+Vector3(2,1.8,-.6),.1,k.dark)
  k.branch(parent,at+Vector3(5,12,-3),at+Vector3(22,4,-35),.04,k.dark)
 if index%8==3:
  var at=point(d,-27)
  for x in [-5,5]:
   k.box(parent,at+Vector3(x,3,0),Vector3(2,6,3),stone,true)
   k.box(parent,at+Vector3(x*.6,6.4,0),Vector3(6,1.2,3),stone,true)
  for n in range(5):k.box(parent,at+Vector3(-8+n*3,.5,-4),Vector3(2,1,1.5),stone,true)
 if index%6==0:
  for side in [-1,1]:
   # Large distant ridge silhouettes give the climb a visible destination.
   var p=point(d,side*130);p.y=road_height(d)-7
   var mountain=k.sphere(parent,p+Vector3.UP*28,24,stone);mountain.scale=Vector3(2.2,2.8,2.6);mountain.set_meta("vista",true)
static func build_bridges(w):
 var k=w.kit
 for index in range(BRIDGES.size()):
  var span=BRIDGES[index];var parent=Node3D.new();parent.name="RavineViaduct_%d"%index;w.scene_root.add_child(parent)
  var d=float(span[0])
  while d<float(span[1]):
   for side in [-1,1]:
    var at=point(d,side*11.7)
    k.box(parent,at+Vector3.UP*1,Vector3(.18,2,.18),k.dark,true)
    var rail=Node3D.new();parent.add_child(rail);rail.position=at+Vector3(0,1.5,-4);rail.rotation.x=atan(road_grade(d+4))
    k.box(rail,Vector3.ZERO,Vector3(.22,.18,8.3),w.palette.panel,true)
    k.box(rail,Vector3(0,-.65,0),Vector3(.15,.12,8.3),k.gold)
    if int(d-float(span[0]))%24<8:
     k.box(parent,at+Vector3(0,-11,0),Vector3(2.2,22,2.2),w.palette.rock,true)
     k.branch(parent,at+Vector3(0,-1,0),at+Vector3(-side*6,-12,-8),.28,k.dark)
   var beam=Node3D.new();parent.add_child(beam);beam.position=point(d)+Vector3(0,-.6,-4);beam.rotation.x=atan(road_grade(d+4))
   k.box(beam,Vector3.ZERO,Vector3(23,1,1),w.palette.panel)
   d+=8
  var center=(float(span[0])+float(span[1]))*.5
  var water=k.box(parent,point(center)+Vector3(0,-27,0),Vector3(120,.1,float(span[1])-float(span[0])-35),k.material(Color("346572"),.4))
  w.sign_at(point(float(span[0])-28,-11)+Vector3.UP*3,"RAVINE VIADUCT / CONTROL YOUR LANDING",Color("ffcc7a"),22).visibility_range_end=80
  rebase_group(parent,point(center));NestRigidBatch.build(parent)
  for mesh in parent.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=330
static func build_cache_bays(w):
 var k=w.kit;var points=weapon_cache_points()
 for index in range(points.size()):
  var at=points[index]-Vector3.UP*.25;var side=signf(at.x-center_x(-at.z));var parent=Node3D.new();parent.name="ExpeditionLayby_%d"%index;w.scene_root.add_child(parent)
  for x in [-2.4,2.4]:
   for z in [-3,3]:
    var foot=Vector3(at.x+x,surface_height(at+Vector3(x,0,z)),at.z+z)
    k.box(parent,foot+Vector3.UP*1.7,Vector3(.15,3.4,.15),k.dark,true)
  k.box(parent,at+Vector3.UP*3.6,Vector3(5.8,.18,7),w.palette.hull)
  for z in [-2.2,2.2]:k.box(parent,at+Vector3(side*2.4,1,z),Vector3(.6,2,1),w.palette.rock,true)
  for n in range(3):
   var p=at+Vector3(side*(3.5+n*.6),0,-2+n*1.6);p.y=surface_height(p)
   k.cylinder(parent,p+Vector3.UP*.55,.38,1.1,k.dark,true)
   k.cylinder(parent,p+Vector3.UP*.56,.4,.12,k.gold)
  w.sign_at(at+Vector3.UP*3.1,"FIELD CACHE %02d / BRAKE + DISMOUNT\nWEAPONS / COVER / RETURN TO ROAD"%(index+1),Color("b4e4d2"),22).visibility_range_end=50
  w.locations["weapon_cache"+str(index)]=points[index]
  rebase_group(parent,at);NestRigidBatch.build(parent)
static func rebase_group(parent: Node3D,origin: Vector3):
 # Culling measures nearby section instances, not an origin kilometres away.
 # Rebasing before batching also keeps mesh coordinates precise on the long road.
 for child in parent.get_children():
  if child is Node3D:child.position-=origin
 parent.position=origin
static func build_slalom_trees(w,parent: Node3D,section: int):
 var k=w.kit
 for group in slalom_groups():
  var d=float(group.distance)
  if floori(d/100)!=section:continue
  var mirror=1.0 if float(group.lane)>0 else -1.0
  var offsets=[-11.0,-7.0,-3.0,0.0,4.8,10.5]
  for index in range(offsets.size()):
   var at=point(d,float(offsets[index])*mirror);var height=12.0+posmod(int(group.index)*7+index*3,9)
   var trunk=k.cylinder(parent,at+Vector3.UP*height*.5,.62,height,w.palette.bark,true);trunk.name="MandatorySlalomTree_%d_%d"%[group.index,index]
   # Light bark bands and reflective arrows make the usable gap readable.
   k.cylinder(parent,at+Vector3.UP*1.3,.64,.22,k.gold)
   k.branch(parent,at+Vector3.UP*.15,at+Vector3(mirror*1.4,.08,1.8),.14,w.palette.bark)
   var canopy=CylinderMesh.new();canopy.radial_segments=7;canopy.top_radius=.3;canopy.bottom_radius=3.4;canopy.height=7
   k.mesh(parent,canopy,at+Vector3.UP*(height-1),w.palette.leaf)
  var gap=point(d,float(group.lane))
  k.box(parent,gap+Vector3.UP*.035,Vector3(1.4,.04,.8),k.gold)
static func build_branches(w):
 var k=w.kit
 for hazard in branch_hazards():
  var d=float(hazard.distance);var duck=hazard.type=="duck";var parent=Node3D.new();parent.name=("DuckBranch_" if duck else "HopBranch_")+str(int(d));w.scene_root.add_child(parent)
  var center=point(d);parent.position=center;parent.rotation.x=atan(road_grade(d))
  var height=2.1 if duck else .4;var thickness=.5 if duck else .55
  k.box(parent,Vector3(0,height,0),Vector3(23,thickness,.85),w.palette.bark,true)
  k.branch(parent,Vector3(-11,height,0),Vector3(11,height+.03,0),thickness*.55,w.palette.bark)
  for side in [-1,1]:
   k.cylinder(parent,Vector3(side*12,3.6,0),.8,7.2,w.palette.bark,true)
   k.branch(parent,Vector3(side*12,4,0),Vector3(side*3,5.5,-2),.22,w.palette.bark)
  for x in [-8,-4,0,4,8]:k.box(parent,Vector3(x,height,-.46),Vector3(.38,thickness*.8,.04),k.gold)
  var instruction="DUCK / HOLD CROUCH" if duck else "LOW BRANCH / JUMP"
  w.sign_at(point(d-34,-10)+Vector3.UP*3.3,instruction,Color("83d8eb") if duck else Color("ffce80"),29).visibility_range_end=85
  for offset in [21,15,9]:
   var at=point(d-offset);var paint=k.box(w.scene_root,at+Vector3.UP*.035,Vector3(6,.04,.45),k.gold);paint.rotation.x=atan(road_grade(d-offset))
  NestRigidBatch.build(parent)
  for mesh in parent.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=240
