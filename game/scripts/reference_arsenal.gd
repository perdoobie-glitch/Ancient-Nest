class_name NestReferenceArsenal
extends RefCounted
## Shared reference-inspired geometry. Built once during menu loading, instanced thereafter.
static var kit: NestKit
static var templates: Dictionary={}
static var colors: Dictionary={}
static func material(name: String) -> StandardMaterial3D:
 if colors.has(name):return colors[name]
 if kit==null:kit=NestKit.new()
 var m=kit.material(Color({"black":"172123","red":"902c30","ivory":"dce3d9","gold":"baa16c","green":"4ce873","blue":"68c9ff"}[name]),.65)
 m.roughness=.3
 if name in ["green","blue"]:m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=1.2
 colors[name]=m;return m
static func create(kind: String) -> Node3D:
 var path="res://models/Reference_"+kind+".glb"
 if ResourceLoader.exists(path):
  if not templates.has(kind):templates[kind]=load(path)
  var model: Node3D=templates[kind].instantiate();model.scale=Vector3.ONE*.85;
  if kind=="plasma_sniper":NestSniperCycle.add_charge(model)
  return model
 if templates.has(kind):return templates[kind].instantiate()
 var root=Node3D.new();root.name="Reference_"+kind
 var plasma=kind.begins_with("plasma")
 var compact=kind in ["smg","plasma_smg","plasma_pistol"]
 var long=kind=="plasma_sniper"
 var body=material("ivory" if plasma else "red");var dark=material("black");var trim=material("green" if plasma else "gold")
 var length=.39 if compact else .66 if long else .51
 # Layered tapered silhouette: receiver, floating shoulder plates, stock and grip.
 kit.box(root,Vector3(0,.015,-.18),Vector3(.14,.13,length),dark)
 for side in [-1,1]:
  var panel=kit.box(root,Vector3(side*.077,.04,-.2),Vector3(.035,.13,length*.85),body)
  panel.rotation.z=side*.18;panel.rotation.x=-.06
  kit.box(root,Vector3(side*.098,.075,-.20),Vector3(.013,.018,length*.67),trim)
  for i in range(3):
   var vent=kit.box(root,Vector3(side*.1,-.005,-.1-i*.055),Vector3(.008,.035,.025),dark);vent.rotation.x=.35
 kit.box(root,Vector3(0,.035,.12),Vector3(.115,.11,.22 if not compact else .12),body)
 var grip=kit.box(root,Vector3(0,-.13,.035),Vector3(.075,.18,.09),dark);grip.rotation.x=-.18
 var magazine=Node3D.new();magazine.name="ReloadMagazine_EnergyCell" if plasma else "ReloadMagazine_SMG";magazine.position=Vector3(0,-.14,-.16);root.add_child(magazine)
 kit.box(magazine,Vector3.ZERO,Vector3(.09,.17,.105),dark)
 kit.box(magazine,Vector3(0,-.045,0),Vector3(.095,.07,.11),body)
 for i in range(3):kit.box(magazine,Vector3(.047,-.04+i*.04,0),Vector3(.009,.018,.07),trim)
 var tip=-.18-length*.5-.07
 if plasma:
  for side in [-1,1]:
   var prong=kit.box(root,Vector3(side*.058,.018,tip),Vector3(.046,.08,.19),body);prong.rotation.y=side*.09
   kit.box(root,Vector3(side*.045,.015,tip-.055),Vector3(.012,.025,.15),trim)
  kit.sphere(root,Vector3(0,.018,tip+.055),.042,trim)
  kit.sphere(root,Vector3(.10,.032,-.22),.043,trim)
 else:
  kit.cylinder(root,Vector3(0,.035,tip),.025,.19,dark).rotation.x=PI*.5
  kit.cylinder(root,Vector3(0,.035,tip-.09),.034,.055,dark).rotation.x=PI*.5
  kit.box(root,Vector3(0,.114,-.19),Vector3(.045,.025,.28),trim)
 if kind in ["plasma_br","plasma_sniper"]:
  kit.box(root,Vector3(0,.135,-.12),Vector3(.055,.08,.18),dark)
  kit.cylinder(root,Vector3(0,.19,-.13),.045,.21,dark).rotation.x=PI*.5
  kit.cylinder(root,Vector3(0,.19,-.24),.034,.009,trim).rotation.x=PI*.5
 else:kit.box(root,Vector3(0,.12,-.15),Vector3(.045,.04,.055),trim)
 var latch=Node3D.new();latch.name="ChargingHandle_Reference";latch.position=Vector3(.10,.075,.03);root.add_child(latch);kit.box(latch,Vector3.ZERO,Vector3(.04,.035,.055),trim)
 root.scale=Vector3.ONE*.85
 own_children(root,root)
 var packed=PackedScene.new();packed.pack(root);templates[kind]=packed;root.free()
 var instance=packed.instantiate()
 if kind=="plasma_sniper":NestSniperCycle.add_charge(instance)
 return instance
static func own_children(node: Node,owner_root: Node) -> void:
 for child in node.get_children():child.owner=owner_root;own_children(child,owner_root)
