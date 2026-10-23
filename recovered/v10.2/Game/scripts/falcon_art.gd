class_name NestFalconArt
extends RefCounted
const WINGSPAN: float=1.05
const BODY_LENGTH: float=.42
static var kit: NestKit
static var feather: StandardMaterial3D
static var pale: StandardMaterial3D
static var dark: StandardMaterial3D
static var gold: StandardMaterial3D
static var wing_mesh: ArrayMesh
static func prepare() -> void:
 if kit!=null:return
 kit=NestKit.new();feather=kit.material(Color("66594a"));pale=kit.material(Color("c7b49a"));dark=kit.material(Color("39352f"));gold=kit.material(Color("b9984e"),.2)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector3(0,0,-.09),Vector3(.20,.015,-.12),Vector3(.47,0,.10),Vector3(.525,-.025,.18),Vector3(.29,-.01,.13),Vector3(.08,-.015,.14)]
 for tri in [[0,1,4],[1,2,4],[2,3,4],[0,4,5]]:
  for index in tri:st.add_vertex(points[index])
 st.generate_normals();wing_mesh=st.commit();feather.cull_mode=BaseMaterial3D.CULL_DISABLED
static func create(folded: bool=false) -> Node3D:
 prepare()
 var root=Node3D.new();root.name="NuFalcon"
 var body=kit.sphere(root,Vector3.ZERO,.10,feather);body.scale=Vector3(.72,.88,1.75)
 var breast=kit.sphere(root,Vector3(0,-.035,-.04),.075,pale);breast.scale=Vector3(.9,1,1.5)
 var head=kit.sphere(root,Vector3(0,.065,-.16),.052,feather);head.scale=Vector3(.9,.9,1.1)
 for sign in [-1,1]:
  var mask=kit.sphere(root,Vector3(sign*.038,.054,-.183),.023,dark);mask.scale=Vector3(.28,1.5,.8)
  kit.sphere(root,Vector3(sign*.041,.077,-.193),.007,gold)
  kit.sphere(root,Vector3(sign*.045,.078,-.197),.004,dark)
  var wing=MeshInstance3D.new();wing.name="WingLeft" if sign<0 else "WingRight";wing.mesh=wing_mesh;wing.material_override=feather;wing.scale.x=sign;root.add_child(wing)
  wing.rotation=Vector3(0,-sign*1.1,-sign*.20) if folded else Vector3.ZERO
  for i in range(5):
   var pen=kit.box(wing,Vector3(.25+i*.05,-.004,.09+i*.012),Vector3(.028,.008,.16-i*.018),dark);pen.rotation.y=-.25
  var talon=kit.cylinder(root,Vector3(sign*.032,-.112,.018),.009,.065,gold);talon.rotation.x=-.4
 var beak=MeshInstance3D.new();var cone=PrismMesh.new();cone.size=Vector3(.026,.04,.042);beak.mesh=cone;beak.material_override=gold;beak.position=Vector3(0,.038,-.215);beak.rotation.x=-.75;root.add_child(beak)
 # Small breast barring and back saddle give the falcon its raptor markings.
 for row in range(4):
  for column in [-1,0,1]:
   var spot=kit.sphere(root,Vector3(column*.027,-.084,-.10+row*.043),.009,dark);spot.scale=Vector3(.48,.22,1.2)
 var saddle=kit.sphere(root,Vector3(0,.061,.035),.064,dark);saddle.scale=Vector3(.85,.35,1.8)
 var tail=kit.box(root,Vector3(0,-.012,.19),Vector3(.11,.012,.15),dark);tail.rotation.x=-.12
 return root
static func animate(root: Node3D, clock: float, flap: bool, bank: float) -> void:
 var stroke=sin(clock*(18.0 if flap else 4.0))*(.65 if flap else .06)
 for sign in [-1,1]:
  var wing=root.get_node("WingLeft" if sign<0 else "WingRight")
  wing.rotation.z=sign*stroke
 root.rotation.z=bank
