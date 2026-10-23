extends SceneTree
var game
var checks=0
var failures=0
var samples=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var floor=StaticBody3D.new();var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=Vector3(100,1,50);c.shape=s;floor.add_child(c);game.add_child(floor);floor.position=Vector3(200,99.5,200)
 for mode in ["standing","hold_crouch","release_crouch","slope_land"]:
  floor.rotation.z=deg_to_rad(25) if mode=="slope_land" else 0.0;await physics_frame
  p.respawn();p.set_physics_process(false);p.global_position=Vector3(200,100.3,200);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
  for i in range(40):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);p.update_visual(1.0/60);await physics_frame
  var base_sequence=p.presentation.landing_sequence;var base_cues=p.combat_audio.landing_foot_cues
  var first_landing=-1;var rises=0;var floor_losses=0;var was_floor=false;var max_ground_vy=0.0;var ys=[]
  for frame in range(240):
   var duck=mode in ["hold_crouch","release_crouch"] and frame>=8 and (mode=="hold_crouch" or frame<90)
   p.movement_step(Vector2(0,-1) if mode=="slope_land" else Vector2.ZERO,frame==0,1 if duck else 0,-PI*.5,1.0/60);await physics_frame
   p.update_visual(1.0/60)
   if frame>12 and p.is_on_floor() and first_landing<0:
    first_landing=frame
    check(p.presentation.landing_foot_lift(p.presentation.first_foot_left)==0 and p.presentation.landing_foot_lift(not p.presentation.first_foot_left)>.99,mode+" plants the leading foot before trailing foot")
   if first_landing>=0:
    if was_floor and not p.is_on_floor():floor_losses+=1
    if p.is_on_floor():max_ground_vy=maxf(max_ground_vy,p.controlled.y)
   if frame>180:ys.append(p.global_position.y)
   was_floor=p.is_on_floor()
  check(first_landing>0 and floor_losses==0,mode+" lands once and remains grounded")
  check(p.presentation.landing_sequence-base_sequence==1,mode+" plays a single landing sequence")
  check(p.combat_audio.landing_foot_cues-base_cues==2,mode+" emits exactly two quiet foot contacts")
  if mode!="slope_land":check(ys.max()-ys.min()<.001,mode+" has no settled vertical bounce")
  samples.append({"case":mode,"first_landing_tick":first_landing,"floor_losses_after_landing":floor_losses,"max_upward_ground_velocity":max_ground_vy,"landing_sequences":p.presentation.landing_sequence-base_sequence,"foot_contacts":p.combat_audio.landing_foot_cues-base_cues})
 # Re-jump uses the original movement rules; the camera fix introduces
 # no new grounded cooldown or physical landing lock.
 for i in range(5):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
 check(p.movement_step(Vector2.ZERO,true,0,0,1.0/60) and p.controlled.y>6,"Deliberate jump still takes off immediately")
 # Presentation methods cannot move the root/camera or alter collision momentum.
 var position=p.global_position;var aim=p.camera.global_transform;var velocity=p.controlled;var external=p.external
 p.presentation.landing_age=0;p.presentation.pose_upper_body()
 check(p.global_position==position and p.camera.global_transform==aim and p.controlled==velocity and p.external==external,"Staggered feet do not move the collision root, camera or momentum")
 p.presentation.landing_age=.20
 check(p.presentation.landing_foot_lift(true)==0 and p.presentation.landing_foot_lift(false)==0,"Both feet are planted by 200 ms")
 check(is_equal_approx(p.tuning.jump_speed,6.4552829507) and is_equal_approx(p.tuning.gravity,8.14065237),"Jump and gravity balance unchanged")
 var output=OS.get_environment("NEST_LANDING_TEST_OUTPUT");if output.is_empty():output="user://landing-results.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(samples,"  "));file.close()
 print("LANDING STABILITY: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
