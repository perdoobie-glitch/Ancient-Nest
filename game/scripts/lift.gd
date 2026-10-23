extends Node3D
# A fixed updraft, not a moving platform. Position tests are replay-safe.
var clock: float=0
var clock_source: Callable
var kit: NestKit
var upper_height: float=13.8
var map_scale: float=1.0
var shaft_position=Vector2(39,0)
func _ready() -> void:
	position=Vector3(39,0,0)
	kit.cylinder(self,Vector3(0,-.12,0),2.35,.24,kit.dark,true)
	for height in [.08,.45,1.0]:kit.ring(self,Vector3(0,height,0),1.9,kit.lamp)
	var glow=kit.material(Color(.18,.7,1,.075))
	glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	kit.cylinder(self,Vector3(0,upper_height*.5,0),1.8,upper_height,glow)
func _physics_process(delta: float) -> void:
	clock=clock_source.call() if clock_source.is_valid() else clock+delta
func apply_motion(actor: NestActor, delta: float) -> void:
	if not visible:return
	var local=to_local(actor.global_position)
	if Vector2(local.x,local.z).length()>2.15 or local.y<-.25 or local.y>upper_height+1.5:return
	actor.controlled.y=maxf(actor.controlled.y,8.0)
	# Ease toward the existing top landing to the south; steering still works.
	if local.y>upper_height-1.0:
		var exit=Vector2(global_basis.z.x,global_basis.z.z).normalized();var horizontal=Vector2(actor.controlled.x,actor.controlled.z)
		var speed=horizontal.dot(exit);horizontal+=exit*(move_toward(speed,4.8,18.0*delta)-speed)
		actor.controlled.x=horizontal.x;actor.controlled.z=horizontal.y
