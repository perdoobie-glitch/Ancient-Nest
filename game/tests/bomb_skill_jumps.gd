extends SceneTree
var game
var checks=0
var failures=0
var results=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func jump_step(start: Vector3,finish: Vector3,title: String,duck: bool) -> void:
 var p=game.player;p.respawn();p.set_physics_process(false);p.set_process(false)
 p.global_position=start*.85+Vector3.UP*.04;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
 for i in range(15):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
 var takeoff=p.global_position
 check(p.is_on_floor() and absf(takeoff.y-start.y*.85)<.12,title+" starts on collision support")
 var target=finish*.85;var delta=target-takeoff;var horizontal=Vector3(delta.x,0,delta.z)
 var dy=delta.y-(p.TUCK if duck else 0.0)
 var discriminant=p.tuning.jump_speed*p.tuning.jump_speed-2*p.tuning.gravity*dy
 check(discriminant>0,title+" within current ballistic reach")
 if discriminant<=0:return
 var flight=(p.tuning.jump_speed+sqrt(discriminant))/p.tuning.gravity
 # Account for a low overhead slab: a crouch jump raises the feet, while
 # the head still collides with that slab and shortens the ballistic arc.
 var ceiling=game.trace(takeoff+Vector3.UP*(p.STAND_HEIGHT+.02),takeoff+Vector3.UP*(p.STAND_HEIGHT+3.0),1)
 if not ceiling.is_empty():
  var max_rise=ceiling.position.y-p.STAND_HEIGHT-takeoff.y-.03
  var free_apex=p.tuning.jump_speed*p.tuning.jump_speed/(2*p.tuning.gravity)
  if max_rise>0 and max_rise<free_apex:
   var up_time=(p.tuning.jump_speed-sqrt(p.tuning.jump_speed*p.tuning.jump_speed-2*p.tuning.gravity*max_rise))/p.tuning.gravity
   var drop=takeoff.y+max_rise+(p.TUCK if duck else 0.0)-target.y
   if drop>0:flight=minf(flight,up_time+sqrt(2*drop/p.tuning.gravity))
 var aim=horizontal.normalized();var yaw=atan2(-aim.x,-aim.z)
 var desired=horizontal.length()/flight
 # Build momentum with movement input on the takeoff surface. Never assign
 # horizontal velocity or position during a flight to make the jump pass.
 var runup=clampi(ceili(desired/(p.tuning.ground_acceleration/60.0))-1,0,7)
 for frame in range(runup):p.movement_step(Vector2(0,-1),false,0,yaw,1.0/60);await physics_frame
 check(p.movement_step(Vector2(0,-1),true,0,yaw,1.0/60),title+" takes off with a normal jump press")
 await physics_frame
 var landed=false
 for frame in range(150):
  var time_left=maxf(.10,flight-(frame+1)/60.0)
  var left=target-p.global_position;left.y=0
  var velocity=Vector3(p.controlled.x,0,p.controlled.z)
  var error=left/time_left-velocity
  var input=Vector2.ZERO
  if error.length()>.12:
   yaw=atan2(-error.x,-error.z);input=Vector2(0,-1)
  p.movement_step(input,false,1 if duck and frame>=1 else 0,yaw,1.0/60);await physics_frame
  if frame>4 and p.is_on_floor() and absf(p.global_position.y-target.y)<.35:
   landed=true
   if Vector2(target.x-p.global_position.x,target.z-p.global_position.z).length()<.24:break
 # Stop and settle after the feet contact the landing; airborne tuck can
 # raise the origin on that same tick, before the following grounded step.
 for i in range(20):p.movement_step(Vector2.ZERO,false,1 if duck else 0,yaw,1.0/60);await physics_frame
 var distance=Vector2(p.global_position.x-target.x,p.global_position.z-target.z).length()
 print("JUMP ",title," landed=",p.global_position," target=",target," distance=",distance)
 var ok=landed and p.alive and absf(p.global_position.y-target.y)<.15 and distance<.65
 check(ok,title+" lands on intended surface using movement input")
 # Release crouch and verify the standing collision shape is allowed to return.
 if ok:
  for i in range(10):p.movement_step(Vector2.ZERO,false,0,yaw,1.0/60);await physics_frame
  check(not p.crouched and p.is_on_floor(),title+" can stand after landing")
 results.append({"route":title,"crouch_in_air":duck,"success":ok,"landing":str(p.global_position),"target":str(target),"error_m":distance})
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var stages=[
  [Vector3(5.8,7,3),Vector3(5.8,8.2,.5),"A ground to first ledge",false],
  [Vector3(5.8,8.2,.5),Vector3(8.9,9.65,.5),"A narrow lateral ledge crouch jump",true],
  [Vector3(8.9,9.65,.5),Vector3(8.9,10.8,-2.9),"A ledge to passage roof",true],
  [Vector3(27.2,0,5.2),Vector3(26,1.2,3),"B ground to existing cover",false],
  [Vector3(26,1.2,3),Vector3(25.5,2.7,-.5),"B cover to narrow pedestal",false],
  [Vector3(25.5,2.7,-.5),Vector3(24.8,4,-3.8),"B pedestal to service roof",true],
  [Vector3(24.8,4,-3.8),Vector3(25.1,4,-5.6),"B roof to outer corner",false],
  [Vector3(25.1,4,-5.6),Vector3(22.2,7,-2.2),"B outer corner to middle crouch jump",true]]
 for stage in stages:await jump_step(stage[0],stage[1],stage[2],stage[3])
 check(is_equal_approx(game.player.tuning.gravity,8.14065237) and is_equal_approx(game.player.tuning.ground_speed,6.6) and is_equal_approx(game.player.tuning.jump_speed,6.4552829507),"Movement balance unchanged")
 var output=OS.get_environment("NEST_SKILL_TEST_OUTPUT")
 if output.is_empty():output="user://skill-jump-results.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
 print("BOMB SKILL JUMPS: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
