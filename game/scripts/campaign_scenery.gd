class_name NestCampaignScenery
extends RefCounted
# Shared palette and modular props; everything fixed participates in world batching.
var w
var rng=RandomNumberGenerator.new()
var copper: Material
var teal: Material
var glass: Material
var moss: Material
var wood: Material
var rust: Material
var stats={"mountain_chunks":0,"structures":0,"cargo":0,"props":0}
func _init(world):
 w=world;rng.seed=810271 if w.region=="preparation" else 810272
 copper=w.kit.material(Color("a76c48"),.45);teal=w.kit.material(Color("397e83"),.35)
 glass=w.kit.material(Color("244c63"),.72);glass.roughness=.24
 moss=w.kit.material(Color("63794d"));wood=w.kit.material(Color("9b7850"));rust=w.kit.material(Color("85533b"),.15)
func box(p: Vector3,size: Vector3,mat: Material,solid=false) -> Node3D:return w.block(p,size,mat,solid)
func tube(p: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
 var shape=CylinderMesh.new();shape.radial_segments=12;shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height
 return w.kit.mesh(w.scene_root,shape,p,mat)
func ring(p: Vector3,radius: float,thickness: float,mat: Material) -> MeshInstance3D:
 var shape=TorusMesh.new();shape.inner_radius=radius-thickness;shape.outer_radius=radius+thickness;shape.rings=16;shape.ring_segments=4
 return w.kit.mesh(w.scene_root,shape,p,mat)
func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color):
 var normal=(b-a).cross(c-a).normalized()
 for p in [a,b,c]:tool.set_normal(normal);tool.set_color(color.srgb_to_linear());tool.add_vertex(p)
func mountain_range():
 var material=w.kit.material(Color.WHITE);material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1
 var city=w.region=="preparation"
 for layer in range(3):
  var inner=(125.0 if city else 205.0)+layer*64;var outer=inner+90
  var dark=Color("504b61") if city else Color("3c5158")
  var light=Color("aa8469") if city else Color("81948a")
  dark=dark.lerp(Color("6c7280"),layer*.12);light=light.lerp(Color("afb7ac"),layer*.15)
  for chunk in range(12):
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   for part in range(3):
    var index=chunk*3+part;var a=index*TAU/36.0;var b=(index+1)*TAU/36.0
    var ridge_a=15+layer*20+absf(sin(a*3.0+layer*1.7))*25+sin(a*7.0)*6
    var ridge_b=15+layer*20+absf(sin(b*3.0+layer*1.7))*25+sin(b*7.0)*6
    var shoulder_a=Vector3(cos(a)*(inner+26),ridge_a,sin(a)*(inner+26));var shoulder_b=Vector3(cos(b)*(inner+26),ridge_b,sin(b)*(inner+26))
    var low_a=Vector3(cos(a)*inner,-5,sin(a)*inner);var low_b=Vector3(cos(b)*inner,-5,sin(b)*inner)
    var back_a=Vector3(cos(a)*outer,-12,sin(a)*outer);var back_b=Vector3(cos(b)*outer,-12,sin(b)*outer)
    var tint=dark.lerp(light,.22+absf(sin(index*2.31))*.4)
    triangle(tool,low_a,shoulder_a,low_b,tint);triangle(tool,low_b,shoulder_a,shoulder_b,tint.lightened(.07))
    triangle(tool,shoulder_a,back_a,shoulder_b,tint.darkened(.12));triangle(tool,shoulder_b,back_a,back_b,tint.darkened(.2))
    var snow_a=shoulder_a.lerp(low_a,.22);var snow_b=shoulder_b.lerp(low_b,.22)
    if ridge_a>41:
     triangle(tool,shoulder_a,snow_a,shoulder_b,light.lightened(.16));triangle(tool,shoulder_b,snow_a,snow_b,light)
   var node=w.kit.mesh(w.scene_root,tool.commit(),Vector3.ZERO,material);node.name="DistantMountainRidge";node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   stats.mountain_chunks+=1
func cargo(p: Vector3,color: Material,index: int,solid=true):
 box(p+Vector3(0,.75,0),Vector3(1.9,1.5,1.5),color,solid)
 for x in [-.82,.82]:box(p+Vector3(x,.75,.77),Vector3(.09,1.52,.06),w.kit.dark)
 for y in [.15,1.35]:box(p+Vector3(0,y,.78),Vector3(1.8,.08,.06),copper)
 box(p+Vector3(0,.85,.79),Vector3(.55,.22,.025),w.kit.dark)
 for j in range(1+index%3):box(p+Vector3(-.18+j*.16,.85,.81),Vector3(.055,.12,.02),w.kit.gold)
 box(p+Vector3(0,1.54,0),Vector3(.2,.07,1.5),w.kit.dark)
 stats.cargo+=1
func workbench(p: Vector3):
 box(p+Vector3(0,.9,0),Vector3(2.1,.16,.95),w.palette.hull,true)
 for x in [-.85,.85]:box(p+Vector3(x,.43,0),Vector3(.14,.86,.7),w.kit.dark,true)
 box(p+Vector3(-.5,1.08,0),Vector3(.55,.2,.45),teal)
 box(p+Vector3(.55,1.04,.05),Vector3(.6,.08,.13),copper)
 box(p+Vector3(.77,1.09,.05),Vector3(.16,.16,.25),w.kit.dark)
 var coil=ring(p+Vector3(.15,1.1,-.2),.24,.05,w.kit.dark);coil.rotation.x=PI*.5
 stats.props+=1
func shelter(p: Vector3):
 var wall=w.palette.tower_teal
 for x in [-5.5,5.5]:box(p+Vector3(x,2.6,-1),Vector3(.5,5.2,11),wall,true)
 box(p+Vector3(0,2.6,-6.4),Vector3(11.5,5.2,.5),w.palette.hull,true)
 box(p+Vector3(0,5.4,-1),Vector3(12,.35,12),w.palette.panel,true)
 for x in [-5.5,5.5]:
  box(p+Vector3(x,3.2,4.8),Vector3(.7,6.4,.7),copper,true)
  box(p+Vector3(x,5.8,-1),Vector3(.4,.3,12),w.kit.gold)
 box(p+Vector3(0,6.2,4.8),Vector3(12,.7,.7),w.kit.dark)
 for i in range(4):box(p+Vector3(-4.5+i*3,4.4,-6.08),Vector3(1.8,1.0,.06),glass)
 cargo(p+Vector3(-3,0,-4),teal,1);cargo(p+Vector3(0,0,-4),copper,2)
 workbench(p+Vector3(3,0,-4))
 for x in [-4,4]:box(p+Vector3(x,.04,1),Vector3(.15,.05,7),w.kit.gold)
 stats.structures+=1
func dish(p: Vector3):
 box(p+Vector3(0,2,0),Vector3(8,4,7),w.palette.tower_slate,true)
 tube(p+Vector3(0,5.3,0),.35,2.6,copper)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(16):
  var a=i*TAU/16;var b=(i+1)*TAU/16
  for j in range(3):
   var r0=j*1.2;var r1=(j+1)*1.2
   var a0=Vector3(cos(a)*r0,r0*r0*.07,sin(a)*r0);var a1=Vector3(cos(a)*r1,r1*r1*.07,sin(a)*r1)
   var b0=Vector3(cos(b)*r0,r0*r0*.07,sin(b)*r0);var b1=Vector3(cos(b)*r1,r1*r1*.07,sin(b)*r1)
   triangle(tool,a0,b1,a1,Color.WHITE);triangle(tool,a0,b0,b1,Color.WHITE)
 var dish_material=w.kit.material(Color("8ea8a6"),.6);dish_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 var bowl=w.kit.mesh(w.scene_root,tool.commit(),p+Vector3(0,6.2,0),dish_material);bowl.rotation_degrees=Vector3(-25,0,12)
 w.kit.branch(w.scene_root,p+Vector3(-2,7,0),p+Vector3(0,9.2,0),.055,copper)
 w.kit.branch(w.scene_root,p+Vector3(2,7,0),p+Vector3(0,9.2,0),.055,copper)
 tube(p+Vector3(0,9.2,0),.17,.5,w.kit.dark)
 for x in [-2.5,2.5]:box(p+Vector3(x,2.8,3.55),Vector3(1.5,1.4,.06),glass)
 stats.structures+=1
func elevated_transit():
 for x in [-28,-9,10,29]:
  box(Vector3(x,3,-36),Vector3(1.2,6,2.5),w.palette.tower_copper,true)
  box(Vector3(x,5.5,-36),Vector3(4,.5,4),copper)
 box(Vector3(0,6.2,-36),Vector3(65,.65,4.8),w.palette.hull,true)
 for z in [-38,-34]:box(Vector3(0,7.1,z),Vector3(65,.12,.12),copper)
 for x in range(-30,31,6):
  for z in [-38,-34]:box(Vector3(x,6.7,z),Vector3(.1,.9,.1),w.kit.dark)
 for x in [-18,-11,12]:
  box(Vector3(x,7.3,-36),Vector3(5.8,1.6,3.4),teal)
  box(Vector3(x,8.15,-36),Vector3(5.2,.15,3),w.palette.panel)
  box(Vector3(x,7.6,-34.25),Vector3(4.6,.65,.06),glass)
  for side in [-1,1]:box(Vector3(x+side*2.3,6.45,-36),Vector3(.7,.6,2.4),w.kit.dark)
 stats.structures+=1
func city():
 mountain_range();shelter(Vector3(43,0,-20));shelter(Vector3(-45,0,31));dish(Vector3(-51,0,-24));elevated_transit()
 # The departure deck sits above a broad valley, rather than a black horizon gap.
 var basin=w.kit.material(Color("66545a"));w.kit.cylinder(w.scene_root,Vector3(0,-30,0),430,12,basin)
 box(Vector3(0,-8.5,0),Vector3(147,16,137),w.palette.rock)
 for i in range(8):
  var p=Vector3(29+(i%2)*2.2,0,24+floori(i/2.0)*2.3)
  cargo(p,[teal,copper,w.palette.tower_slate][i%3],i)
 for i in range(4):cargo(Vector3(-29+i%2*2.2,0,-19-floori(i/2.0)*2),w.palette.hull,i)
 workbench(Vector3(-17,0,10));workbench(Vector3(10,0,5))
 # Clinic face dressing stays on the original building collider; it is not a new door.
 for x in [-36.7,-31.3]:box(Vector3(x,2.2,-1.96),Vector3(2,1.2,.06),glass)
 box(Vector3(-34,2.7,-1.91),Vector3(.35,1.4,.09),teal);box(Vector3(-34,2.7,-1.85),Vector3(1.3,.35,.09),teal)
 for x in [-38.5,-29.5]:box(Vector3(x,3.85,-7),Vector3(.25,.2,9.5),copper)
 # A low docking cradle frames the ship without entering the boarding corridor.
 for x in [-26,23]:
  box(Vector3(x,.5,-20),Vector3(1.2,1,7),w.kit.dark,true)
  for z in [-22,-18]:tube(Vector3(x,1.2,z),.35,1.4,copper)
 for p in [Vector3(-22,.05,-1),Vector3(13,.05,20),Vector3(28,.05,-4)]:
  for i in range(3):box(p+Vector3(i*.35,0,0),Vector3(.14,.04,1.7),w.kit.gold)
 cabin(Vector3(-2,0,-17))
 w.set_meta("landscape_stats",stats)
func cabin(origin: Vector3):
 var previous=w.scene_root;w.scene_root=w.ship_root
 # Wide continuous ramp gives the open hatch a readable, snag-free physical approach.
 var a=origin+Vector3(-2,.015,12);var b=origin+Vector3(2,.015,12);var d=origin+Vector3(-2,.245,9.2);var e=origin+Vector3(2,.245,9.2)
 var ramp=SurfaceTool.new();ramp.begin(Mesh.PRIMITIVE_TRIANGLES);triangle(ramp,a,d,b,Color.WHITE);triangle(ramp,b,d,e,Color.WHITE)
 w.kit.mesh(w.scene_root,ramp.commit(),Vector3.ZERO,w.palette.hull)
 var body=StaticBody3D.new();body.name="BoardingRamp";body.collision_layer=1;body.collision_mask=2;w.scene_root.add_child(body)
 var shape=ConvexPolygonShape3D.new();shape.points=PackedVector3Array([a,b,d,e,a-Vector3.UP*.08,b-Vector3.UP*.08,d-Vector3.UP*.08,e-Vector3.UP*.08]);var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
 for z in [-5,-1,3]:
  for x in [-4,4]:
   box(origin+Vector3(x,1.16,z+.42),Vector3(.9,.75,.12),teal)
   box(origin+Vector3(x,1.18,z+.5),Vector3(.09,.7,.025),copper)
 for x in [-2,2]:
  box(origin+Vector3(x,3.61,-2),Vector3(.35,.12,10),w.kit.dark)
  for z in [-5,0,3]:box(origin+Vector3(x,3.5,z),Vector3(.22,.04,.5),w.kit.lamp)
 for x in [-2,0,2]:
  box(origin+Vector3(x,1.3,-8.95),Vector3(1.6,.65,.2),w.kit.dark)
  box(origin+Vector3(x,1.36,-8.82),Vector3(1.3,.3,.04),glass)
 for z in [2,4,6]:
  for side in [-1,1]:
   var paint=box(origin+Vector3(side*.45,.275,z),Vector3(.65,.025,.12),w.kit.gold);paint.rotation.y=side*.6
 w.scene_root=previous
func ancient_arch(p: Vector3,width: float,height: float,broken=false):
 var stone=w.palette.rock
 for side in [-1,1]:
  box(p+Vector3(side*width*.5,height*.5,0),Vector3(1.8,height,2.6),stone)
  box(p+Vector3(side*width*.5,1,0),Vector3(2.3,2,3),moss)
 for i in range(9):
  if broken and i in [3,4,5]:continue
  var a=(i+.5)*PI/9
  var block=box(p+Vector3(cos(a)*width*.5,height+sin(a)*width*.5,0),Vector3(width*PI/18+.1,1.3,2.4),stone);block.rotation.z=a+PI*.5
 for side in [-1,1]:box(p+Vector3(side*width*.5,height*.6,1.32),Vector3(.09,height*.65,.04),copper)
 stats.structures+=1
func conifer(p: Vector3,height: float,dead=false):
 tube(p+Vector3(0,height*.5,0),.65,height,w.palette.bark)
 if dead:
  for i in range(5):w.kit.branch(w.scene_root,p+Vector3(0,height*(.35+i*.1),0),p+Vector3(sin(i*2.4)*4,height*(.43+i*.1),cos(i*2.4)*4),.18,w.palette.bark)
 else:
  for i in range(4):
   var cone=CylinderMesh.new();cone.top_radius=.15;cone.bottom_radius=5.2-i*.85;cone.height=7.5;cone.radial_segments=9
   var mesh=w.kit.mesh(w.scene_root,cone,p+Vector3(0,height-9+i*2.4,0),w.palette.leaf);mesh.rotation.y=i*.7
 stats.props+=1
func forest():
 mountain_range()
 for i in range(7):ancient_arch(Vector3(-100+i*35,0,-165),9,8+i%3,i in [1,4])
 ancient_arch(Vector3(-165,0,8),12,11,true);ancient_arch(Vector3(180,0,-12),10,9)
 for i in range(20):
  var a=i*TAU/20+.19;var radius=174+float(i%3)*9
  conifer(Vector3(cos(a)*radius,0,sin(a)*radius),rng.randf_range(16,28),i%4==0)
 for side in [-1,1]:
  for i in range(6):
   var rock=w.kit.sphere(w.scene_root,Vector3(side*(169+rng.randf_range(0,7)),4+i%3*2,-90+i*35),5.2,w.palette.rock);rock.scale=Vector3(1.2,1.3+i%3*.3,1.4);rock.rotation.z=side*.2
 # Supply crates are recognizable up close; dressing does not add a second pickup.
 for id in ["ammo0","ammo1","ammo2","weapon"]:
  var p=w.locations[id]
  for x in [-.39,.39]:box(p+Vector3(x,.75,.37),Vector3(.07,1.3,.04),copper)
  box(p+Vector3(0,1.56,0),Vector3(.8,.12,.55),teal)
  for j in range(4):box(p+Vector3(-.3+j*.2,1.67,0),Vector3(.1,.1,.35),w.kit.gold)
 # A broken sensor mast, readable red emergency hardware and scorched hull plates.
 var previous=w.scene_root;w.scene_root=w.ship_root
 var warning=w.kit.material(Color("a54435"),.25)
 for p in [Vector3(-4,1.6,5),Vector3(4,1.6,4)]:box(p,Vector3(.55,.22,.1),warning)
 w.kit.branch(w.scene_root,Vector3(0,3.95,4),Vector3(2.4,5.6,5),.09,w.kit.dark)
 ring(Vector3(2.4,5.6,5),.5,.06,copper).rotation.x=PI*.5
 w.scene_root=previous
 cabin(Vector3(0,0,9))
 w.set_meta("landscape_stats",stats)
