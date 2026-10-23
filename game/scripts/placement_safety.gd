class_name NestPlacementSafety
extends RefCounted
const FOOT_GAP=.065
static func ground(game,point: Vector3,radius: float,exclude: Array[RID]=[]) -> Vector3:
 if not point.is_finite():return Vector3.INF
 var center=Vector3.INF
 for offset in [Vector3.ZERO,Vector3(radius*.7,0,0),Vector3(-radius*.7,0,0),Vector3(0,0,radius*.7),Vector3(0,0,-radius*.7)]:
  var hit=game.trace(point+offset+Vector3.UP*.55,point+offset-Vector3.UP*.8,1,exclude)
  if hit.is_empty() or hit.normal.y<.8:return Vector3.INF
  if center==Vector3.INF:center=hit.position
  elif absf(center.y-hit.position.y)>.18:return Vector3.INF
 if not game.arena.has_walk_support(center,.32):return Vector3.INF
 return Vector3(point.x,center.y+FOOT_GAP,point.z)
static func clear(game,point: Vector3,radius: float,height: float,exclude: Array[RID]=[],box: bool=false) -> bool:
 if not point.is_finite():return false
 # Authored cover footprints also protect against decorative props whose
 # visual mesh does not own a physical collider.
 for cover in game.arena.floor_cover:
  if absf(point.y-cover.pos.y)>.4:continue
  if absf(point.x-cover.pos.x)<cover.size.x*.5+radius and absf(point.z-cover.pos.z)<cover.size.y*.5+radius:return false
 var shape: Shape3D
 if box:
  var volume=BoxShape3D.new();volume.size=Vector3(radius*2,height,radius*2);shape=volume
 else:
  var capsule=CapsuleShape3D.new();capsule.radius=radius;capsule.height=maxf(height,radius*2);shape=capsule
 var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*height*.5);query.collision_mask=1;query.exclude=exclude;query.margin=.02
 return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
static func fit_candidate(game,candidate:Vector3,radius:float,height:float,exclude:Array[RID],box:bool,occupied:Array)->Vector3:
 var point=ground(game,candidate,radius,exclude)
 if not point.is_finite():return Vector3.INF
 for item in occupied:
  var position:Vector3=item.position if item is Dictionary else item
  var spacing:float=float(item.radius) if item is Dictionary else NestActor.BODY_RADIUS+.15
  if absf(point.y-position.y)<height and Vector2(point.x-position.x,point.z-position.z).length()<radius+spacing:return Vector3.INF
 return point if clear(game,point,radius,height,exclude,box) else Vector3.INF
static func find(game,anchor: Vector3,radius: float,height: float,exclude: Array[RID]=[],box: bool=false,occupied: Array=[]) -> Vector3:
 # Preserve candidate order; don't build/sort the map fallback unless earlier candidates fail.
 var candidates=[anchor]
 for ring in [1.25,2.5,3.75,5.0,7.5]:
  for i in range(12):candidates.append(anchor+Vector3(cos(TAU*i/12)*ring,0,sin(TAU*i/12)*ring))
 for candidate in candidates:
  var point=fit_candidate(game,candidate,radius,height,exclude,box,occupied)
  if point.is_finite():return point
 for nav in game.arena.nav_points:
  if absf(nav.y-anchor.y)>=.65:continue
  var point=fit_candidate(game,nav+Vector3.UP*.08,radius,height,exclude,box,occupied)
  if point.is_finite():return point
 var fallback=game.arena.nav_points.duplicate()
 fallback.sort_custom(func(a,b):return a.distance_squared_to(anchor)<b.distance_squared_to(anchor))
 for nav in fallback:
  var point=fit_candidate(game,nav+Vector3.UP*.08,radius,height,exclude,box,occupied)
  if point.is_finite():return point
 return Vector3.INF
static func spawn(game,actor,anchors: Array) -> Vector3:
 var occupied=[]
 for other in game.actors:
  if other!=actor and other.alive:occupied.append(other.global_position)
 var sorted=anchors.duplicate();sorted.shuffle()
 var best=Vector3.INF;var score=-INF
 for anchor in sorted:
  var point=ground(game,anchor,NestActor.BODY_RADIUS+.05,actor.ray_exclusions())
  if not clear(game,point,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT,actor.ray_exclusions()):continue
  var rank=randf()*2;var crowded=false
  for other in game.actors:
   if other==actor or not other.alive:continue
   var distance=point.distance_to(other.global_position)
   if absf(point.y-other.global_position.y)<NestActor.STAND_HEIGHT and Vector2(point.x-other.global_position.x,point.z-other.global_position.z).length()<NestActor.BODY_RADIUS*2+.2:crowded=true;break
   if other.faction!=actor.faction:
    rank+=minf(distance,30)*.12
    if game.trace(point+Vector3.UP*NestActor.EYE_HEIGHT,other.eye.global_position,1,actor.ray_exclusions()).is_empty():rank-=15
  if not crowded and rank>score:score=rank;best=point
 if best.is_finite():return best
 for anchor in sorted:
  var point=find(game,anchor,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT,actor.ray_exclusions(),false,occupied)
  if point.is_finite():return point
 return Vector3.INF
static func prepare(game) -> bool:
 var ok=true;var repairs=[];var reserved=[]
 for body in game.arena.find_children("*","StaticBody3D",true,false):body.force_update_transform()
 for team in [0,1]:
  for i in range(game.arena.spawns[team].size()):
   var old=game.arena.spawns[team][i];var point=find(game,old,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT)
   if not point.is_finite():ok=false;continue
   if point.distance_to(old)>.2:repairs.append("spawn %d/%d"%[team,i])
   game.arena.spawns[team][i]=point
 for i in range(2):
  var exclude: Array[RID]=[]
  for body in game.arena.deposits[i].find_children("*","StaticBody3D",true,false):exclude.append(body.get_rid())
  var old=game.arena.sites[i];var point=find(game,old,1.3,2.6,exclude,true,reserved)
  if point.is_finite():
   point.y-=FOOT_GAP-.02
   if point.distance_to(old)>.2:repairs.append("bomb / mine "+str(i))
   reserved.append({"position":point,"radius":1.5});game.arena.sites[i]=point;game.arena.deposits[i].global_position=point;game.arena.deposit_labels[i].global_position=point+Vector3.UP*3
   for body in game.arena.deposits[i].find_children("*","StaticBody3D",true,false):body.force_update_transform()
  else:ok=false
  old=game.flag_bases[i];point=find(game,old,.8,2.5,[],false,reserved)
  if point.is_finite():
   if point.distance_to(old)>.2:repairs.append("flag "+str(i))
   reserved.append({"position":point,"radius":.9});game.flag_bases[i]=point;game.arena.flag_positions[i]=point
   if game.flag_nodes.size()==2:game.flag_nodes[i].base.global_position=point+Vector3.UP*.03
  else:ok=false
 game.arena.set_meta("placement_repairs",repairs);game.arena.set_meta("placement_blocked",not ok)
 return ok
static func dropped(game,point: Vector3,radius: float,height: float,fallback: Vector3) -> Vector3:
 var grounded=game.trace(point+Vector3.UP*.3,point-Vector3.UP*30,1)
 var anchor=grounded.position+Vector3.UP*.08 if not grounded.is_empty() else fallback
 return find(game,anchor,radius,height)
