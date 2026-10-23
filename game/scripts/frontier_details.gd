class_name NestFrontierDetails
extends RefCounted
static func rock(a,p: Vector3,size: Vector3,material: Material,seed_value: int) -> void:
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings=[]
 for level in range(5):
  var ring=[];var taper=[.85,1.,.88,.67,.35][level]
  for i in range(10):
   var angle=i*TAU/10.;var radius=taper*rng.randf_range(.82,1.18)
   ring.append(Vector3(sin(angle)*size.x*radius,level*size.y*.25+rng.randf_range(-.35,.35),cos(angle)*size.z*radius))
  rings.append(ring)
 for level in range(4):
  for i in range(10):
   var j=(i+1)%10
   for vertex in [rings[level][i],rings[level+1][i],rings[level][j],rings[level][j],rings[level+1][i],rings[level+1][j]]:st.add_vertex(vertex)
 for i in range(10):
  for vertex in [Vector3(0,size.y,0),rings[4][i],rings[4][(i+1)%10]]:st.add_vertex(vertex)
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material;mesh.position=p;a.add_child(mesh)
static func leaves(a,p: Vector3,radius: Vector3,count: int,seed_value: int,pale: bool=false) -> void:
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 var entries=a.get_meta("frontier_leaf_instances",[])
 a.set_meta("frontier_leaf_sources",int(a.get_meta("frontier_leaf_sources",0))+1)
 for i in range(count):
  var angle=rng.randf()*TAU;var r=sqrt(rng.randf());var pos=p+Vector3(cos(angle)*r*radius.x,rng.randf_range(-1,1)*radius.y,sin(angle)*r*radius.z)
  var basis=Basis.from_euler(Vector3(rng.randf_range(-1.5,1.5),rng.randf()*TAU,rng.randf_range(-1.,1.))).scaled(Vector3.ONE*rng.randf_range(.55,1.15))
  var color=Color("3a572b").lerp(Color("87915a") if pale else Color("6f8343"),rng.randf())
  entries.append({"pose":Transform3D(basis,pos),"color":color})
 a.set_meta("frontier_leaf_instances",entries)
static func tree(a,p: Vector3,height: float,pale: bool=false) -> void:
 var k=a.kit;var bark=NestFrontierMaps.mat(a,"776a53",0,"soil");var seed_value=int(p.x*100+p.z*31+height*227)
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 var bend=Vector3(.45,height*.48,.25)
 k.branch(a,p,p+bend,height*.065,bark);k.branch(a,p+bend,p+Vector3(-.15,height*.82,.4),height*.042,bark)
 for i in range(7):
  var angle=i*2.399;var end=p+Vector3(sin(angle)*height*.34,height*(.67+.04*(i%4)),cos(angle)*height*.34)
  k.branch(a,p+bend,end,height*.012,bark)
  var tip=end+Vector3(sin(angle+.4)*height*.07,height*.08,cos(angle+.4)*height*.07)
  k.branch(a,end,tip,height*.006,bark)
  leaves(a,tip,Vector3(height*.23,height*.14,height*.22),80,seed_value+i*7,pale)
 # Broad roots are purely visual and always inside the authored planter or beyond walls.
 for i in range(4):
  var angle=i*TAU/4;k.branch(a,p+Vector3(0,.45,0),p+Vector3(sin(angle)*height*.12,.08,cos(angle)*height*.12),height*.018,bark)
static func arch(a,p: Vector3,width: float,height: float,turned: bool=false) -> void:
 var k=a.kit;var node=Node3D.new();a.add_child(node);node.position=p
 if turned:node.rotation.y=PI*.5
 var radius=width*.5
 for i in range(13):
  var angle=float(i)*PI/12
  var stone=k.box(node,Vector3(cos(angle)*(radius+.45),height-radius+sin(angle)*(radius+.45),0),Vector3(.85,1.05,1.8),k.stone)
  stone.rotation.z=angle-PI*.5
  var edge=k.box(node,Vector3(cos(angle)*(radius+.45),height-radius+sin(angle)*(radius+.45),-.94),Vector3(.78,.085,.08),k.gold);edge.rotation.z=angle
static func stairs_trim(a,start: Vector3,end: Vector3,width: float) -> void:
 var count=ceili(start.distance_to(end)/.85)
 for i in range(1,count):
  var t=float(i)/count;var p=start.lerp(end,t)+Vector3(0,.027,0)
  a.kit.box(a,p,Vector3(width,.035,.12) if abs(start.z-end.z)>abs(start.x-end.x) else Vector3(.12,.035,width),a.kit.gold)
static func roof(a) -> void:
 var k=a.kit
 for x in [-10,10]:
  for z in [-10,10]:NestFrontierMaps.pillar(a,Vector3(x,0,z),11.5,.75)
 for side in [-1,1]:
  k.box(a,Vector3(0,11.3,10*side),Vector3(23,.75,2),k.stone)
  k.box(a,Vector3(10*side,11.3,0),Vector3(2,.75,23),k.stone)
  k.box(a,Vector3(0,11.8,10*side),Vector3(23,.14,2.25),k.gold)
  k.box(a,Vector3(10*side,11.8,0),Vector3(2.25,.14,23),k.gold)
  # Broken sloping roof leaves a bright central oculus; no hidden ceiling collisions.
  for axis in [0,1]:
   var mesh=k.box(a,Vector3(0,12.5,7*side) if axis==0 else Vector3(7*side,12.5,0),Vector3(20,.5,5) if axis==0 else Vector3(5,.5,20),k.stone)
   if axis==0:mesh.rotation.x=-side*.24
   else:mesh.rotation.z=side*.24
  for x in range(-8,9,2):
   k.box(a,Vector3(x,10.7,10*side),Vector3(.5,.5,2.1),k.gold)
  for path in a.up_routes:
   if sign(path.start.x+path.start.z)==side:stairs_trim(a,path.start,path.end,path.width)
static func extra(a) -> void:
 var k=a.kit
 if a.map_selection==3:
  var plate=NestFrontierMaps.mat(a,"8d9d9d",.3,"dark_alloy");var energy=NestFrontierMaps.glow(a,"57ab9f")
  for side in [-1,1]:
   for z in [7,12,17]:
    for x in [-20,-8]:
     var brace=k.box(a,Vector3(x*side,2.6,z*side),Vector3(.6,5.2,.75),plate);brace.rotation.z=side*.14
   for x in [-19,-15,-11]:
    NestFrontierMaps.panel(a,Vector3(x*side,2.7,4.9*side),Vector2(2.6,3.1))
   # Failed conduits are flush inside a raised service edge, never across a walking lane.
   for z in [-20,20]:
    for i in range(3):k.box(a,Vector3(side*(22+i*.4),.11,z),Vector3(.15,.2,7),energy)
  var basalt=NestFrontierMaps.mat(a,"40535c",0,"slate")
  for i in range(18):
   var angle=i*TAU/18;rock(a,Vector3(sin(angle)*73,-14,cos(angle)*68),Vector3(7+(i%3),24+(i%4)*5,8),basalt,100+i)
 elif a.map_selection==4:
  var water=NestFrontierMaps.water_material(a)
  for side in [-1,1]:
   for z in [-14,14]:
    var basin=Vector3(-25*side,0,z)
    NestFrontierMaps.solid(a,basin,Vector2(5,3),.8)
    k.box(a,basin+Vector3(0,.83,0),Vector3(4.6,.05,2.6),water)
   for z in [-30,-18,-6,6,18,30]:
    # Carved arcade crowns form a rhythm behind the outer combat route.
    arch(a,Vector3(37*side,0,z),5.5,8.2,true)
  var pale=NestFrontierMaps.mat(a,"bcc6b0",0,"garden_stone")
  for i in range(16):
   var angle=i*TAU/16;rock(a,Vector3(sin(angle)*72,-19,cos(angle)*66),Vector3(9,27+(i%4)*3,9),pale,200+i)
 else:
  roof(a)
  for side in [-1,1]:
   arch(a,Vector3(28*side,0,0),9,8.2,true)
   for z in [-24,-12,0,12,24]:arch(a,Vector3(37*side,0,z),7,9.3,true)
  var cliff=NestFrontierMaps.mat(a,"778a71",0,"cliff")
  for i in range(20):
   var angle=i*TAU/20;rock(a,Vector3(sin(angle)*72,-16,cos(angle)*69),Vector3(10,26+(i%5)*4,9),cliff,300+i)
static func leaf_geometry() -> ArrayMesh:
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
 for row in range(5):
  var t=float(row)/4.;var width=sin(t*PI)*.22
  for column in [-1,0,1]:
   vertices.append(Vector3(column*width,.025*sin(t*PI) if column==0 else 0,t-.5));normals.append(Vector3.UP);uv.append(Vector2((column+1)*.5,t))
 for row in range(4):
  for col in range(2):
   var i=row*3+col;indices.append_array(PackedInt32Array([i,i+3,i+1,i+1,i+3,i+4]))
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
static func batch_foliage(a) -> void:
 # CPU-authored transforms work identically with the headless and real renderers.
 # Never read uncommitted MultiMesh GPU state back to build gameplay assets.
 var groups={};var entries=a.get_meta("frontier_leaf_instances",[])
 for item in entries:
  var p=item.pose.origin;var key=Vector3i(floori(p.x/18),floori(p.y/12),floori(p.z/18))
  if not groups.has(key):groups[key]=[]
  groups[key].append(item)
 for items in groups.values():
  var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=a.kit.leaf_mesh;multi.instance_count=items.size()
  for i in range(items.size()):multi.set_instance_transform(i,items[i].pose);multi.set_instance_color(i,items[i].color)
  var node=MultiMeshInstance3D.new();node.name="BatchedGardenFoliage";node.multimesh=multi;node.material_override=a.kit.foliage;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=145;a.add_child(node)
 a.set_meta("frontier_foliage",{"before":a.get_meta("frontier_leaf_sources",0),"draw_groups":groups.size(),"leaves":entries.size()})
 if a.has_meta("frontier_leaf_instances"):a.remove_meta("frontier_leaf_instances")
