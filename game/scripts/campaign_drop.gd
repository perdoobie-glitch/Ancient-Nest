class_name NestCampaignDrop
extends RigidBody3D
var campaign
var drop_id=0
var kind=""
var rounds=0
var reserve=0
var born=0.0
var claimed_by=0
var claimed_at=0.0
var cache_key=""
var grip_center=Vector3.ZERO
var visual: Node3D
var target=Transform3D.IDENTITY
var target_velocity=Vector3.ZERO
var received_at=0.0
var pause_held=false
var saved_velocity=Vector3.ZERO
var saved_spin=Vector3.ZERO
func _ready():
 mass=2.5;collision_layer=0;collision_mask=1;continuous_cd=true;linear_damp=.6;angular_damp=1.8
 var material=PhysicsMaterial.new();material.friction=.8;material.bounce=.15;physics_material_override=material
 visual=Node3D.new();add_child(visual);visual.scale=Vector3.ONE*NestActor.SIZE
 var art=NestWeaponArt.create(kind,1);visual.add_child(art);NestRigidBatch.build(art)
 var bounds=AABB();var first=true
 for mesh in art.find_children("*","MeshInstance3D",true,false):
  var local=global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
  bounds=local if first else bounds.merge(local);first=false
 var box=BoxShape3D.new();box.size=Vector3(clampf(bounds.size.x,.12,1.5),clampf(bounds.size.y,.12,.5),clampf(bounds.size.z,.25,1.6))
 var collision=CollisionShape3D.new();collision.shape=box;collision.position=bounds.get_center();grip_center=collision.position;add_child(collision)
 freeze=campaign.game.is_client();physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF if freeze else Node.PHYSICS_INTERPOLATION_MODE_ON;target=global_transform
func pickup_point() -> Vector3:return to_global(grip_center)+Vector3.UP*.12
func pack() -> Dictionary:
 return {"id":drop_id,"kind":kind,"rounds":rounds,"reserve":reserve,"born":born,"xf":global_transform,"v":linear_velocity,"claimed":claimed_by,"claim_at":claimed_at,"cache_key":cache_key}
func animate_pickup(slot: int):
 if claimed_by>0:return
 claimed_by=slot;claimed_at=campaign.game.now;freeze=true;collision_mask=0
 var actor=campaign.game.actor_by_id(slot)
 var destination=Vector3.UP*.8
 if actor!=null:destination=to_local(actor.eye.global_position+actor.aim_direction()*.5)
 var tween=create_tween();tween.set_parallel(true);tween.tween_property(visual,"position",destination,.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);tween.tween_property(visual,"scale",Vector3.ONE*.05,.22);tween.tween_property(visual,"rotation",Vector3(0,PI*.5,0),.22)
func _physics_process(_delta):
 if campaign.game.is_client() or claimed_by>0:return
 var pause=campaign.frozen_actors()
 if pause and not pause_held:
  saved_velocity=linear_velocity;saved_spin=angular_velocity;freeze=true;pause_held=true
 elif not pause and pause_held:
  freeze=false;linear_velocity=saved_velocity;angular_velocity=saved_spin;pause_held=false
func _integrate_forces(state: PhysicsDirectBodyState3D):
 state.linear_velocity=state.linear_velocity.limit_length(20);state.angular_velocity=state.angular_velocity.limit_length(10)
func _process(delta):
 if campaign.game.is_client() and claimed_by==0:
  var age=minf(.15,(Time.get_ticks_msec()/1000.0)-received_at)
  global_position=global_position.lerp(target.origin+target_velocity*age,minf(1,delta*15))
  global_basis=global_basis.orthonormalized().slerp(target.basis.orthonormalized(),minf(1,delta*15))
