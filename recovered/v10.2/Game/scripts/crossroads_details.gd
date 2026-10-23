class_name NestCrossroadsDetails
extends RefCounted
static func wall_opening(along_x: bool,fixed: float,cell: int) -> bool:
 if along_x:return false
 return (is_equal_approx(fixed,-36) and (cell in range(0,6,2) or cell in range(18,24,2))) or (is_equal_approx(fixed,34) and cell in range(2,8,2)) or (is_equal_approx(fixed,36) and cell in range(-16,-10,2))
static func build(a: NestArena) -> void:
 var k=a.kit
 # Two low exterior alleys make deliberate edge drops safe; ramps return to play.
 a.floor_at(-39,-2.4,3,Vector2(6,42));a.floor_at(39,-2.4,2,Vector2(6,40))
 a.floor_at(35,0,5,Vector2(2,6))
 # Continuous lower retaining walls close the gap under the street slabs.
 a.floor_at(35,-2.4,6,Vector2(2,32))
 a.floor_cover.append({"pos":Vector3(35,-2.4,5),"size":Vector2(2,6)})
 for spec in [[-36,3,.6,42],[36,-14,.6,8],[34,6,.6,32],[35,-10,2,.6]]:
  NestSanctuaryLayout.wall(a,Vector3(spec[0],-2.4,spec[1]),Vector2(spec[2],spec[3]),2.4)
 for spec in [[-42,-2.4,3,.5,42,9.5],[42,-2.4,2,.5,40,9.5],[-39,-2.4,-18,6,.45,1.25],[-39,-2.4,24,6,.45,1.25],[39,-2.4,-18,6,.45,1.25],[39,-2.4,22,6,.45,1.25]]:
  NestSanctuaryLayout.wall(a,Vector3(spec[0],spec[1],spec[2]),Vector2(spec[3],spec[4]),spec[5])
 a.up_route("SUN ALLEY RETURN",Vector3(-41,-2.4,21),Vector3(-36,0,21),3.2)
 a.up_route("MOON ALLEY RETURN",Vector3(41,-2.4,-13),Vector3(36,0,-13),3.2)
 # Visible upper lintels frame the openings; they never cap a standing route.
 for spec in [[-36,3,6],[-36,21,6],[34,5,6],[36,-13,6]]:
  k.box(a,Vector3(spec[0],6.6,spec[1]),Vector3(.6,6.0,spec[2]),k.stone,true)
 a.set_meta("crossroads_safe_drops",[
  {"name":"SUN ALLEY","start":Vector3(-35.1,0,3),"landing":Vector3(-39,-2.4,3),"exit":Vector3(-33.5,0,21)},
  {"name":"MOON ALLEY","start":Vector3(35.1,0,5),"landing":Vector3(39,-2.4,5),"exit":Vector3(33.5,0,-13)}])
 # Open-front balconies provide height/oblique angles with safe ground underneath.
 balcony(a,"SUN EXCHANGE",Vector3(-33,2.8,-24),Vector3(-33,0,-12),Vector3(-33,2.8,-20))
 balcony(a,"MOON GALLERY",Vector3(33,2.8,-25),Vector3(33,0,-13),Vector3(33,2.8,-21))
 a.set_meta("crossroads_balcony_drops",[
  {"start":Vector3(-31,2.8,-26),"landing":Vector3(-29.0,0,-26)},
  {"start":Vector3(31,2.8,-25),"landing":Vector3(28.8,0,-25)}])
 # Sparse cover: staggered heights and clear sides rather than a field of crates.
 for item in [[-12,22,3.2,1.5,1.35],[14,22,3.2,1.5,1.35],[0,24,2.6,1.6,1.2],[-34,2,3,2,2.9],[-28,15,2.5,2,1.5],[-20,1,2.2,2,1.3],[-1.5,12,2.6,1.8,1.35],[31,-3,2.0,2.2,1.45]]:
  NestSanctuaryLayout.wall(a,Vector3(item[0],0,item[1]),Vector2(item[2],item[3]),item[4])
 var brick=ShaderMaterial.new();brick.shader=load("res://assets/crossroads_masonry.gdshader");brick.set_shader_parameter("noise_texture",load("res://assets/stone_noise.png"))
 var cool=brick.duplicate();cool.set_shader_parameter("tint",Color("626f68"))
 var canvas=k.material(Color("4a5a43"));canvas.roughness=.9
 var glass=k.material(Color("416e70"),.25);glass.roughness=.22
 # Solid wall-backed shopfronts and upper-storey masonry; the shops are decorative.
 for item in [
  [Vector3(-41.65,-2.4,3),PI/2,"LOWER SUN ARCADE",false],
  [Vector3(41.65,-2.4,10),-PI/2,"LOWER MOON ARCADE",true],
  [Vector3(-35.65,0,12),PI/2,"THE RELIQUARY",false],
  [Vector3(-21.65,0,6),PI/2,"PALACE ARCHIVES",false],
  [Vector3(33.65,0,14),-PI/2,"MOON ARCADE",true],
  [Vector3(-5.65,0,8),PI/2,"TEMPLE MARKET",false],
  [Vector3(5.65,0,-4),-PI/2,"LANTERN HOUSE",true],
  [Vector3(-33,2.8,-29.65),0.0,"SUN EXCHANGE",false],
  [Vector3(33,2.8,-29.65),0.0,"MOON GALLERY",true],
  [Vector3(-3,0,33.65),PI,"WAYFARER'S COURT",false],
  [Vector3(0,0,-35.65),0.0,"SANCTUARY GATE",true]]:
  storefront(a,item[0],item[1],item[2],cool if item[3] else brick,canvas,glass)
 # Cornice-lit alley arcades create cool shelter and warm pools of light.
 for side in [-1,1]:
  var x=side*41.65
  for z in [-10,6,18]:
   k.box(a,Vector3(x,1.1,z),Vector3(.15,2.8,.6),k.dark)
   k.box(a,Vector3(x-side*.1,2.4,z),Vector3(.15,.4,.4),k.lamp)
  var fill=OmniLight3D.new();fill.name="CrossroadsAlleyFill";a.add_child(fill);fill.position=Vector3(side*39,1,6);fill.omni_range=12;fill.light_energy=.65;fill.light_color=Color("b1d6d1");fill.shadow_enabled=false
 for spec in [[Vector3(-31,8,-22),Vector3(-29,0,-19)],[Vector3(29,8,12),Vector3(29,0,8)]]:
  NestInteriorLighting.spot(a,spec[0],spec[1],18,52,1.1,Color("ffdda6"),true)
 for p in [Vector3(-18,4,6),Vector3(1,4,8),Vector3(29,3,10)]:
  var light=OmniLight3D.new();light.name="CrossroadsMarketGlow";a.add_child(light);light.position=p;light.omni_range=8;light.light_energy=.55;light.light_color=Color("ffdeb0");light.shadow_enabled=false
 for spec in [[Vector3(-35,1,3),"SUN ALLEY ↓ · SAFE DROP"],[Vector3(35,1,5),"MOON ALLEY ↓ · SAFE DROP"],[Vector3(-39,-.8,13),"RETURN RAMP →"],[Vector3(39,-.8,-3),"← RETURN RAMP"]]:k.label(a,spec[0],spec[1],Color("cdd7ba"),22)
 a.set_meta("crossroads_atmosphere",true)
static func balcony(a: NestArena,title: String,center: Vector3,start: Vector3,end: Vector3) -> void:
 a.floor_at(center.x,center.y,center.z,Vector2(6,8))
 a.floor_cover.append({"pos":Vector3(center.x,0,center.z),"size":Vector2(6,8)})
 var delta=Vector2(end.x-start.x,end.z-start.z)
 a.floor_cover.append({"pos":Vector3((start.x+end.x)*.5,0,(start.z+end.z)*.5),"size":Vector2(3.2,absf(delta.y))})
 a.up_route(title+" RAMP",start,end,3.2)
 # Split front balustrades leave a 3.6m ramp entrance; sides remain drop-able.
 for side in [-1,1]:NestSanctuaryLayout.wall(a,Vector3(center.x+side*2.55,center.y,end.z),Vector2(.9,.25),.95)
 a.kit.label(a,center+Vector3.UP*2.2,title+" · BALCONY",Color("dfc890"),24)
static func storefront(a: NestArena,origin: Vector3,yaw: float,title: String,brick: Material,canvas: Material,glass: Material) -> void:
 var k=a.kit;var root=Node3D.new();root.name="Shop_"+title.replace(" ","_");a.add_child(root);root.position=origin;root.rotation.y=yaw
 # Masonry infill backs the shutters and windows, including the raised storefronts.
 k.box(root,Vector3(0,6.9,-.09),Vector3(5.3,13.8,.1),brick,true)
 # Upper blocks sit above standing gameplay space, over a backed perimeter wall.
 k.box(root,Vector3(0,11.2,-.35),Vector3(5.7,5.2,.7),brick,true)
 for side in [-1,1]:
  k.box(root,Vector3(side*2.65,4.4,.02),Vector3(.28,8.8,.22),k.gold)
  k.box(root,Vector3(side*1.35,6.8,.04),Vector3(1.6,2.2,.1),glass)
  for cross in [-.52,.52]:k.box(root,Vector3(side*1.35+cross,6.8,.11),Vector3(.05,2.2,.06),k.gold)
  k.box(root,Vector3(side*1.35,6.8,.11),Vector3(1.65,.06,.06),k.gold)
 k.box(root,Vector3(0,1.4,.035),Vector3(4.6,2.8,.07),k.dark)
 for y in [.35,.7,1.05,1.4,1.75,2.1,2.45]:k.box(root,Vector3(0,y,.08),Vector3(4.5,.045,.045),k.gold)
 k.box(root,Vector3(0,3.5,.65),Vector3(5.5,.16,1.4),canvas,true)
 k.box(root,Vector3(0,3.1,1.32),Vector3(5.5,.65,.08),canvas)
 k.box(root,Vector3(0,8.7,.06),Vector3(5.9,.24,.3),k.gold)
 k.box(root,Vector3(0,13.85,-.35),Vector3(6,.3,1.0),k.gold)
 var sign=k.label(root,Vector3(0,3.0,.15),title,Color("e5d39a"),26);sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED;sign.pixel_size=.007
