extends SceneTree
var game
var c
var failures=0
var checks=0
var observed_low=INF
var observed_high=-INF
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func pulse(pressed: bool):
 var event=InputMap.action_get_events("forward")[0].duplicate();event.pressed=pressed;event.echo=false;Input.parse_input_event(event)
func walk(target: Vector3) -> bool:
 var actor=game.player;var path=c.world.route(actor.global_position,target)
 if path.is_empty():print("NO_ROUTE ",actor.global_position," -> ",target);return false
 for waypoint in path:
  var count=0;var progress_at=0
  var last_distance=Vector2(actor.position.x-waypoint.x,actor.position.z-waypoint.z).length()
  var limit=360+ceili(last_distance*30) # Budget at least 0.5 seconds per metre, plus six seconds.
  while Vector2(actor.position.x-waypoint.x,actor.position.z-waypoint.z).length()>.65:
   count+=1
   var remaining=Vector2(actor.position.x-waypoint.x,actor.position.z-waypoint.z).length()
   if remaining<last_distance-.35:last_distance=remaining;progress_at=count
   if count>limit or count-progress_at>180:
    pulse(false);print("STUCK ",actor.position," -> ",waypoint," controlled ",actor.controlled," external ",actor.external," velocity ",actor.velocity," floor ",actor.is_on_floor())
    for collision_index in range(actor.get_slide_collision_count()):
     var contact=actor.get_slide_collision(collision_index);var body=contact.get_collider()
     print("CONTACT ",body.get_path()," position ",body.global_position," normal ",contact.get_normal()," at ",contact.get_position())
    return false
   var offset=waypoint-actor.position;actor.rotation.y=atan2(-offset.x,-offset.z);actor.eye.rotation.x=0
   pulse(true);game.input_window_focused=true;await physics_frame
   observed_low=minf(observed_low,actor.position.y);observed_high=maxf(observed_high,actor.position.y)
 pulse(false);await physics_frame
 return actor.global_position.distance_to(target)<1.5
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 c=game.campaign;c.save_store.path="user://chapter-routes.json";c.begin_solo(false)
 var requested=int(OS.get_environment("NEST_ROUTE_MISSION"))
 for mission in range(3,10):
  if requested>0 and requested!=mission:continue
  if mission<int(OS.get_environment("NEST_ROUTE_MIN")):continue
  c.journey.start_standalone(mission);c.state.phase="RADIO_READY";c.journey._remove_enemies()
  game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  await physics_frame;await physics_frame
  observed_low=game.player.position.y;observed_high=observed_low
  for stage in range(4):
   c.state.chapter_stage=stage;c.world.set_stage(stage);await physics_frame;await physics_frame
   var target=c.world.locations["objective"+str(stage)]+Vector3(0,0,2.2)
   check(await walk(target),"Chapter %d stage %d actual player reaches objective through route"%[mission,stage])
   check(c.near(game.player,"objective"+str(stage)),"Chapter %d stage %d physical objective has clear interaction sightline"%[mission,stage])
   var points=c.world.encounter_spawns(stage);var valid=points.size()>=int(c.journey.chapter(mission).stages[stage].enemies)
   for point in points:
    if c.world.blocked_point(point):valid=false
    var floor_query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*1.2,1)
    var floor_hit=c.world.get_world_3d().direct_space_state.intersect_ray(floor_query)
    if floor_hit.is_empty() or absf(floor_hit.position.y-c.world.surface_height(point))>.15:valid=false
   check(valid,"Chapter %d stage %d has enough unobstructed Annu positions"%[mission,stage])
   var anchors=c.world.weapon_cache_points()
   for cache_index in range(anchors.size()):
    var cache_stage=[0,1,2,0,0,3][cache_index] if mission==9 else cache_index/2
    if cache_stage!=stage:continue
    check(await walk(anchors[cache_index]+Vector3(0,0,1.5)),"Chapter %d cache %d reached using actual movement over ramps and terraces"%[mission,cache_index])
   if stage in [1,2]:
    var index=stage-1
    check(await walk(c.world.locations["evidence"+str(index)]+Vector3(0,0,2.2)),"Chapter %d optional record %d physically reachable"%[mission,index])
  check(await walk(c.world.locations.supply3+Vector3(0,0,2.2)),"Chapter %d final supply rack physically reachable"%mission)
  var required_span={3:9,4:17,5:12,6:10,7:23,8:14,9:11}
  check(observed_high-observed_low>=required_span[mission],"Chapter %d actual player elevation span %.2fm exceeds %dm"%[mission,observed_high-observed_low,required_span[mission]])
 c.exit_campaign();game.queue_free();c=null;game=null;await process_frame;await process_frame
 print("CHAPTER ROUTES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
