class_name NestKnifeArt
extends RefCounted
static var blade: ArrayMesh
static var steel: StandardMaterial3D
static var grip: StandardMaterial3D
static var guard_material: StandardMaterial3D
static var handle_mesh: BoxMesh
static var guard_mesh: BoxMesh
static func prepare() -> void:
 if blade!=null:return
 steel=StandardMaterial3D.new();steel.albedo_color=Color("b8c7cd");steel.metallic=.85;steel.roughness=.25
 grip=StandardMaterial3D.new();grip.albedo_color=Color("782a2a");grip.roughness=.85
 guard_material=StandardMaterial3D.new();guard_material.albedo_color=Color("a08b4d");guard_material.metallic=.65;guard_material.roughness=.4
 var verts=[Vector3(-.025,0,0),Vector3(.025,0,0),Vector3(-.019,0,-.18),Vector3(.019,0,-.18),Vector3(0,0,-.29),Vector3(0,.007,-.11),Vector3(0,-.007,-.11)]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in [[0,5,1],[0,2,5],[2,4,5],[4,3,5],[3,1,5],[1,6,0],[0,6,2],[2,6,4],[4,6,3],[3,6,1]]:
  for index in face:st.add_vertex(verts[index])
 st.generate_normals();blade=st.commit()
 handle_mesh=BoxMesh.new();handle_mesh.size=Vector3(.035,.032,.13)
 guard_mesh=BoxMesh.new();guard_mesh.size=Vector3(.09,.015,.022)
static func create() -> Node3D:
 prepare()
 var root=Node3D.new();root.name="TalonKnife"
 var edge=MeshInstance3D.new();edge.name="SteelBlade";edge.mesh=blade;edge.material_override=steel;root.add_child(edge)
 var handle=MeshInstance3D.new();handle.mesh=handle_mesh;handle.material_override=grip;handle.position.z=.075;root.add_child(handle)
 var guard=MeshInstance3D.new();guard.mesh=guard_mesh;guard.material_override=guard_material;root.add_child(guard)
 return root
