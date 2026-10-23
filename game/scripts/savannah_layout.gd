class_name NestSavannahLayout
extends RefCounted
# Original dig settlement: offset courts, stepped mine route and a two-access overlook.
const ROOMS=[[-12,12,24,38],[-10,10,-28,26],[-36,-24,-12,30],[-38,-16,-28,-8],[-28,0,-8,0],[26,36,-12,30],[16,38,-28,-8],[0,30,4,12],[-28,30,-34,-26],[-10,10,-38,-28],[-30,-6,20,30],[6,32,20,30]]
static func material(id: String) -> StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_texture=load("res://assets/savannah/"+id+".png");m.normal_enabled=true;m.normal_texture=load("res://assets/savannah/"+id+"_normal.png");m.normal_scale=.35;m.roughness=.92;m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(.25,.25,.25);return m
static func shaft_open(p: Vector2) -> bool:
 return (p.x>=-34 and p.x<=-26 and p.y>=4 and p.y<=20) or (p.x>=26 and p.x<=34 and p.y>=-22 and p.y<=-6)
static func grid(a, rooms: Array, height: float, mine: bool=false) -> void:
 var cells={}
 for r in rooms:
  for x in range(r[0],r[1],2):
   for z in range(r[2],r[3],2):
    if not mine and shaft_open(Vector2(x+1,z+1)):continue
    cells[Vector2i(x,z)]=true
 # Merge floor strips and perimeter runs; retain collision without thousands of bodies.
 var rows={};var edges={}
 for c in cells:
  if not rows.has(c.y):rows[c.y]=[]
  rows[c.y].append(c.x)
  for d in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
   if cells.has(c+d):continue
   var p=Vector3(c.x+1+d.x*.5,height,c.y+1+d.y*.5)
   if shaft_open(Vector2(p.x,p.z)):continue
   var key=str(int(d.y!=0))+":"+str(p.z if d.y!=0 else p.x)
   if not edges.has(key):edges[key]=[]
   edges[key].append(c.x if d.y!=0 else c.y)
 for z in rows:
  var xs=rows[z];xs.sort();var first=int(xs[0]);var last=first
  for i in range(1,xs.size()+1):
   if i<xs.size() and xs[i]==last+2:last=int(xs[i]);continue
   a.floor_at((first+last+2)*.5,height,z+1,Vector2(last-first+2,2))
   if i<xs.size():first=int(xs[i]);last=first
 for key in edges:
  var xs=edges[key];xs.sort();var first=int(xs[0]);var last=first
  for i in range(1,xs.size()+1):
   if i<xs.size() and xs[i]==last+2:last=int(xs[i]);continue
   var along=key.begins_with("1:");var fixed=float(key.get_slice(":",1));var center=(first+last+2)*.5
   NestSanctuaryLayout.wall(a,Vector3(center,height,fixed) if along else Vector3(fixed,height,center),Vector2(last-first+2,.5) if along else Vector2(.5,last-first+2),3.7 if mine else 5.6)
   if i<xs.size():first=int(xs[i]);last=first
static func build(a: NestArena) -> void:
 var k=a.kit;k.stone=material("sandstone");var sand=material("sand");var ore=material("ore");var wood=material("timber");var metal=material("metal");metal.albedo_color=Color("8cb7af")
 a.bounds=Vector2(44,42);a.sites.assign([Vector3(-22,0,-1),Vector3(22,0,-1)]);a.ship_position=Vector3(8,0,33)
 var rooms=ROOMS.duplicate(true)
 rooms.append([-26,-16,-10,8]);rooms.append([16,26,-10,8])
 for room in ROOMS:rooms.append([-room[1],-room[0],-room[3]-2,-room[2]-2])
 grid(a,rooms,0)
 k.stone=ore
 grid(a,[[-34,-26,-2,6],[-28,-8,-2,6],[-10,10,-6,4],[8,28,-8,0],[26,34,-8,0]],-4,true)
 # The tunnel roof is the ground slab; portals and ramp slots are genuine openings.
 for r in [[-26,-10,-2,6],[-10,10,-6,4],[10,26,-8,0]]:
  k.box(a,Vector3((r[0]+r[1])*.5,-.8,(r[2]+r[3])*.5),Vector3(r[1]-r[0],.3,r[3]-r[2]),ore,true)
 k.stone=material("sandstone")
 a.up_route("",Vector3(-30,0,20),Vector3(-30,-4,4),6,false)
 a.up_route("",Vector3(30,-4,-6),Vector3(30,0,-22),6,false)
 # Timber mine supports are flush with the walls, not scattered through the lane.
 for x in [-24,-16,-8,0,8]:
  for z in [-1.5,5.5]:k.box(a,Vector3(x,-2,z),Vector3(.24,3.5,.24),wood)
  k.box(a,Vector3(x,-.95,2),Vector3(.3,.25,7.2),wood)
  k.box(a,Vector3(x,-1.4,5.4),Vector3(.12,.2,.2),k.lamp)
 for x in [-.6,.6]:k.box(a,Vector3(x,-3.97,1),Vector3(.07,.035,9),metal)
 # Both teams have a two-access overlook, with the same dimensions and height.
 for side in [-1,1]:
  var center=Vector3(8*side,3.8,11*side-1)
  a.floor_at(center.x,center.y,center.z,Vector2(12,12))
  a.floor_cover.append({"pos":Vector3(center.x,0,center.z),"size":Vector2(12,12)})
  a.up_route("",Vector3(8*side,0,29*side-1),Vector3(8*side,3.8,17*side-1),4.5,false)
  a.up_route("",Vector3(24*side,0,11*side-1),Vector3(14*side,3.8,11*side-1),4.5,false)
  for z in [-6,6]:NestSanctuaryLayout.wall(a,center+Vector3(-5*side,0,z),Vector2(2,.3),1)
 # Spawn baffles break all direct spawn-to-spawn sightlines, with wide exits on both sides.
 for z in [22,-24]:NestSanctuaryLayout.wall(a,Vector3(0,0,z),Vector2(12,.8),3.4)
 for p in [Vector3(-31,0,-22),Vector3(31,0,20),Vector3(-20,0,25),Vector3(20,0,-27)]:NestSanctuaryLayout.wall(a,p,Vector2(3,3),3.2)
 for p in [Vector3(-18,0,5),Vector3(18,0,-7)]:NestSanctuaryLayout.wall(a,p,Vector2(3,2),2.4)
 for p in [Vector3(-8,0,-3),Vector3(8,0,1)]:NestSanctuaryLayout.wall(a,p,Vector2(1.2,2),1.3)
 # A fractured solar engine gives the dig a silhouette of its own.
 for x in [-4,4]:
  NestSanctuaryLayout.wall(a,Vector3(x,0,-1),Vector2(.8,.8),7)
  k.box(a,Vector3(x,5,-1),Vector3(.95,.15,1),k.gold)
 var engine=Node3D.new();a.add_child(engine);engine.position=Vector3(0,6,-1);engine.rotation_degrees.x=90;k.ring(engine,Vector3.ZERO,3.5,k.gold)
 for side in [-1,1]:
  var z=33 if side==-1 else -35
  var team=0 if side==-1 else 1
  for x in [-4,-2,0,2,4]:a.spawns[team].append(Vector3(x,.08,-32 if team==1 else 30))
  a.flag_labels.append(k.label(a,Vector3(0,4,z),"FLAG",Color("dfc890")))
  a.flag_meshes.append(k.banner(a,Vector3(-8,0,z),k.green if team==0 else k.red))
 # Identical paired rifles near each team; specialist gun and Shield are contested.
 a.pads.assign([Vector3(-30,0,25),Vector3(30,0,-27),Vector3(31,0,15),Vector3(-31,0,-17),Vector3(-6,0,-1),Vector3(0,-4,-1),Vector3(8,3.8,10),Vector3(-8,3.8,-12),Vector3(6,0,-1),Vector3(0,0,-1)])
 a.pad_kinds=["ak47","ak47","plasma_auto","plasma_auto","shotgun","sniper","plasma_br","plasma_br","shotgun","overshield"]
 a.pad_names=["AK","AK","VOLT","VOLT","SHOTGUN","SNIPER","TRIAD","TRIAD","SHOTGUN","SHIELD"]
 # Equivalent physical cover opposite the extraction shuttle; no second scoring trigger.
 NestSanctuaryLayout.wall(a,Vector3(-8,0,-35),Vector2(4,6),2.5)
 scenery(a,sand,ore,wood,metal)
 a.set_meta("savannah_original",true)
static func scenery(a, sand: Material, ore: Material, wood: Material, metal: Material) -> void:
 var k=a.kit;var pale=k.material(Color("bc9374"));var leaves=k.material(Color("536044"))
 k.box(a,Vector3(0,-7,0),Vector3(1500,1,1500),sand)
 # Layered canyon replaces the separate distant mesa props.
 NestSavannahCanyon.build(a)
 # Acacia canopies and branching trunks, placed beyond playable walls.
 for p in [Vector3(-43,0,18),Vector3(42,0,7),Vector3(-15,0,43),Vector3(28,0,37),Vector3(45,0,-29)]:
  k.branch(a,p,p+Vector3(.7,5,0),.18,wood)
  for i in range(4):
   var end=p+Vector3(sin(i*2.3)*2.5,5.3+i*.18,cos(i*2.3)*2)
   k.branch(a,p+Vector3(.5,3.4,0),end,.08,wood)
   var crown=k.sphere(a,end,1.5,leaves);crown.scale=Vector3(1.5,.22,1.2)
 # Buttresses, broken lintels and inset metalwork give each court a strong silhouette.
 for x in [-38,38]:
  for z in [-26,-18,-10]:
   k.box(a,Vector3(x,3,z),Vector3(1,6,1.5),pale)
   k.box(a,Vector3(x,5.7,z),Vector3(1.4,.22,1.8),k.gold)
   k.box(a,Vector3(x,2,z),Vector3(1.05,.1,1.55),metal)
 for p in [Vector3(-30,0,-8),Vector3(31,0,-8),Vector3(0,0,-28)]:
  for side in [-1,1]:
   k.box(a,p+Vector3(side*3.8,3.3,0),Vector3(.7,6.6,.8),pale)
   k.box(a,p+Vector3(side*3.8,5.3,0),Vector3(.8,.1,.9),k.gold)
  k.box(a,p+Vector3(0,6.1,0),Vector3(8.4,.7,1),pale)
 # Recessed mining cart; collision footprint is included in navigation.
 var cart=Vector3(-5,-4,-4)
 k.box(a,cart+Vector3(0,.7,0),Vector3(2,1.2,1.4),metal,true)
 a.floor_cover.append({"pos":cart,"size":Vector2(2,1.4)})
 for dx in [-.7,.7]:
  for dz in [-.6,.6]:k.sphere(a,cart+Vector3(dx,.25,dz),.25,metal)
 for dx in [-.4,.2,.6]:k.sphere(a,cart+Vector3(dx,1.4,0),.28,ore)
 # Cloth shade and an abandoned hoist identify the working excavation.
 var canvas=k.material(Color("af795f"));canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
 for x in [-32,32]:
  var shade=SurfaceTool.new();shade.begin(Mesh.PRIMITIVE_TRIANGLES)
  var corners=[Vector3(x-4,6,-25),Vector3(x+4,6,-25),Vector3(x-4,5.3,-14),Vector3(x+4,5.3,-14)]
  for index in [0,2,1,1,2,3]:shade.add_vertex(corners[index])
  shade.generate_normals();var fabric=MeshInstance3D.new();fabric.mesh=shade.commit();fabric.material_override=canvas;a.add_child(fabric)
  for p in corners:k.branch(a,p,p+Vector3(0,1,0),.04,metal)
 var hoist=Vector3(-36,0,11)
 for dx in [-1,1]:
  for dz in [-2,2]:k.branch(a,hoist+Vector3(dx*2,0,dz),hoist+Vector3(dx*1.1,11,dz*.6),.16,metal)
 for y in [3,6,9]:
  k.box(a,hoist+Vector3(0,y,0),Vector3(3.5,.15,4.2),metal)
 k.box(a,hoist+Vector3(0,11,0),Vector3(3,.4,4),wood)
 k.branch(a,hoist+Vector3(0,1,0),hoist+Vector3(0,11,0),.025,metal)
 # Recessed wall courses and geometric bronze panels stay flush with collision.
 for side in [-1,1]:
  for z in [-20,-4,12,28]:
   var wall_x=38*side
   k.box(a,Vector3(wall_x,2,z),Vector3(.04,2,1.4),metal)
   for offset in [-.5,0,.5]:k.box(a,Vector3(wall_x-side*.03,2,z+offset),Vector3(.04,1.8,.045),k.gold)
  # A coiled cable and ore bins sit on a raised plinth beyond the perimeter.
  var p=Vector3(side*42,0,side*18)
  k.box(a,p+Vector3(0,.15,0),Vector3(3,.3,2),pale)
  k.box(a,p+Vector3(0,.8,0),Vector3(1.8,1,1.1),wood)
  for dx in [-.6,0,.6]:k.sphere(a,p+Vector3(dx,1.35,0),.25,ore)
  k.ring(a,p+Vector3(1,.35,0),.5,metal)
 # Strata ledges and small ore exposures enrich the mine without narrowing its walkway.
 for x in [-22,-14,14,22]:
  k.box(a,Vector3(x,-2.5,-1.72 if x<0 else -7.72),Vector3(1.5,.08,.04),k.gold)
  k.box(a,Vector3(x,-1.45,-1.72 if x<0 else -7.72),Vector3(2.5,.08,.04),wood)
 # Flush shaft edge bands communicate the drop without introducing snagging collision.
 for side in [-1,1]:
  var center=Vector3(30*side,.025,-1-12*side)
  for dx in [-4,4]:k.box(a,center+Vector3(dx,0,0),Vector3(.14,.035,16),metal)
  # Three bronze strokes form an original Nest/dig emblem on each outside wall.
  var face=Vector3(37.7*side,2.5,-1-2*side)
  for pair in [[Vector3(0,.9,0),Vector3(0,-.65,-.8)],[Vector3(0,-.65,-.8),Vector3(0,-.65,.8)],[Vector3(0,-.65,.8),Vector3(0,.9,0)]]:
   k.branch(a,face+pair[0],face+pair[1],.035,k.gold)
 NestSavannahCanyon.trim(a,metal)
 # Muted work lamps illuminate shafts without costly dynamic shadows.
 for p in [Vector3(-20,-1.8,2),Vector3(0,-1.8,2),Vector3(22,-1.8,-5)]:
  var light=OmniLight3D.new();light.position=p;light.light_color=Color("e6c38f");light.light_energy=.65;light.omni_range=9;light.shadow_enabled=false;a.add_child(light)
