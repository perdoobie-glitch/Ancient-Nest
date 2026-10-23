class_name NestPlasmaSwordArt
extends RefCounted
const GREEN=Color("18d954")
static var kit: NestKit
static var green: StandardMaterial3D
static var grip: StandardMaterial3D
static var shell: StandardMaterial3D
static var blade_mesh: ArrayMesh
static func prepare() -> void:
 if kit!=null:return
 kit=NestKit.new();green=kit.material(GREEN,.25);green.emission_enabled=true;green.emission=GREEN;green.emission_energy_multiplier=.35;green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;green.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;green.albedo_color.a=.87;green.cull_mode=BaseMaterial3D.CULL_DISABLED
 grip=kit.material(Color("263d32"),.4);shell=kit.material(Color("d7e4d5"),.7)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var v=[Vector3(-.033,0,-.08),Vector3(.033,0,-.08),Vector3(-.05,0,-.63),Vector3(.05,0,-.63),Vector3(0,0,-.94),Vector3(0,.016,-.45),Vector3(0,-.016,-.45)]
 for tri in [[0,1,5],[0,5,2],[2,5,4],[4,5,3],[3,5,1],[1,0,6],[0,2,6],[2,4,6],[4,3,6],[3,1,6]]:
  for i in tri:st.add_vertex(v[i])
 st.generate_normals();blade_mesh=st.commit()
static func create(active: bool=true) -> Node3D:
 prepare()
 var root=Node3D.new();root.name="GreenPlasmaSword"
 kit.cylinder(root,Vector3(0,0,.065),.025,.17,grip).rotation.x=PI*.5
 kit.box(root,Vector3.ZERO,Vector3(.145,.035,.035),shell)
 var gem=kit.sphere(root,Vector3(0,.028,.014),.022,green);gem.name="HiltCrystal"
 var blade=MeshInstance3D.new();blade.name="PlasmaBlade";blade.mesh=blade_mesh;blade.material_override=green;blade.visible=active;root.add_child(blade)
 return root
static func activate(root: Node3D, strength: float) -> void:
 if not is_instance_valid(root):return
 var blade=root.get_node_or_null("PlasmaBlade")
 if blade==null:return
 blade.visible=strength>0;blade.scale.z=maxf(.001,strength)
