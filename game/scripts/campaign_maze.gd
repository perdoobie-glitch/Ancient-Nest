class_name NestCampaignMaze
extends RefCounted
# One authored spine plus tree branches: no loops or alternate routes to the relay.
const CELL=20.0
const WALL_HEIGHT=13.0
const WALL_THICKNESS=3.0
const PATH_WIDTH=11.6
const STAGES=[12,28,45,63,80]
var w
var edges={}
var cells={}
var spine: Array[Vector2i]=[]
var checkpoints=[]
var approaches=[]
var vertical_sites=[]
var route_signs=[]
var names=["FERN RIDGE","RIVER GARDEN","ROOT SANCTUARY","GOLDEN RAVINE","EXPEDITION RELAY"]
var stats={"walls":0,"flowers":0,"bridges":0,"branches":0,"climbing_sites":0,"area_m2":40000,"clear_width":17.0,"wall_height":13.0}
var rng=RandomNumberGenerator.new()
var flower_materials=[]
var water_material: Material
func _init(world):w=world;rng.seed=90125
func hub(c: Vector2i) -> bool:return c.x>=-1 and c.x<=1 and c.y>=0 and c.y<=1
func key(a: Vector2i,b: Vector2i) -> String:
 return "%d,%d:%d,%d"%[a.x,a.y,b.x,b.y] if a.x*32+a.y<b.x*32+b.y else "%d,%d:%d,%d"%[b.x,b.y,a.x,a.y]
func link_cells(a: Vector2i,b: Vector2i):edges[key(a,b)]=[a,b]
func position(c: Vector2i) -> Vector3:return Vector3(c.x*CELL,0,c.y*CELL)
func neighbours(c: Vector2i) -> Array:
 var result=[]
 for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if edges.has(key(c,c+d)):result.append(c+d)
 return result
func layout():
 var points=[Vector2i(0,2),Vector2i(-1,2),Vector2i(-2,2),Vector2i(-3,2),Vector2i(-3,3),Vector2i(-4,3),Vector2i(-4,4),Vector2i(-3,4),Vector2i(-3,5),Vector2i(-2,5),Vector2i(-2,4),Vector2i(-1,4),Vector2i(-1,3),Vector2i(0,3),Vector2i(0,4),Vector2i(1,4),Vector2i(1,5),Vector2i(2,5),Vector2i(2,4),Vector2i(3,4),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5),Vector2i(5,4),Vector2i(4,4),Vector2i(4,3),Vector2i(5,3),Vector2i(5,2),Vector2i(4,2),Vector2i(4,1),Vector2i(5,1),Vector2i(5,0),Vector2i(4,0),Vector2i(4,-1),Vector2i(5,-1),Vector2i(5,-2),Vector2i(4,-2),Vector2i(4,-3),Vector2i(5,-3),Vector2i(5,-4),Vector2i(4,-4),Vector2i(3,-4),Vector2i(3,-3),Vector2i(2,-3),Vector2i(2,-4),Vector2i(1,-4),Vector2i(1,-3),Vector2i(0,-3),Vector2i(0,-4),Vector2i(-1,-4),Vector2i(-2,-4),Vector2i(-2,-3),Vector2i(-3,-3),Vector2i(-3,-4),Vector2i(-4,-4),Vector2i(-4,-3),Vector2i(-4,-2),Vector2i(-3,-2),Vector2i(-3,-1),Vector2i(-4,-1),Vector2i(-4,0),Vector2i(-3,0),Vector2i(-3,1),Vector2i(-2,1),Vector2i(-2,0),Vector2i(-2,-1),Vector2i(-1,-1),Vector2i(-1,-2),Vector2i(0,-2),Vector2i(1,-2),Vector2i(2,-2),Vector2i(2,-1),Vector2i(3,-1),Vector2i(3,0),Vector2i(2,0),Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(2,2),Vector2i(2,3),Vector2i(1,3),Vector2i(1,2)]
 for c in points:spine.append(c);cells[c]=true
 for i in range(spine.size()-1):link_cells(spine[i],spine[i+1])
 link_cells(Vector2i(0,1),spine[0])
 var queue=cells.keys()
 while not queue.is_empty():
  var c: Vector2i=queue.pop_front();var directions=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
  for i in range(4):
   var j=rng.randi_range(i,3);var tmp=directions[i];directions[i]=directions[j];directions[j]=tmp
  for d in directions:
   var n: Vector2i=c+d
   if n.x< -4 or n.x>5 or n.y< -4 or n.y>5 or hub(n) or cells.has(n):continue
   cells[n]=true;link_cells(c,n);queue.append(n);stats.branches+=1
 for stage in STAGES:
  checkpoints.append(position(spine[stage]));approaches.append(position(spine[stage-3]))
 # The last encounter occupies the end of the route rather than an earlier side corridor.
 checkpoints[4]=position(spine[-1]);approaches[4]=position(spine[STAGES[4]-3])
func build():
 layout()
 var dirt=w.surface("735039","a17e51",5);var fern=w.surface("294c36","729358",3)
 for color in ["e4b354","b48abe","e7d5ac","cc6f68"]:flower_materials.append(w.kit.material(Color(color)))
 water_material=ShaderMaterial.new();water_material.shader=load("res://assets/campaign_river.gdshader")
 for pair in edges.values():
  var a=position(pair[0]);var b=position(pair[1]);var size=Vector3(PATH_WIDTH,.035,PATH_WIDTH)+(b-a).abs()
  w.block((a+b)*.5+Vector3.UP*.025,size,dirt,false)
 for c in cells:
  var p=position(c);var patch=w.kit.cylinder(w.scene_root,p+Vector3.UP*.045,PATH_WIDTH*.54,.035,dirt);patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for d in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
   var n: Vector2i=c+d
   if edges.has(key(c,n)):continue
   if cells.has(n) and (d==Vector2i.LEFT or d==Vector2i.UP):continue
   hedge(p+Vector3(d.x*CELL*.5,0,d.y*CELL*.5),d,fern)
  if neighbours(c).size()==1 and c!=spine[-1] and c!=spine[0]:climbing_garden(c)
 # Close the crash courtyard to every adjacent cell except the entrance.
 for x in range(-1,2):
  for z in range(0,2):
   var c=Vector2i(x,z)
   for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var n=c+d
    if hub(n) or cells.has(n) or edges.has(key(c,n)):continue
    hedge(position(c)+Vector3(d.x*CELL*.5,0,d.y*CELL*.5),d,fern)
 river(Vector3(-50,.055,10),Vector3(5,.07,200));river(Vector3(10,.058,-50),Vector3(200,.07,5))
 for pair in edges.values():
  var a=position(pair[0]);var b=position(pair[1])
  if (a.x< -50 and b.x> -50) or (b.x< -50 and a.x> -50):bridge(Vector3(-50,0,a.z),true)
  if (a.z< -50 and b.z> -50) or (b.z< -50 and a.z> -50):bridge(Vector3(a.x,0,-50),false)
 for i in range(5):
  w.locations["checkpoint"+str(i)]=checkpoints[i];w.locations["approach"+str(i)]=approaches[i]
  for side in [-1,1]:
   w.block(checkpoints[i]+Vector3(side*7,.65,5),Vector3(2.3,1.3,3.5),w.palette.rock)
   w.cover_points.append(checkpoints[i]+Vector3(side*7,0,2.4));flowers(checkpoints[i]+Vector3(side*7,0,7),i)
  # A discrete breadcrumb midway to the next stage prevents a waypoint through walls.
  w.locations["trail"+str(i)]=approaches[i]
  w.station("field"+str(i),checkpoints[i]+Vector3(-6,0,-5),"FIELD RESUPPLY / AMMUNITION")
 trail_details()
 w.set_meta("maze_stats",stats)
func hedge(p: Vector3,d: Vector2i,material: Material):
 var along=Vector3(0,0,1) if d.x!=0 else Vector3(1,0,0)
 var size=Vector3(WALL_THICKNESS,WALL_HEIGHT,CELL) if d.x!=0 else Vector3(CELL,WALL_HEIGHT,WALL_THICKNESS)
 w.block(p+Vector3.UP*WALL_HEIGHT*.5,size,material);stats.walls+=1
 for j in range(4):
  var crown=w.kit.sphere(w.scene_root,p+along*(j-1.5)*4.7+Vector3.UP*12.4,2.1,material);crown.scale=Vector3(.8,1,1.3) if d.x!=0 else Vector3(1.3,1,.8)
 if stats.walls%2==0:
  w.kit.cylinder(w.scene_root,p+Vector3.UP*10,.55,20,w.palette.bark)
  var canopy=w.kit.sphere(w.scene_root,p+Vector3.UP*22,4.8,w.palette.leaf);canopy.scale=Vector3(1.3,.65,1.3)
 flowers(p-Vector3(d.x*2.2,0,d.y*2.2),stats.walls)
func flowers(p: Vector3,index: int):
 for j in range(3 if w.quality==0 else 6):
  var root=p+Vector3(rng.randf_range(-1.1,1.1),0,rng.randf_range(-1.1,1.1));var h=rng.randf_range(.35,.8)
  var stem_mesh=CylinderMesh.new();stem_mesh.top_radius=.025;stem_mesh.bottom_radius=.04;stem_mesh.height=h;stem_mesh.radial_segments=6
  var stem=w.kit.mesh(w.scene_root,stem_mesh,root+Vector3.UP*h*.5,w.palette.leaf);stem.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var blossom=w.kit.sphere(w.scene_root,root+Vector3.UP*h,.2,flower_materials[(index+j)%4]);blossom.scale=Vector3(1,.4,1);blossom.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;stats.flowers+=1
func climbing_garden(c: Vector2i):
 var entrance: Vector2i=neighbours(c)[0]-c;var inward=-Vector3(entrance.x,0,entrance.y);var side=Vector3(-inward.z,0,inward.x);var center=position(c)+inward*3
 var steps=[]
 for i in range(5):
  var h=.45+i*.65;var p=center+side*(i-2)*1.95+inward*(i*.2)
  w.block(p+Vector3.UP*(h-.2),Vector3(2.3,.4,1.5),w.palette.bark)
  var limb=w.kit.sphere(w.scene_root,p+Vector3.UP*(h-.18),1,w.palette.bark);limb.scale=Vector3(1.5,.23,.8)
  w.kit.branch(w.scene_root,center+inward*2+Vector3.UP*(h-.2),p+Vector3.UP*(h-.2),.18,w.palette.bark)
  steps.append(p+Vector3.UP*h)
 var root=center-side*3.8-inward
 w.block(root+Vector3.UP*.2,Vector3(2.2,.4,2.2),w.palette.rock)
 w.kit.branch(w.scene_root,center+inward*2+Vector3.UP*.1,center+inward*2+Vector3.UP*7,.65,w.palette.bark)
 w.block(center+inward*2+Vector3.UP*3.5,Vector3(1.1,7,1.1),w.palette.bark)
 vertical_sites.append({"entry":root,"steps":steps});stats.climbing_sites+=1
 flowers(center-inward*2,stats.climbing_sites)
func river(p: Vector3,size: Vector3):
 var water=w.block(p,size,water_material,false);water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func bridge(p: Vector3,east_west: bool):
 var length=9.0;var width=PATH_WIDTH+1
 w.block(p+Vector3.UP*.08,Vector3(length,.16,width) if east_west else Vector3(width,.16,length),w.palette.bark)
 for i in range(11):
  var offset=Vector3((i-5)*.8,0,0) if east_west else Vector3(0,0,(i-5)*.8)
  w.block(p+offset+Vector3.UP*.17,Vector3(.055,.025,width-.2) if east_west else Vector3(width-.2,.025,.055),w.kit.gold,false)
 for side in [-1,1]:
  var offset=Vector3(0,0,side*(width*.5+.35)) if east_west else Vector3(side*(width*.5+.35),0,0)
  w.block(p+offset+Vector3.UP*.65,Vector3(length,1.3,.25) if east_west else Vector3(.25,1.3,length),w.palette.bark)
 stats.bridges+=1
func near_checkpoint(p: Vector3,index: int) -> bool:
 if index<0 or index>=5 or absf(p.y)>5:return false
 return p.distance_to(approaches[index])<9 or p.distance_to(checkpoints[index])<10
func spawn_origins(wave: int) -> Array:
 var index=STAGES[clampi(wave,0,4)];var result=[]
 for offset in [0,1,2]:result.append(position(spine[mini(index+offset,spine.size()-1)]))
 return result

func trail_details():
 # Stable placement: variety without changing collision/navigation between clients.
 var debris=w.kit.material(Color("687c78"),.25)
 for i in range(spine.size()):
  if i%3==0 or STAGES.has(i) or i==spine.size()-1:continue
  var p=position(spine[i]);var side=-1 if i%2==0 else 1
  var edge=p+Vector3(side*7.2,0,2.8)
  match i%5:
   0:
    var stone=w.kit.sphere(w.scene_root,edge+Vector3.UP*.65,.9,w.palette.rock);stone.scale=Vector3(1.4,.8,1)
    w.kit.branch(w.scene_root,edge+Vector3(-.8,.2,1),edge+Vector3(1.2,.55,2),.2,w.palette.bark)
   1:
    w.block(edge+Vector3.UP*.5,Vector3(1.4,1,1),debris)
    for x in [-.5,.5]:w.block(edge+Vector3(x,.6,.53),Vector3(.08,1,.04),w.kit.gold,false)
   2:
    w.kit.cylinder(w.scene_root,edge+Vector3.UP*.4,.7,.8,w.palette.bark,true)
    flowers(edge+Vector3(0,0,1.5),i)
   3:
    w.block(edge+Vector3.UP*.8,Vector3(.18,1.6,.18),debris)
    var plate=w.block(edge+Vector3(0,1.4,.05),Vector3(1.2,.6,.1),w.palette.tower_copper,false);plate.rotation.z=.15
   4:
    for j in range(3):
     var mushroom=w.kit.sphere(w.scene_root,edge+Vector3(j*.45,.3,j*.3),.3,flower_materials[i%4]);mushroom.scale=Vector3(1,.35,1)
     w.kit.cylinder(w.scene_root,edge+Vector3(j*.45,.15,j*.3),.06,.3,w.palette.bark)
