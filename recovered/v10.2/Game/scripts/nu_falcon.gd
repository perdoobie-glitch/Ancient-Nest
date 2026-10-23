class_name NestNuFalcon
extends Node3D
const HIT_RADIUS: float=.25
var game
var owner_actor: NestActor
var flight
var velocity=Vector3.ZERO
var yaw: float=0
var pitch: float=0
var assist_enabled: bool=true
var boost_active: bool=false
var previous_boost: float=1.0
var controls=Vector3.ZERO # forward thrust, banking, flap/dive
var control_at: float=-INF
var visual: Node3D
var hurtbox: Area3D
var shape: BoxShape3D
var target_position=Vector3.ZERO
var target_velocity=Vector3.ZERO
var visual_error=Vector3.ZERO
var round_id: int
var life: int
var dead: bool=false
var last_seq: int=-1
var spots: Array[int]=[]
var next_spot: float=0
var clock: float=0
func _ready() -> void:
 round_id=game.round_number;life=owner_actor.life_id;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
 visual=NestFalconArt.create();add_child(visual)
 hurtbox=Area3D.new();hurtbox.collision_layer=8;hurtbox.collision_mask=0;hurtbox.set_meta("nu",self);hurtbox.monitoring=false;add_child(hurtbox)
 shape=BoxShape3D.new();shape.size=Vector3(NestFalconArt.WINGSPAN,.38,NestFalconArt.BODY_LENGTH+.1)
 var collision=CollisionShape3D.new();collision.shape=shape;hurtbox.add_child(collision)
func _physics_process(delta: float) -> void:
 if game.matchmaking.blocks_simulation():return
 if dead:return
 if not game.running or game.finished or round_id!=game.round_number or not is_instance_valid(owner_actor) or not owner_actor.alive or owner_actor.character!=1 or life!=owner_actor.life_id or not game.game_type.nu_enabled:
  destroy("ended");return
 var local=owner_actor.local_player
 if game.is_client() and not local:
  global_position=global_position.lerp(target_position,1-exp(-delta*18));velocity=target_velocity
 else:
  if local:flight.read_controls(self)
  elif game.now-control_at>.25:controls=Vector3.ZERO;boost_active=false
  var factor=3.0 if boost_active else 1.0
  if factor!=previous_boost:velocity*=factor/previous_boost;previous_boost=factor
  velocity=step_velocity(velocity/factor,yaw,pitch,controls,delta,assist_enabled)*factor
  var step=velocity*delta
  if not game.is_client():
   var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.from_euler(Vector3(pitch,yaw,0)),global_position);query.motion=step;query.collision_mask=15;query.collide_with_areas=true;query.exclude=[hurtbox.get_rid()]
   var space=get_world_3d().direct_space_state
   if not space.intersect_shape(query,1).is_empty():destroy("impact");return
   var fractions=space.cast_motion(query)
   if fractions[0]<1.0:global_position+=step*fractions[0];destroy("impact");return
  global_position+=step
 if global_position.y<-100 or absf(global_position.x)>250 or absf(global_position.z)>250:destroy("out of bounds");return
 clock+=delta;rotation=Vector3(pitch,yaw,0);NestFalconArt.animate(visual,clock,controls.z>0,-controls.y*.22)
 if not game.is_client() and game.now>=next_spot:next_spot=game.now+.1;update_spots()
static func step_velocity(current: Vector3, view_yaw: float, view_pitch: float, input: Vector3, delta: float, assist: bool=false) -> Vector3:
 var forward=-Basis.from_euler(Vector3(view_pitch,view_yaw,0)).z
 var speed=current.length()
 # Gravity, speed-dependent lift, drag and finite wing propulsion. No hover.
 var lift=clampf(speed*speed*.07,0,11.0)*maxf(.15,cos(view_pitch))
 var acceleration=Vector3.DOWN*9.8+Vector3.UP*lift-current*(.28+.018*speed)
 acceleration+=forward*(3.0+maxf(-.5,input.x)*8.0+maxf(0,input.z)*7.0)
 acceleration+=Vector3.UP*maxf(0,input.z)*9.0+Vector3.DOWN*maxf(0,-input.z)*10.0
 var desired=forward*speed
 acceleration+=(desired-current)*(3.0 if assist else 1.6)
 if assist:
  # Gentle cruise/heading guidance applies forces, never camera smoothing,
  # teleports, wall avoidance or free-camera hovering.
  var cruise=12.0+maxf(0,input.x)*4.0-maxf(0,-input.x)*5.0
  acceleration+=forward*clampf((cruise-current.dot(forward))*.75,-2,5)
  if absf(view_pitch)<.35 and absf(input.z)<.01:
   acceleration.y+=clampf(9.8-lift-current.y*1.25,-4,7)
 return (current+acceleration*delta).limit_length(24)
func update_spots() -> void:
 spots.clear()
 var direction=-Basis.from_euler(Vector3(pitch,yaw,0)).z
 for actor in game.actors:
  if not actor.alive or actor.faction==owner_actor.faction or actor.cloak_deadline>game.now:continue
  var point=actor.global_position+Vector3.UP*NestActor.EYE_HEIGHT
  var delta=point-global_position
  if delta.length()>80 or direction.dot(delta.normalized())<.5:continue
  if game.vision_clear(global_position,point):
   spots.append(actor.net_id);game.record_nu_sighting(owner_actor.faction,actor)
func destroy(_reason: String) -> void:
 if dead:return
 # Client flight is predicted visually; only the host declares collision/death.
 if game.is_client():return
 dead=true;hurtbox.collision_layer=0;flight.finish(owner_actor);queue_free()
