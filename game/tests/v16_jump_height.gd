extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func jump(p, speed: float) -> float:
 p.respawn();p.set_physics_process(false);p.set_process(false);p.tuning.jump_speed=speed
 p.global_position=Vector3(600,100.07,600);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
 for i in range(30):
  p.velocity=Vector3.DOWN;p.move_and_slide();await physics_frame
 var floor_y=p.global_position.y;var apex=floor_y
 check(p.movement_step(Vector2.ZERO,true,0,0,1.0/60),"Grounded press initiates a simulated jump")
 apex=maxf(apex,p.global_position.y);await physics_frame
 for i in range(180):
  p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame;apex=maxf(apex,p.global_position.y)
  if p.is_on_floor():break
 check(p.is_on_floor(),"Jump returns to collision floor without repeated takeoff")
 return apex-floor_y
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 # Isolate ballistic height from the normal 3 cm floor-separation recovery.
 p.safe_margin=.0001
 var floor=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);shape.shape=box;floor.add_child(shape);game.add_child(floor);floor.position=Vector3(600,99.5,600);await physics_frame
 var new_speed=NestTuning.new().jump_speed
 var old_apex=await jump(p,6.0150376)
 var new_apex=await jump(p,new_speed)
 print("APEX old=",old_apex," new=",new_apex," ratio=",new_apex/old_apex)
 check(absf(new_apex/old_apex-1.15)<.005,"Measured jump apex increases 15 percent within half a percentage point at 60 Hz")
 check(is_equal_approx(p.tuning.gravity,8.14065237) and is_equal_approx(p.tuning.ground_speed,6.6),"Gravity and ground movement retain their existing values")
 game.game_type.jump_height_percent=50;p.refresh_traits()
 var half=await jump(p,new_speed)
 check(absf(half/new_apex-.5)<.02,"Custom jump-height traits still scale the higher baseline")
 print("V16 JUMP HEIGHT: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
