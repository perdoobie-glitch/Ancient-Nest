extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="playing"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var cannons=game.arena.get_children().filter(func(n):return n is NestManCannon)
 for cannon in cannons:
  if not OS.get_cmdline_user_args().is_empty() and not String(cannon.name).begins_with(OS.get_cmdline_user_args()[0]):continue
  p.respawn();p.global_position=cannon.global_position+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.cannon_takeoff=false;p.reset_physics_interpolation()
  await physics_frame
  cannon.recent.clear();cannon.launch(p)
  check(Engine.is_in_physics_frame(),"Launcher simulation runs on a real fixed physics tick")
  check(p.controlled.y>10,"Launcher takeoff: "+String(cannon.name))
  for i in range(320):
   game.now+=1.0/60;p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
   if "trace" in OS.get_cmdline_user_args() and i%30==0:print("STEP ",i," pos ",p.global_position," vel ",p.velocity)
  var target=game.arena.to_global(cannon.destination)
  print("LANDING ",cannon.name," actual ",p.global_position," target ",target)
  var landing_ok=Vector2(p.global_position.x-target.x,p.global_position.z-target.z).length()<3.0
  if String(cannon.name).begins_with("C2"):
   var point=game.arena.to_local(p.global_position)
   landing_ok=Rect2(-4,4,14,10).has_point(Vector2(point.x,point.z))
  check(p.alive and p.is_on_floor() and absf(p.global_position.y-target.y)<.25 and landing_ok,"Actual capsule lands on intended deck: "+String(cannon.name))
 game.stop_game();game.queue_free()
 for i in range(8):await process_frame
 print("MAP LAUNCHERS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
