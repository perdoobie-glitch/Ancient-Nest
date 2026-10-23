class_name NestV19Scenery
extends RefCounted
# Original 3D scenery inspired by the supplied castle/mountain artwork.
# Entirely beyond playable bounds; no scenery body participates in collision.
static func build(a: NestArena) -> void:
 var root=Node3D.new();root.name="V19CastleValley";a.add_child(root)
 if ResourceLoader.exists("res://assets/v19_panorama.jpg"):return
 var k=a.kit;var cliff=k.material(Color("718086"));var distant=k.material(Color("aab5bc"));var snow=k.material(Color("ebe8df"));var cream=k.material(Color("d7cdb3"),.08);var roof=k.material(Color("756953"),.35);var window=k.material(Color("59666a"));var green=k.material(Color("667963"))
 # Three depth bands of snow-topped ridges frame the citadel and valley.
 for row in range(3):
  for i in range(9):
   var angle=-2.8+i*.66+row*.17;var radius=280+row*125
   var pos=Vector3(sin(angle)*radius,-85-row*18,cos(angle)*radius)
   var height=120+float((i*37+row*23)%100);var spread=64+float((i*17)%42)
   mountain(k,root,pos,spread,height,distant if row>0 else cliff)
   mountain(k,root,pos+Vector3.UP*(height*.70),spread*.31,height*.31,snow)
 # Steep cliff and pale stone citadel, raised above the mist.
 var city=Node3D.new();city.position=Vector3(-145,-5,-190);root.add_child(city)
 mountain(k,city,Vector3(0,-100,0),63,105,cliff)
 k.box(city,Vector3(0,-2,0),Vector3(72,5,62),cream)
 k.box(city,Vector3(0,23,-3),Vector3(27,46,42),cream)
 k.box(city,Vector3(0,48,-3),Vector3(30,4,45),k.gold)
 for x in [-26,-13,13,26]:
  for z in [-21,21]:tower(k,city,Vector3(x,0,z),44+absf(x)*.9,cream,roof,window)
 tower(k,city,Vector3(0,47,-3),52,cream,roof,window)
 for side in [-1,1]:
  for i in range(6):
   k.box(city,Vector3(side*14,7+i*6,-3),Vector3(.7,.7,40),k.gold)
   k.cylinder(city,Vector3(side*17,21,-20+i*7),.8,42,cream)
 for x in [-9,0,9]:
  for y in [12,25,38]:k.box(city,Vector3(x,y,18.04),Vector3(3,7,.1),window)
 # Arched aqueduct connects the citadel to a smaller inhabited cliff.
 var bridge=Node3D.new();bridge.position=Vector3(-107,-1,-155);bridge.rotation.y=-.54;root.add_child(bridge)
 k.box(bridge,Vector3(0,0,0),Vector3(12,2,96),cream)
 for x in [-5.8,5.8]:k.box(bridge,Vector3(x,1.9,0),Vector3(.5,2,96),k.gold)
 for z in [-36,-12,12,36]:
  for x in [-4.5,4.5]:
   k.cylinder(bridge,Vector3(x,-24,z),1.4,48,cream)
   for j in range(11):
    var angle=j*PI/10;var beam=k.box(bridge,Vector3(x,-14+sin(angle)*10,z+cos(angle)*10),Vector3(1.7,2.2,3.4),cream);beam.rotation.x=angle
 var island=Vector3(-78,-42,-105);mountain(k,root,island-Vector3.UP*45,38,80,cliff)
 for i in range(14):
  var x=-170+i*7.3;var z=-145+sin(i*2.3)*17;var y=-6+sin(i*.7)*4
  var tree=k.cylinder(root,Vector3(x,y+5,z),0.0,16,green);tree.mesh.bottom_radius=2.7
 # Foaming falls beneath the bridge remain below and beyond the combat map.
 var water=k.material(Color(.65,.79,.80,.55));water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;water.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 for x in [-152,-137]:k.box(root,Vector3(x,-51,-165),Vector3(4,92,.4),water)
 for mesh in root.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func tower(k: NestKit,parent: Node3D,pos: Vector3,height: float,stone: Material,roof: Material,window: Material) -> void:
 k.cylinder(parent,pos+Vector3.UP*height*.5,3.8,height,stone)
 for y in [6.0,height*.5,height-2]:k.cylinder(parent,pos+Vector3.UP*y,4.15,.8,k.gold)
 var top=k.cylinder(parent,pos+Vector3.UP*(height+9),0,18,roof);top.mesh.bottom_radius=4.7
 k.cylinder(parent,pos+Vector3.UP*(height+18),.15,7,k.gold)
 for y in range(10,int(height-3),12):
  for side in [-1,1]:k.box(parent,pos+Vector3(side*3.79,y,0),Vector3(.09,5,1.4),window)
static func mountain(k: NestKit,parent: Node3D,pos: Vector3,radius: float,height: float,mat: Material) -> void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(9):
  var a=i*TAU/9;var b=(i+1)*TAU/9
  var p=Vector3(cos(a)*radius*(1+.13*sin(i*2.7)),0,sin(a)*radius)
  var q=Vector3(cos(b)*radius*(1+.13*sin((i+1)*2.7)),0,sin(b)*radius)
  for v in [p,Vector3(radius*.12,height,-radius*.08),q]:st.add_vertex(v)
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=mat;mesh.position=pos;parent.add_child(mesh)
