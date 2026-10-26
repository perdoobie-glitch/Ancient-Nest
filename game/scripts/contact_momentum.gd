class_name NestContactMomentum
extends RefCounted
# These impulses use the actor's existing replicated external-velocity channel.
const MAX_CONTACT_SPEED=24.0
const MAX_SLOPE_RISE=6.0
const PLAYER_MASS=80.0
static func slope_rise(horizontal: Vector3,normal: Vector3) -> float:
 if normal.y<.7 or normal.y>.999:return 0.0
 return clampf(-Vector3(normal.x,0,normal.z).dot(horizontal)/normal.y,0,MAX_SLOPE_RISE)
static func transfer(momentum: Vector3,normal: Vector3,surface_velocity: Vector3,mass=INF) -> Vector3:
 if not surface_velocity.is_finite() or normal.length_squared()<.5:return momentum
 var speed=clampf(surface_velocity.dot(normal),0,MAX_CONTACT_SPEED)
 if is_finite(mass):speed*=clampf(mass/(mass+PLAYER_MASS),0,1)
 if speed<.15:return momentum
 # Replace only the pushed component; repeated contacts cannot pump unlimited energy.
 return momentum+normal*maxf(0,speed-momentum.dot(normal))
static func contacts(actor: NestActor,replaying: bool):
 var normals=[];var pressure=0.0
 for i in range(actor.get_slide_collision_count()):
  var contact=actor.get_slide_collision(i);var normal=contact.get_normal();var surface=contact.get_collider_velocity();var body=contact.get_collider()
  normals.append(normal)
  if body is NestActor:continue
  var mass=float(body.mass) if body is RigidBody3D else INF
  # CharacterBody already carries a standing rider. Only side/ceiling impacts
  # enter external momentum here; jumping inherits the support separately.
  if normal.y<cos(actor.floor_max_angle):actor.external=transfer(actor.external,normal,surface,mass)
  pressure=maxf(pressure,surface.dot(normal))
  if body is RigidBody3D and not body.freeze and not replaying and not actor.game.is_client():
   var closing=maxf(0,-(actor.controlled+actor.external-body.linear_velocity).dot(normal))
   if closing>.2:body.apply_impulse(-normal*minf(closing*minf(body.mass,PLAYER_MASS),PLAYER_MASS*4),contact.get_position()-body.global_position)
 escape(actor,normals,pressure)
static func escape(actor: NestActor,normals: Array,pressure: float) -> bool:
 if pressure<.2:return false
 var squeezed=false
 for a in normals:
  for b in normals:
   if a.dot(b)<-.75:squeezed=true
 if not squeezed:return false
 # Search a short, unobstructed escape. No teleport and no launch through a wall.
 for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(-1,0,-1).normalized(),Vector3(1,0,-1).normalized(),Vector3(-1,0,1).normalized(),Vector3(1,0,1).normalized(),Vector3.UP]:
  if not actor.test_move(actor.global_transform,direction*.9):
   var speed=clampf(pressure*1.5+2,3,12)
   actor.external=transfer(actor.external,direction,direction*speed);return true
 return false
