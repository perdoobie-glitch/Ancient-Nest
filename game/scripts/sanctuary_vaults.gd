class_name NestSanctuaryVaults
extends RefCounted
## Wall-mounted visual inlays: no collision, lights, particles or script ticks.
static var door_mesh: BoxMesh
static var frame_mesh: ArrayMesh
static var core_mesh: QuadMesh
static var plasma: ShaderMaterial
static var vault_gold: StandardMaterial3D
const STATIONS=[
 [Vector3(-9.64,2.15,0),PI/2], [Vector3(9.64,2.15,3),-PI/2],
 [Vector3(-9.64,9.15,0),PI/2], [Vector3(9.64,9.15,3),-PI/2],
 [Vector3(-16,2.15,-19.34),0.0], [Vector3(18,2.15,-19.34),0.0]
]
static func quad(tool: SurfaceTool, points: Array) -> void:
 for index in [0,1,2,0,2,3]:
  tool.set_normal(Vector3.FORWARD*-1);tool.add_vertex(points[index])
static func ring(tool: SurfaceTool, outer: float, inner: float, depth: float, segments: int=32) -> void:
 for i in range(segments):
  var a=i*TAU/segments;var b=(i+1)*TAU/segments
  quad(tool,[Vector3(sin(a)*inner,cos(a)*inner,depth),Vector3(sin(a)*outer,cos(a)*outer,depth),Vector3(sin(b)*outer,cos(b)*outer,depth),Vector3(sin(b)*inner,cos(b)*inner,depth)])
static func bar(tool: SurfaceTool, center: Vector2, size: Vector2, depth: float) -> void:
 var low=center-size*.5;var high=center+size*.5
 quad(tool,[Vector3(low.x,low.y,depth),Vector3(low.x,high.y,depth),Vector3(high.x,high.y,depth),Vector3(high.x,low.y,depth)])
static func prepare() -> void:
 if frame_mesh!=null:return
 var metal=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES)
 ring(metal,1.24,1.10,.018);ring(metal,1.025,.95,.025);ring(metal,.76,.72,.035)
 for side in [-1,1]:
  bar(metal,Vector2(side*1.30,0),Vector2(.065,2.65),.02)
  bar(metal,Vector2(0,side*1.36),Vector2(2.66,.10),.02)
  for level in [-.83,0,.83]:bar(metal,Vector2(side*1.36,level),Vector2(.18,.05),.022)
 for i in range(8):
  var a=i*TAU/8;var p=Vector2(sin(a),cos(a))*1.16
  bar(metal,p,Vector2(.085,.085),.03)
 frame_mesh=metal.commit()
 door_mesh=BoxMesh.new();door_mesh.size=Vector3(2.78,2.92,.12)
 core_mesh=QuadMesh.new();core_mesh.size=Vector2(1.40,1.40)
 plasma=ShaderMaterial.new();plasma.shader=load("res://assets/sanctuary_plasma.gdshader")
static func part(parent: Node3D, mesh: Mesh, material: Material, name: String) -> MeshInstance3D:
 var item=MeshInstance3D.new();item.name=name;item.mesh=mesh;item.material_override=material
 item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(item);return item
static func build(arena: NestArena) -> void:
 prepare()
 if vault_gold==null:
  vault_gold=arena.kit.gold.duplicate();vault_gold.resource_name="Sanctuary shared vault gold"
  vault_gold.albedo_color=Color("d1af62");vault_gold.roughness=.34
  vault_gold.cull_mode=BaseMaterial3D.CULL_DISABLED
 for i in STATIONS.size():
  var station=Node3D.new();station.name="SanctuaryEnergyVault%d"%i;station.position=STATIONS[i][0];station.rotation.y=STATIONS[i][1];arena.add_child(station)
  part(station,door_mesh,arena.kit.dark,"RecessedVaultDoor").position.z=.015
  part(station,frame_mesh,vault_gold,"GoldLockingRings").position.z=.08
  var core=part(station,core_mesh,plasma,"PlasmaEnergyCore");core.position.z=.13;core.visibility_range_end=55
  core.set_meta("sanctuary_plasma_core",true)
 # Inset courses on existing bearing walls; never across doors, ramps or floors.
 for floor_y in [0.0,7.0]:
  for item in [[-9.64,0.0,PI/2],[9.64,3.0,-PI/2]]:
   var trim=Node3D.new();trim.position=Vector3(item[0],floor_y,item[1]);trim.rotation.y=item[2];arena.add_child(trim)
   for y in [.46,3.80]:
    var band=arena.kit.box(trim,Vector3(0,y,.01),Vector3(7.4,.045,.025),arena.kit.gold);band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   for x in [-3.3,3.3]:
    var seam=arena.kit.box(trim,Vector3(x,2.12,.01),Vector3(.045,3.36,.025),arena.kit.gold);seam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.set_meta("sanctuary_vaults",{"vaults":STATIONS.size(),"plasma_meshes":STATIONS.size(),"runtime_ticks":0,"lights":0,"particles":0,"collision_shapes":0})
