class_name NestRocketArt
extends RefCounted
const LENGTH: float=.65
const DIAMETER: float=.09
static var body: CylinderMesh
static var nose: CylinderMesh
static var fin: BoxMesh
static var cap: BoxMesh
static var exhaust: CylinderMesh
static var shell: StandardMaterial3D
static var dark: StandardMaterial3D
static var trim: StandardMaterial3D
static var fire: StandardMaterial3D
static func prepare() -> void:
 if body!=null:return
 shell=StandardMaterial3D.new();shell.albedo_color=Color("aab6ab");shell.metallic=.6;shell.roughness=.45
 dark=StandardMaterial3D.new();dark.albedo_color=Color("30382f");dark.roughness=.7
 trim=StandardMaterial3D.new();trim.albedo_color=Color("bfab65");trim.metallic=.6
 fire=StandardMaterial3D.new();fire.albedo_color=Color("ffb64b");fire.emission_enabled=true;fire.emission=Color("ff8f31");fire.emission_energy_multiplier=1.5
 body=CylinderMesh.new();body.top_radius=DIAMETER*.5;body.bottom_radius=DIAMETER*.5;body.height=.46;body.radial_segments=12;body.rings=1
 nose=CylinderMesh.new();nose.top_radius=0;nose.bottom_radius=DIAMETER*.5;nose.height=.19;nose.radial_segments=12;nose.rings=1
 fin=BoxMesh.new();fin.size=Vector3(.15,.008,.10)
 cap=BoxMesh.new();cap.size=Vector3(.16,.13,.025)
 exhaust=CylinderMesh.new();exhaust.top_radius=.027;exhaust.bottom_radius=0;exhaust.height=.15;exhaust.radial_segments=8;exhaust.rings=1
static func mesh(parent: Node3D,shape: Mesh,material: Material,position: Vector3,rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=shape;node.material_override=material;node.position=position;node.rotation=rotation;parent.add_child(node);return node
static func create(in_flight: bool=true) -> Node3D:
 prepare()
 var root=Node3D.new();root.name="RocketProjectile"
 mesh(root,body,shell,Vector3(0,0,.095),Vector3(PI*.5,0,0))
 mesh(root,nose,trim,Vector3(0,0,-.23),Vector3(-PI*.5,0,0))
 mesh(root,fin,dark,Vector3(0,0,.25));mesh(root,fin,dark,Vector3(0,0,.25),Vector3(0,0,PI*.5))
 if in_flight:
  var flame=mesh(root,exhaust,fire,Vector3(0,0,.395),Vector3(-PI*.5,0,0));flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return root
static func add_reload(launcher: Node3D) -> void:
 prepare()
 var hatch=Node3D.new();hatch.name="RocketReloadHatch";launcher.add_child(hatch);hatch.position=Vector3(0,.065,.32)
 mesh(hatch,cap,dark,Vector3(0,-.065,0))
 var payload=create(false);payload.name="RocketReloadPayload";launcher.add_child(payload);payload.scale=Vector3.ONE*.72;payload.visible=false
 launcher.set_meta("rocket_reload",{"hatch":hatch,"rest":hatch.transform,"payload":payload})
static func insertion(progress: float) -> float:
 return smoothstep(.32,.70,progress)
static func hand_offset(progress: float) -> Vector3:
 return Vector3(.015,-.24,.32).lerp(Vector3(.015,-.045,.08),insertion(progress))
static func animate_reload(launcher: Node3D,progress: float) -> void:
 if not launcher.has_meta("rocket_reload"):return
 var data=launcher.get_meta("rocket_reload");data.hatch.transform=data.rest
 var opening=smoothstep(.04,.15,progress)*(1-smoothstep(.79,.94,progress)) if progress>=0 else 0.0
 data.hatch.rotation.x=-opening*1.4
 data.payload.visible=progress>=.24 and progress<.73
 data.payload.position=Vector3(0,-.24,.46).lerp(Vector3(0,0,.05),insertion(progress))
