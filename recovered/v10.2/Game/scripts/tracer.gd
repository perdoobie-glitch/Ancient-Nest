class_name NestTracer
extends MeshInstance3D
# Traveling cosmetics only. The hit query has already finished before setup.
const START_ALPHA: float = .10
const VISIBILITY_MULTIPLIER: float = 1.25
const SPEED: float = 450.0
const LENGTH: float = 2.2
const WIDTH: float = .03
static var ribbon: ArrayMesh
var game
var origin: Vector3
var direction: Vector3
var distance: float
var born: float
var expires: float
var material: StandardMaterial3D
var sniper_trail: bool=false
var projectile_trail: bool=false
var initial_opacity: float=START_ALPHA
var streak_width: float=WIDTH
static func shared_mesh() -> ArrayMesh:
 if ribbon==null:
  ribbon=ArrayMesh.new();var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.5,0,-1),Vector3(.5,0,-1),Vector3(-.5,0,0),Vector3(.5,0,0)])
  arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color.WHITE,Color.WHITE])
  arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,2,1,3]);ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return ribbon
func appearance(opacity: float) -> void:
 mesh=shared_mesh();material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.vertex_color_use_as_albedo=true
 material.albedo_color=Color(1,.92,.72,clampf(opacity,0,1));material_override=material
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func setup(start: Vector3, finish: Vector3, opacity: float=START_ALPHA, sniper: bool=false) -> void:
 var visible_opacity=clampf(opacity*VISIBILITY_MULTIPLIER,0,1)
 appearance(visible_opacity);initial_opacity=visible_opacity;origin=start;distance=start.distance_to(finish);direction=(finish-start).normalized()
 sniper_trail=sniper;born=game.now;expires=born+(2.0 if sniper else minf(.5,distance/SPEED+.03));update_streak(.001)
func update_streak(age: float) -> void:
 var head=minf(distance,maxf(.10,age*SPEED));var tail=0.0 if sniper_trail else maxf(.08,head-LENGTH)
 visible=head>tail
 global_position=origin+direction*head
 if direction.length_squared()>.5:global_basis=Basis.looking_at(-direction,Vector3.FORWARD if absf(direction.y)>.99 else Vector3.UP)
 scale=Vector3(streak_width,1,maxf(.001,head-tail))
func _process(_delta: float) -> void:
 if projectile_trail:return
 if not game.running or game.now>=expires:queue_free();return
 update_streak(game.now-born)
 material.albedo_color.a=initial_opacity*clampf((expires-game.now)/(1.5 if sniper_trail else .025),0,1)
static func attach_projectile(parent: Node3D, direction: Vector3, opacity: float) -> NestTracer:
 var trail=NestTracer.new();trail.projectile_trail=true;trail.appearance(clampf(opacity*VISIBILITY_MULTIPLIER,0,1));parent.add_child(trail)
 trail.global_basis=Basis.looking_at(-direction,Vector3.FORWARD if absf(direction.y)>.99 else Vector3.UP);trail.scale=Vector3(WIDTH,1,LENGTH);trail.set_process(false)
 return trail
