class_name NestDeathBody
extends RigidBody3D
## Cosmetic physical body: world collision only, never living-player damage.
const LIFETIME: float = 3.0
const VISUALS = [preload("res://scenes/characters/NakiVisual.tscn"),preload("res://scenes/characters/AnnuVisual.tscn")]
var body_key: String
var age: float = 0
var skeleton: Skeleton3D
var pivot: Node3D
var hitboxes: Array[Area3D] = []
var offsets: Array[Dictionary] = []
var initial_pose: Array = []
var applied_impacts: Dictionary = {}
var pending_impulses: Array[Dictionary] = []
var relax: Dictionary = {}
var spec: Dictionary

static func snapshot(actor: NestActor, key: String, reason: String) -> Dictionary:
	var center=actor.global_transform*Vector3(0,NestActor.STAND_CENTER,0)
	var root=Transform3D(actor.global_basis,center)
	var poses: Array=[]
	if actor.skeleton!=null:
		for i in actor.skeleton.get_bone_count():poses.append(actor.skeleton.get_bone_pose(i))
	var direction=-actor.global_basis.z
	var point=center+Vector3.UP*.3
	var fresh=actor.game.now-actor.last_damage<.1 and reason in ["headshot","bullet","heavy","explosion","melee"]
	if fresh:
		if actor.last_impact_point.is_finite():point=actor.last_impact_point
		if actor.last_damage_origin.is_finite():direction=(point-actor.last_damage_origin).normalized()
	if direction.length_squared()<.01:direction=-actor.global_basis.z
	var push=6.0 if reason in ["explosion","heavy"] else 3.5 if reason=="melee" else 3.5 if reason=="headshot" else 2.1
	var inherited=actor.velocity.limit_length(35)
	return {"key":key,"character":actor.character,"root":root,"visual":root.affine_inverse()*actor.model.global_transform,"poses":poses,"velocity":inherited,"impulse":(direction*push+Vector3.UP*.5)*80.0,"point":point,"born":actor.game.now,"headshot":reason=="headshot","fall_direction":direction}

func _ready() -> void:
	body_key=spec.key
	mass=80;collision_layer=0;collision_mask=1;continuous_cd=true
	linear_damp=.65;angular_damp=1.5
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	var material=PhysicsMaterial.new();material.friction=.75;material.bounce=0;physics_material_override=material
	var capsule=CapsuleShape3D.new();capsule.height=NestActor.STAND_HEIGHT*.94;capsule.radius=NestActor.BODY_RADIUS*.75
	var shape=CollisionShape3D.new();shape.shape=capsule;add_child(shape)
	pivot=Node3D.new();pivot.transform=spec.visual;add_child(pivot)
	var visual:Node3D=VISUALS[clampi(int(spec.character),0,1)].instantiate();pivot.add_child(visual);NestReferenceGear.apply_trim(visual,int(spec.character))
	for animator in visual.find_children("*","AnimationPlayer",true,false):
		animator.stop();animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeletons=visual.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty():skeleton=skeletons[0]
	# Establish authored hull-to-bone offsets in the bind pose before applying
	# the victim's exact pose. No live actor, name tag or damage metadata is copied.
	for part in NestCharacterCatalog.hitboxes(int(spec.character)):
		var area=Area3D.new();area.collision_layer=16;area.collision_mask=0;area.monitoring=false
		area.set_meta("corpse",self);pivot.add_child(area)
		area.position=Vector3(part.position[0],part.position[1],part.position[2])
		var hull=CollisionShape3D.new();hull.shape=part.shape;area.add_child(hull);hitboxes.append(area)
		var bone=skeleton.find_bone(String(part.bone)) if skeleton!=null else -1
		if bone>=0:offsets.append({"area":area,"bone":bone,"transform":(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).affine_inverse()*area.global_transform})
	if skeleton!=null:
		initial_pose=spec.poses
		for i in mini(skeleton.get_bone_count(),initial_pose.size()):
			var pose:Transform3D=initial_pose[i]
			skeleton.set_bone_pose_position(i,pose.origin);skeleton.set_bone_pose_rotation(i,pose.basis.get_rotation_quaternion());skeleton.set_bone_pose_scale(i,pose.basis.get_scale())
		# Relax the held-weapon pose while the physical torso falls and tumbles.
		for data in [["upperarm_l",Vector3(0,0,.35)],["upperarm_r",Vector3(0,0,-.35)],["forearm_l",Vector3(-.3,0,0)],["forearm_r",Vector3(-.3,0,0)],["head",Vector3(.16,0,0)]]:
			var index=skeleton.find_bone(data[0])
			if index>=0:relax[index]=Quaternion.from_euler(data[1])
	update_hulls()
	linear_velocity=spec.velocity
	# A small deterministic torque prevents an upright capsule balancing on end.
	if spec.get("headshot",false):
		# Impact near the head adds leverage; bias the fall away from the shot.
		var axis=Vector3.UP.cross(spec.get("fall_direction",-global_basis.z)).normalized()
		if axis.length_squared()<.01:axis=global_basis.x
		angular_velocity=axis*4.0+global_basis.y*.20
	else:angular_velocity=global_basis*Vector3(1.7,.15,-.45)
	apply_bullet_impulse(spec.point,spec.impulse,"death")

func _physics_process(_delta: float) -> void:
	if skeleton!=null:
		var t=smoothstep(0,.22 if spec.get("headshot",false) else .45,age)
		for index in relax:
			var source:Quaternion=initial_pose[index].basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(index,source.slerp(source*relax[index],t))
	update_hulls()

func update_hulls() -> void:
	for data in offsets:data.area.global_transform=skeleton.global_transform*skeleton.get_bone_global_pose(data.bone)*data.transform

func _process(delta: float) -> void:
	age+=delta
	if age>=LIFETIME:queue_free()

func apply_bullet_impulse(point: Vector3, impulse: Vector3, shot_key: String) -> bool:
	if is_queued_for_deletion() or age>=LIFETIME or applied_impacts.has(shot_key):return false
	applied_impacts[shot_key]=true
	sleeping=false
	pending_impulses.append({"impulse":impulse.limit_length(800),"point":point})
	return true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# The first step has the correct mass/inertia. Applying the initial impulse
	# earlier can use uninitialized mass; cached node velocity writes also erase it.
	for impact in pending_impulses:state.apply_impulse(impact.impulse,(impact.point-state.transform.origin).limit_length(2.5))
	pending_impulses.clear()
	state.linear_velocity=state.linear_velocity.limit_length(40)
	state.angular_velocity=state.angular_velocity.limit_length(12)
