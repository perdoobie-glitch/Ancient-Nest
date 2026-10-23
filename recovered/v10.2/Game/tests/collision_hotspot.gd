extends SceneTree
const SPOT=Vector3(34.27474,.028492,2.218842)
func _initialize():call_deferred("run")
func measure(actor,label):
 var values=[]
 for tick in range(45):
  await physics_frame
  var stamp=Time.get_ticks_usec();actor.movement_step(Vector2.ZERO,false,0,0,1./60)
  values.append(Time.get_ticks_usec()-stamp)
 values.sort();print("HOTSPOT ",label," median_us=",values[22]," p95_us=",values[42]," at=",actor.global_position)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_process(false);game.set_physics_process(false)
 var actor=game.player;actor.set_physics_process(false);actor.global_position=SPOT;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.velocity=Vector3.ZERO
 var candidates=[]
 for body in game.arena.find_children("*","StaticBody3D",true,false):
  if body.collision_layer==0:continue
  for child in body.get_children():
   if not child is CollisionShape3D or child.shape==null or child.disabled:continue
   var box=child.global_transform*child.shape.get_debug_mesh().get_aabb()
   if box.intersects(AABB(SPOT-Vector3(1.5,1.5,1.5),Vector3(3,4,3))):
    print("NEARBY ",body.get_path()," ",child.shape.get_class()," bounds=",box)
    candidates.append({"body":body,"child":child,"shape":child.shape,"layer":body.collision_layer})
 await measure(actor,"all colliders")
 for item in candidates:
  if not item.shape is ConvexPolygonShape3D:continue
  var points=item.shape.points
  print("CONVEX ",item.body.get_path()," raw point count=",points.size())
  var bounds=AABB(points[0],Vector3.ZERO)
  for point in points:bounds=bounds.expand(point)
  var corners=0;var rectangular=true
  for point in points:
   var bits=0
   for axis in range(3):
    if absf(point[axis]-bounds.position[axis])<.00001:pass
    elif absf(point[axis]-bounds.end[axis])<.00001:bits|=1<<axis
    else:rectangular=false
   corners|=1<<bits
  if not rectangular or corners!=255:
   var unique=PackedVector3Array();var seen={}
   for point in points:
    if not seen.has(point):seen[point]=true;unique.append(point)
   var clean=ConvexPolygonShape3D.new();clean.points=unique;clean.margin=item.shape.margin
   print("EXACT UNIQUE HULL ",points.size()," -> ",clean.points.size())
   item.child.shape=clean;await physics_frame
   await measure(actor,"cleaned exact hull "+str(item.body.get_path()))
   item.child.shape=item.shape;await physics_frame
   continue
  var prior=item.child.transform
  var box=BoxShape3D.new();box.size=bounds.size;box.margin=item.shape.margin
  item.child.position+=item.child.basis*bounds.get_center();item.child.shape=box
  await physics_frame
  await measure(actor,"native BOX "+str(item.body.get_path()))
  item.child.shape=item.shape;item.child.transform=prior;await physics_frame
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit()
