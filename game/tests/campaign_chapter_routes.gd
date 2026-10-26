extends SceneTree
var game
var c
var failures=0
var checks=0
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
  var count=0
  while Vector2(actor.position.x-waypoint.x,actor.position.z-waypoint.z).length()>.65:
   count+=1
   if count>360:pulse(false);print("STUCK ",actor.position," -> ",waypoint);return false
   var offset=waypoint-actor.position;actor.rotation.y=atan2(-offset.x,-offset.z);actor.eye.rotation.x=0
   pulse(true);game.input_window_focused=true;await physics_frame
 pulse(false);await physics_frame
 return actor.global_position.distance_to(target)<1.5
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 c=game.campaign;c.save_store.path="user://chapter-routes.json";c.begin_solo(false)
 var requested=int(OS.get_environment("NEST_ROUTE_MISSION"))
 for mission in range(3,10):
  if requested>0 and requested!=mission:continue
  c.journey.start_standalone(mission);c.state.phase="RADIO_READY";c.journey._remove_enemies()
  game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  await physics_frame;await physics_frame
  for stage in range(4):
   c.state.chapter_stage=stage;c.world.set_stage(stage);await physics_frame;await physics_frame
   var target=c.world.locations["objective"+str(stage)]+Vector3(0,0,2.2)
   check(await walk(target),"Chapter %d stage %d actual player reaches objective through route"%[mission,stage])
   var points=c.world.encounter_spawns(stage);var valid=points.size()>=int(c.journey.chapter(mission).stages[stage].enemies)
   for point in points:
    if c.world.blocked_point(point):valid=false
   check(valid,"Chapter %d stage %d has enough unobstructed Annu positions"%[mission,stage])
   if stage in [1,2]:
    var index=stage-1
    check(await walk(c.world.locations["evidence"+str(index)]+Vector3(0,0,2.2)),"Chapter %d optional record %d physically reachable"%[mission,index])
  check(await walk(c.world.locations.supply3+Vector3(0,0,2.2)),"Chapter %d final supply rack physically reachable"%mission)
 c.exit_campaign();game.queue_free();await process_frame
 print("CHAPTER ROUTES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
