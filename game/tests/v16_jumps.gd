extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func tick():await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var steps=[Vector3(-22,14,-24),Vector3(-20,15.7,-21.9),Vector3(-18,17.3,-21.9),Vector3(-15.5,18.9,-21.9),Vector3(-13,20.5,-21.9),Vector3(-10,22.1,-21.9),Vector3(-7,22.8,-20)]
 for index in range(steps.size()-1):
  var start=steps[index]*.85;var finish=steps[index+1]*.85
  p.respawn();p.set_physics_process(false);p.global_position=start+Vector3.UP*.07;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
  for i in range(20):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await tick()
  var jump=p.tuning.jump_speed;var g=p.tuning.gravity;var dy=finish.y-p.global_position.y;var discriminant=jump*jump-2*g*dy
  check(discriminant>0,"Default jump has enough height for rafter step "+str(index+1))
  if discriminant<=0:continue
  var flight=(jump+sqrt(discriminant))/g;var direction=finish-p.global_position;direction.y=0;var speed=direction/flight
  p.movement_step(Vector2.ZERO,true,0,0,1.0/60);p.controlled.x=speed.x;p.controlled.z=speed.z
  for i in range(ceili(flight*60)+20):
   p.movement_step(Vector2.ZERO,false,1 if i>=8 else 0,0,1.0/60);await tick()
   if i>10 and p.is_on_floor():break
  print("STEP ",index+1," landed ",p.global_position," target ",finish)
  check(p.is_on_floor() and absf(p.global_position.y-finish.y)<.15,"Real collision accepts crouch-assisted rafter jump "+str(index+1))
 print("V16 JUMPS: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
