extends SceneTree
func _initialize():call_deferred("run")
func legacy_find(game,anchor: Vector3,radius: float,height: float,exclude: Array[RID]=[],box: bool=false,occupied: Array=[]) -> Vector3:
 var candidates=[anchor]
 for ring in [1.25,2.5,3.75,5.0,7.5]:
  for i in range(12):candidates.append(anchor+Vector3(cos(TAU*i/12)*ring,0,sin(TAU*i/12)*ring))
 for nav in game.arena.nav_points:
  if absf(nav.y-anchor.y)<.65:candidates.append(nav+Vector3.UP*.08)
 # Floor-correct fallback for invalid elevated / roof markers. Every option is
 # still checked against physical ground and a complete standing volume.
 var fallback=game.arena.nav_points.duplicate()
 fallback.sort_custom(func(a,b):return a.distance_squared_to(anchor)<b.distance_squared_to(anchor))
 for nav in fallback:candidates.append(nav+Vector3.UP*.08)
 for candidate in candidates:
  var point=NestPlacementSafety.ground(game,candidate,radius,exclude)
  if not point.is_finite():continue
  var crowded=false
  for item in occupied:
   var position: Vector3=item.position if item is Dictionary else item
   var spacing: float=float(item.radius) if item is Dictionary else NestActor.BODY_RADIUS+.15
   if absf(point.y-position.y)<height and Vector2(point.x-position.x,point.z-position.z).length()<radius+spacing:crowded=true;break
  if crowded or not NestPlacementSafety.clear(game,point,radius,height,exclude,box):continue
  return point
 return Vector3.INF

func run():
 seed(12015);var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;var checks=0
 for map in [0,1,2]:
  game.apply_game_type_settings(NestMatchPresets.create(2,map));await physics_frame;await physics_frame
  var anchors=[]
  for spawn in game.arena.spawns[0]+game.arena.spawns[1]:anchors.append(spawn)
  for point in game.arena.sites+game.arena.pads:anchors.append(point)
  for i in range(12):anchors.append(Vector3(randf_range(-45,45),randf_range(-6,18),randf_range(-35,35)))
  for anchor in anchors:
   for blocked in [false,true]:
    var occupied=[anchor] if blocked else []
    var radius=NestActor.BODY_RADIUS+.05;var height=NestActor.STAND_HEIGHT
    var old=legacy_find(game,anchor,radius,height,[],false,occupied)
    var current=NestPlacementSafety.find(game,anchor,radius,height,[],false,occupied)
    assert((not old.is_finite() and not current.is_finite()) or old.is_equal_approx(current),"Spawn fallback changed: "+str(map)+" "+str(anchor));checks+=1
  print("PLACEMENT EQUIVALENCE map=",map," checks=",checks)
 print("PASS placement candidate ordering and collision checks preserved ",checks)
 game.queue_free();await create_timer(.2).timeout;quit()
