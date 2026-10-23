class_name NestFrontierMaps
extends RefCounted
## Original arenas. Gameplay solids are simple; fine trim is visual and statically batched.
const PALETTES={
 3:["414b50","a7b0aa","bca270","273339","70e4cf","d17742"],
 4:["d5d5b9","e9e6ca","baa66b","526d61","70d6b7","527b42"],
 5:["66726b","adb5a0","a28d53","343e3a","91be8f","6d7a47"]}
static func mat(a,color: String,metal: float=0.0,texture: String="masonry") -> StandardMaterial3D:
 var cache=a.get_meta("frontier_materials",{});var key=color+str(metal)+texture
 if cache.has(key):return cache[key]
 var m=a.kit.material(Color(color),metal);cache[key]=m;a.set_meta("frontier_materials",cache);m.roughness=.82 if metal<.4 else .43
 var extension=".jpg" if texture in ["weathered","slate","garden_stone","dark_alloy","cliff","soil"] else ".png"
 var path="res://assets/frontier/"+texture+extension
 if ResourceLoader.exists(path):
  m.albedo_texture=load(path);m.normal_enabled=true;m.normal_texture=load("res://assets/frontier/"+texture+"_normal"+extension);m.normal_scale=.42
  m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(.22,.22,.22)
 return m
static func glow(a,color: String) -> StandardMaterial3D:
 var m=a.kit.material(Color(color));m.emission_enabled=true;m.emission=Color(color);m.emission_energy_multiplier=.7;return m
static func water_material(a) -> ShaderMaterial:
 if a.has_meta("frontier_water"):return a.get_meta("frontier_water")
 var m=ShaderMaterial.new();m.shader=load("res://assets/frontier/water.gdshader");a.set_meta("frontier_water",m);return m
static func environment(a,env: Environment,sky: Sky,light: DirectionalLight3D) -> void:
 var material=ProceduralSkyMaterial.new()
 if a.map_selection==3:
  material.sky_top_color=Color("183747");material.sky_horizon_color=Color("a48d79");material.ground_horizon_color=Color("4c5859");material.ground_bottom_color=Color("1c262d")
  env.ambient_light_color=Color("b5ced1");env.ambient_light_energy=.48;env.fog_light_color=Color("8c9290");env.fog_density=.0018;light.light_color=Color("f3d0aa");light.light_energy=.73;light.rotation_degrees=Vector3(-38,-24,0)
 elif a.map_selection==4:
  material.sky_top_color=Color("5a9fb8");material.sky_horizon_color=Color("e4e5ce");material.ground_horizon_color=Color("a6c3b1");material.ground_bottom_color=Color("719b91")
  env.ambient_light_color=Color("d9e5d5");env.ambient_light_energy=.46;env.fog_light_color=Color("b4d4c2");env.fog_density=.0011;light.light_color=Color("fff1cb");light.light_energy=.72;light.rotation_degrees=Vector3(-54,-35,0)
 else:
  material.sky_top_color=Color("405d65");material.sky_horizon_color=Color("bbc4b0");material.ground_horizon_color=Color("738d80");material.ground_bottom_color=Color("354b47")
  env.ambient_light_color=Color("ccdbd0");env.ambient_light_energy=.52;env.fog_light_color=Color("a5b3a4");env.fog_density=.0016;light.light_color=Color("ffe5ae");light.light_energy=.73;light.rotation_degrees=Vector3(-43,48,0)
 env.tonemap_exposure=.85;env.tonemap_white=2.0
 var atmosphere=ShaderMaterial.new();atmosphere.shader=load("res://assets/frontier/sky.gdshader")
 atmosphere.set_shader_parameter("zenith",material.sky_top_color);atmosphere.set_shader_parameter("horizon",material.sky_horizon_color)
 atmosphere.set_shader_parameter("clouds",Color("b8a58d") if a.map_selection==3 else Color("ece8d4") if a.map_selection==4 else Color("bac6bc"))
 atmosphere.set_shader_parameter("cover",.53 if a.map_selection==3 else .48 if a.map_selection==4 else .42)
 sky.sky_material=atmosphere
static func solid(a,p: Vector3,size: Vector2,height: float,m: Material=null,trim: bool=true) -> void:
 var k=a.kit;var material=k.stone if m==null else m
 k.box(a,p+Vector3(0,height*.5,0),Vector3(size.x,height,size.y),material,true)
 a.floor_cover.append({"pos":p,"size":size})
 if trim:
  k.box(a,p+Vector3(0,.16,0),Vector3(size.x+.08,.18,size.y+.08),k.dark)
  k.box(a,p+Vector3(0,height-.12,0),Vector3(size.x+.1,.12,size.y+.1),k.gold)
static func pillar(a,p: Vector3,height: float,radius: float=.55) -> void:
 var k=a.kit
 # Box collision encloses the fluting; visual shafts do not add tiny snag points.
 solid(a,p,Vector2(radius*2,radius*2),height,k.stone,false)
 k.box(a,p+Vector3(0,.15,0),Vector3(radius*2.5,.3,radius*2.5),k.dark)
 k.cylinder(a,p+Vector3(0,height*.5,0),radius*.92,height,k.stone)
 for y in [.45,height-1,height-.25]:k.cylinder(a,p+Vector3(0,y,0),radius*1.13,.12,k.gold)
 for dx in [-.34,.34]:k.box(a,p+Vector3(dx,height*.5,-radius-.01),Vector3(.065,height-.9,.055),k.gold)
static func portal(a,p: Vector3,width: float,height: float,turned: bool=false) -> void:
 var k=a.kit;var node=Node3D.new();node.position=p;if turned:node.rotation.y=PI*.5
 a.add_child(node)
 # The portal frame is decorative; thick posts are the only collision, with a wide aperture.
 for side in [-1,1]:
  var local=Vector3(side*(width*.5+.6),0,0);var world=p+(Basis(Vector3.UP,node.rotation.y)*local)
  pillar(a,world,height,.6)
 k.box(node,Vector3(0,height-.4,0),Vector3(width+2.5,.8,1.35),k.stone)
 k.box(node,Vector3(0,height+.1,0),Vector3(width+2.9,.18,1.6),k.gold)
 for x in [-2,-1,0,1,2]:
  k.box(node,Vector3(x*width*.16,height-.3,-.72),Vector3(.4,.5,.06),k.dark)
  k.box(node,Vector3(x*width*.16,height-.3,-.77),Vector3(.06,.32,.04),k.gold)
static func panel(a,p: Vector3,size: Vector2,turned: bool=false) -> void:
 var k=a.kit;var node=Node3D.new();node.position=p;if turned:node.rotation.y=PI*.5
 a.add_child(node);k.box(node,Vector3.ZERO,Vector3(size.x,size.y,.08),k.dark)
 for sign in [-1,1]:
  k.box(node,Vector3(sign*size.x*.5,0,-.06),Vector3(.055,size.y+.08,.07),k.gold)
  k.box(node,Vector3(0,sign*size.y*.5,-.06),Vector3(size.x,.055,.07),k.gold)
 for i in range(4):k.box(node,Vector3((i-1.5)*size.x*.17,0,-.09),Vector3(.075,size.y*.67,.06),k.gold)
static func paving(a,axis: int,length: float,width: float,center: Vector3,ink: Material) -> void:
 var k=a.kit
 for side in [-1,1]:
  var offset=Vector3(side*width*.5,0,0) if axis==0 else Vector3(0,0,side*width*.5)
  k.box(a,center+offset+Vector3(0,.025,0),Vector3(.10,.03,length) if axis==0 else Vector3(length,.03,.10),ink)
 for i in range(-int(length*.5)+2,int(length*.5)-1,4):
  var p=center+(Vector3(0,.027,i) if axis==0 else Vector3(i,.027,0))
  k.box(a,p,Vector3(width,.025,.035) if axis==0 else Vector3(.035,.025,width),a.kit.dark)
static func foundation(a) -> void:
 var k=a.kit
 a.bounds=Vector2(41,37)
 var wall_material=k.stone;k.stone=mat(a,"8f999c" if a.map_selection==3 else "b9b9a5" if a.map_selection==4 else "8f998e",0,"slate" if a.map_selection==3 else "masonry" if a.map_selection==4 else "masonry")
 a.floor_at(0,0,0,Vector2(80,72));k.stone=wall_material
 for x in [-40,40]:solid(a,Vector3(x,0,0),Vector2(1,72),5.6)
 for z in [-36,36]:solid(a,Vector3(0,0,z),Vector2(80,1),5.6)
 # Competitive clipping follows the visible perimeter above normal jump height.
 # Players can climb the shuttle; a low visual wall alone permits leaving the arena.
 for spec in [[Vector3(-40,16,0),Vector3(1,32,73)],[Vector3(40,16,0),Vector3(1,32,73)],[Vector3(0,16,-36),Vector3(81,32,1)],[Vector3(0,16,36),Vector3(81,32,1)]]:
  var body=StaticBody3D.new();body.name="CompetitiveBoundary";body.collision_layer=1;body.collision_mask=2;body.position=spec[0];body.set_meta("surface_material","stone");body.set_meta("frontier_boundary",true);a.add_child(body)
  var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=spec[1];collider.shape=shape;body.add_child(collider)
 # Spawn baffles protect first movement, with three exits and no direct opposing sightline.
 for side in [-1,1]:
  solid(a,Vector3(0,0,24*side),Vector2(14,1),3.7)
  panel(a,Vector3(0,1.9,24*side-side*.56),Vector2(6,1.65))
  for x in [-8,-4,0,4,8]:
   for z in [30,32]:a.spawns[0 if side==1 else 1].append(Vector3(x,.08,z*side))
  a.flag_labels.append(k.label(a,Vector3(0,3.1,31*side),"FLAG",Color("dfc890")))
  a.flag_meshes.append(k.banner(a,Vector3(-9*side,0,33*side),k.green if side==1 else k.red))
  # Same collision footprint opposite the actual shuttle berth.
  # Mirrored shuttle geometry is added by the arena, with identical collision.
 a.ship_position=Vector3(12,0,31)
 a.sites.assign([Vector3(-28,0,0),Vector3(28,0,0)])
 a.pads.assign([Vector3(-32,0,26),Vector3(32,0,-26),Vector3(30,0,15),Vector3(-30,0,-15),Vector3(-28,0,-9),Vector3(28,0,9),Vector3(0,0,14),Vector3(0,0,-14),Vector3(-4,0,0),Vector3(4,0,0)])
 a.pad_kinds=["ak47","ak47","plasma_auto","plasma_auto","shotgun","shotgun","burst_scoped","plasma_br","sniper","overshield"]
 a.pad_names=["AK","AK","VOLT","VOLT","SHOTGUN","SHOTGUN","SCOPED BR","TRIAD","SNIPER","SHIELD"]
 for x in [-35,35]:paving(a,0,56,4,Vector3(x,0,0),k.gold)
 for z in [-31,31]:paving(a,1,50,4,Vector3(0,0,z),k.gold)
 # Repeating wall courses and buttresses are batched by material/spatial cell.
 for x in [-39.45,39.45]:
  for y in [.7,3.9]:k.box(a,Vector3(x,y,0),Vector3(.09,.10,70),k.gold)
  for z in range(-32,33,8):
   k.box(a,Vector3(x,2.7,z),Vector3(.15,3.8,.5),k.dark)
   panel(a,Vector3(x,2.4,z+2.1),Vector2(2.1,1.35),true)
 for z in [-35.45,35.45]:
  k.box(a,Vector3(0,3.9,z),Vector3(78,.1,.08),k.gold)
  for x in range(-32,33,8):panel(a,Vector3(x,2.6,z),Vector2(3,1.3))
static func build(a: NestArena) -> void:
 var colors=PALETTES[a.map_selection];var k=a.kit;k.leaf_mesh=NestFrontierDetails.leaf_geometry()
 k.stone=mat(a,colors[0],0,"dark_alloy" if a.map_selection==3 else "garden_stone" if a.map_selection==4 else "weathered");k.gold=mat(a,colors[2],.7,"alloy");k.dark=mat(a,colors[3],.2,"dark_alloy")
 foundation(a)
 if a.map_selection==3:connectuct(a)
 elif a.map_selection==4:qaytal(a)
 else:temple(a)
 NestFrontierDetails.extra(a)
 NestFrontierDetails.batch_foliage(a)
 for mesh in a.find_children("*","MeshInstance3D",true,false):
  var position=mesh.position
  if absf(position.x)>44 or absf(position.z)>41 or position.y< -3:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  elif mesh.mesh is BoxMesh:
   var size=mesh.mesh.size
   if minf(size.x,minf(size.y,size.z))<.16:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 a.set_meta("frontier_map",true);a.set_meta("frontier_design","Original 180-degree balanced structure; unique scenery and landmarks")
static func platform(a,p: Vector3,size: Vector2,height: float) -> void:
 solid(a,p,size,height);a.floor_at(p.x,p.y+height,p.z,size)
static func connectuct(a) -> void:
 var k=a.kit;var energy=glow(a,"6fd5c9");var hot=glow(a,"d99b53");var pale=mat(a,"9daaa8",.25,"alloy");var basalt=mat(a,"293c45",0,"rock")
 for side in [-1,1]:
  var s=float(side)
  platform(a,Vector3(14*s,0,12*s),Vector2(12,12),4)
  a.up_route("",Vector3(14*s,0,30*s),Vector3(14*s,4,18*s),4.5,false)
  a.up_route("",Vector3(32*s,0,12*s),Vector3(20*s,4,12*s),4.5,false)
  solid(a,Vector3(-14*s,0,12*s),Vector2(11,14),5.5)
  for z in [7,17]:panel(a,Vector3(-14*s,2.6,z*s),Vector2(7,2.5))
  solid(a,Vector3(11*s,4,12*s),Vector2(1,6),1.15)
  solid(a,Vector3(16*s,4,8*s),Vector2(4,1),1.15)
  solid(a,Vector3(25*s,0,-6*s),Vector2(6,1.5),1.2)
  portal(a,Vector3(28*s,0,0),8,7,true)
  for z in [-5,5]:solid(a,Vector3(21*s,0,z),Vector2(1.1,4),2.8)
  for x in [9,19]:
   k.box(a,Vector3(x*s,3.7,12*s),Vector3(.14,.14,11),energy)
   for z in [8,12,16]:k.box(a,Vector3(x*s,2.5,z*s),Vector3(.13,1.2,.8),pale)
  for z in [-23,23]:
   k.box(a,Vector3(25*s,.02,z),Vector3(13,.025,4),k.dark)
   paving(a,1,13,3,Vector3(25*s,0,z),energy)
 # Central reactor: clear lower cover and a suspended, slowly dying energy crown.
 solid(a,Vector3(0,0,0),Vector2(7,7),1.35,k.dark)
 for x in [-3,3]:
  for z in [-3,3]:pillar(a,Vector3(x,1.35,z),6.4,.42)
 var ring=Node3D.new();a.add_child(ring);ring.position=Vector3(0,7.2,0);ring.rotation.x=PI*.5
 k.ring(ring,Vector3.ZERO,4.5,k.gold);k.ring(ring,Vector3(0,.12,0),4.1,energy)
 for i in range(8):
  var angle=i*TAU/8;var p=Vector3(sin(angle)*3.8,7.2,cos(angle)*3.8)
  k.box(a,p,Vector3(.22,.9,.22),hot if i%3==0 else energy)
 for side in [-1,1]:
  for z in [-13,13]:paving(a,1,16,5,Vector3(0,0,z),k.gold)
 # Giant cracked strata and abandoned towers sit outside playable bounds; no physics.
 for i in range(16):
  var angle=TAU*i/16;var p=Vector3(sin(angle)*86,-6,cos(angle)*78)
  NestFrontierDetails.rock(a,p,Vector3(12,24+(i%4)*5,9),basalt,400+i)
  if i%2==0:
   k.box(a,p+Vector3(0,18,0),Vector3(5,26,5),pale)
   k.box(a,p+Vector3(0,19,-2.6),Vector3(.15,19,.12),hot)
 var globe=SphereMesh.new();globe.radius=48;globe.height=96;globe.radial_segments=64;globe.rings=32
 var planet_material=k.material(Color.WHITE);planet_material.albedo_texture=load("res://assets/frontier/connectuct_planet.jpg");planet_material.roughness=1.0
 planet_material.emission_enabled=true;planet_material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY;planet_material.emission_texture=load("res://assets/frontier/connectuct_planet_emission.jpg");planet_material.emission=Color("f6ac66");planet_material.emission_energy_multiplier=.65
 var planet=k.mesh(a,globe,Vector3(-65,95,-155),planet_material);planet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 k.box(a,Vector3(0,-8,0),Vector3(320,.5,320),basalt)
static func tree(a,p: Vector3,height: float,_leaf: Material,_root_radius: float=.4) -> void:
 NestFrontierDetails.tree(a,p,height,a.map_selection==4)
static func planter(a,p: Vector3,size: Vector2,leaf: Material) -> void:
 solid(a,p,size,1.15)
 var soil=mat(a,"6b6550",0,"soil");a.kit.box(a,p+Vector3(0,1.16,0),Vector3(size.x-.3,.08,size.y-.3),soil)
 NestFrontierDetails.leaves(a,p+Vector3(0,1.45,0),Vector3(size.x*.42,.35,size.y*.42),int(size.x*size.y*25),int(p.x*33+p.z*91),a.map_selection==4)
static func qaytal(a) -> void:
 var k=a.kit;var pale=mat(a,"e6e4ca");var water=water_material(a);var leaf=mat(a,"577d4f",0,"moss");var lightleaf=mat(a,"8b9d60",0,"moss")
 for side in [-1,1]:
  var s=float(side)
  # Opposing raised tea gardens run north/south: this arena's topology is
  # a double loop around a living central court, rather than diagonal towers.
  platform(a,Vector3(0,0,14*s),Vector2(14,8),2.8)
  a.up_route("",Vector3(-19,0,14*s),Vector3(-7,2.8,14*s),4.5,false)
  a.up_route("",Vector3(19,0,14*s),Vector3(7,2.8,14*s),4.5,false)
  planter(a,Vector3(-4*s,2.8,11*s),Vector2(4,1.2),leaf)
  planter(a,Vector3(4*s,2.8,17*s),Vector2(4,1.2),leaf)
  # Large garden islands split the left and right approaches into readable curves.
  planter(a,Vector3(17*s,0,5*s),Vector2(6,7),leaf)
  tree(a,Vector3(17*s,1.7,5*s),6.2,leaf)
  planter(a,Vector3(15*s,0,-10*s),Vector2(3.2,8),lightleaf)
  portal(a,Vector3(28*s,0,0),8,6.2,true)
  for z in [-6,6]:planter(a,Vector3(24*s,0,z),Vector2(4,2.1),leaf)
  planter(a,Vector3(-7*s,0,12*s),Vector2(2.2,4),lightleaf)
  # Pools are raised behind the terrace, with a dry standing area on both sides.
  k.box(a,Vector3(0,2.84,14*s),Vector3(2.2,.05,5.2),water)
  tree(a,Vector3(29*s,0,-21*s),6.5,lightleaf)
  for z in [-24,24]:paving(a,1,20,5,Vector3(23*s,0,z),k.gold)
 a.pads[6]=Vector3(-3,2.8,14);a.pads[7]=Vector3(3,2.8,-14)
 # Tree of life: living landmark and deliberately solid central cover.
 solid(a,Vector3(0,0,0),Vector2(7,7),1.35,pale)
 tree(a,Vector3(0,1.35,0),11.5,leaf,.95)
 for side in [-1,1]:
  k.box(a,Vector3(side*5,.035,0),Vector3(1.1,.035,16),water)
  for z in [-10,10]:planter(a,Vector3(side*8,0,z),Vector2(4,1.5),leaf)
 # Arcades and carved wall ribs provide detailed edges while the playable floor stays clear.
 for side in [-1,1]:
  for z in [-26,-14,-2,10,22]:
   pillar(a,Vector3(37*side,0,z),7.5,.55)
   k.box(a,Vector3(37*side,7.4,z+4),Vector3(1.4,.5,8),pale)
  for x in [-25,-13,13,25]:tree(a,Vector3(x,0,41*side),9,leaf)
 for i in range(12):
  var angle=i*TAU/12;var p=Vector3(sin(angle)*75,-5,cos(angle)*70)
  NestFrontierDetails.rock(a,p-Vector3(0,9,0),Vector3(14,19,12),pale,500+i)
  tree(a,p+Vector3(0,9,0),10,lightleaf)
  for j in [-1,1]:
   k.box(a,p+Vector3(j*3,2,-6),Vector3(.75,14,.15),water)
 k.box(a,Vector3(0,-12,0),Vector3(380,.5,380),water)
static func vine(a,p: Vector3,length: float,leaf: Material) -> void:
 var k=a.kit
 for i in range(5):
  var here=p+Vector3(sin(i*1.3)*.35,-length*i/5.,0)
  k.branch(a,here,here+Vector3(.18,-length/5.,.08),.035,k.dark)
  NestFrontierDetails.leaves(a,here+Vector3(.1,-.15,.1),Vector3(.42,.24,.3),12,int(p.x*23+p.z*17+i),false)
static func temple(a) -> void:
 var k=a.kit;var pale=mat(a,"a6b09e");var leaf=mat(a,"657d48",0,"moss");var shadow=mat(a,"3d514b",0,"rock");var fire=glow(a,"d9bb6c")
 # Four-way raised sanctuary, with a central screen so height never watches every approach.
 platform(a,Vector3(0,0,0),Vector2(18,18),3.2)
 for side in [-1,1]:
  a.up_route("",Vector3(0,0,22*side),Vector3(0,3.2,9*side),6,false)
  a.up_route("",Vector3(22*side,0,0),Vector3(9*side,3.2,0),5,false)
  solid(a,Vector3(-14*side,0,15*side),Vector2(10,11),5.8)
  solid(a,Vector3(21*side,0,12*side),Vector2(4,12),3.5)
  portal(a,Vector3(28*side,0,0),9,8.2,true)
  for z in [-7,7]:solid(a,Vector3(31*side,0,z),Vector2(8,1.2),2.5)
  for x in [-6,6]:pillar(a,Vector3(x,3.2,6*side),6,.55)
  solid(a,Vector3(5*side,3.2,2*side),Vector2(1.1,3.2),1.1)
  # Reclaimed cloister roof: ornament is outside capsule contact paths.
  for z in [-23,-11,1,13,25]:
   pillar(a,Vector3(37*side,0,z),8.2,.65)
   k.box(a,Vector3(37*side,8.15,z+4.5),Vector3(2,.75,9),pale)
   vine(a,Vector3(36.8*side,7.9,z),4.2,leaf)
  for z in [-14,14]:
   k.box(a,Vector3(13*side,5.5,z),Vector3(12,.7,1.3),pale)
   vine(a,Vector3(11*side,5.5,z),3.2,leaf)
  tree(a,Vector3(47*side,0,19*side),14,leaf,.8)
 a.pads[6]=Vector3(-30,0,20);a.pads[7]=Vector3(30,0,-20);a.pads[8]=Vector3(-4,3.2,0);a.pads[9]=Vector3(4,3.2,0)
 # An empty, fractured reliquary: original sculpture rather than a borrowed faction icon.
 solid(a,Vector3(0,3.2,0),Vector2(4.5,4.5),3.1,pale)
 var altar=Node3D.new();a.add_child(altar);altar.position=Vector3(0,7.3,0);altar.rotation.x=PI*.5
 k.ring(altar,Vector3.ZERO,2.8,k.gold)
 for i in range(3):
  var prism=k.box(a,Vector3((i-1)*1.8,9.4+abs(i-1)*.7,0),Vector3(.5,3.1,.5),k.gold);prism.rotation.z=(i-1)*.35
 for side in [-1,1]:
  panel(a,Vector3(0,4.9,2.31*side),Vector2(3,1.9))
  panel(a,Vector3(2.31*side,4.9,0),Vector2(3,1.9),true)
  for z in range(-28,29,7):vine(a,Vector3(39.2*side,5.5,z),3.6,leaf)
 # Background temple mass and angular cliffs add scale without actor collision.
 for side in [-1,1]:
  for i in range(6):
   var p=Vector3(side*(51+i*5),-4,-32+i*13)
   NestFrontierDetails.rock(a,p,Vector3(12,23+(i%3)*3,9),shadow,600+i)
  for x in [-24,-12,0,12,24]:
   k.box(a,Vector3(x,8,52*side),Vector3(7,20,8),shadow)
   k.box(a,Vector3(x,18,52*side),Vector3(8,.8,9),k.gold)
   tree(a,Vector3(x,18,52*side),6,leaf)
 k.box(a,Vector3(0,-9,0),Vector3(300,.5,300),shadow)
