extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.selected_faction=1 if "annu" in OS.get_cmdline_user_args() else 0;game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var floor_root=Node3D.new();game.add_child(floor_root)
 game.arena.kit.box(floor_root,Vector3(80,20,80),Vector3(20,1,20),game.arena.kit.stone,true)
 p.global_position=Vector3(80,21,80)
 for i in range(80):
  await physics_frame
  p.velocity=Vector3(0,-3,0);p.move_and_slide()
 check(p.is_on_floor(),"Animation fixture has grounded character")
 p.velocity=Vector3.ZERO
 var pres=p.presentation;var sk=p.skeleton
 pres.landing_age=INF;pres.airborne_seconds=0;pres.landing_life=p.life_id
 for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(1,0,-1).normalized()]:
  p.velocity=direction*game.tuning.ground_speed
  var origin=p.global_transform;var camera=p.camera.global_transform
  var velocity=p.velocity;var shape=p.capsule
  var shape_transform=shape.transform if shape!=null else Transform3D.IDENTITY
  for i in range(45):
   pres.update_locomotion(1.0/60)
   p.animation.play(p.clips.idle);p.animation.advance(0)
   pres.pose_upper_body()
  check(p.global_transform==origin and p.velocity==velocity and p.camera.global_transform==camera,"Model pose leaves physics and aim unchanged: "+str(direction))
  if shape!=null:check(shape.transform==shape_transform,"Collision capsule remains unchanged")
  for side in ["l","r"]:
   var hip=sk.get_bone_global_pose(sk.find_bone("thigh_"+side)).origin
   var knee=sk.get_bone_global_pose(sk.find_bone("calf_"+side)).origin
   var foot=sk.get_bone_global_pose(sk.find_bone("foot_"+side)).origin
   check(foot.is_finite() and foot.y<knee.y and knee.y<hip.y,"Anatomical leg ordering for "+side+" "+str(direction))
 var phase=pres.gait_phase
 p.velocity=Vector3.ZERO
 pres.update_locomotion(1.0/60)
 check(pres.locomotion_weight>0,"Stopping blends the model instead of snapping")
 for i in range(90):pres.update_locomotion(1.0/60)
 check(pres.locomotion_weight<.001,"Stopped model settles into idle")
 p.velocity=Vector3(1,0,-1)*game.tuning.ground_speed
 pres.update_locomotion(1.0/60);phase=pres.gait_phase
 p.velocity=Vector3(-1,0,-1)*game.tuning.ground_speed
 pres.update_locomotion(1.0/60)
 check(pres.gait_phase!=0 and absf(angle_difference(phase,pres.gait_phase))<.5,"Direction changes preserve continuous stride phase")
 p.life_id+=1;pres.update_locomotion(1.0/60)
 check(pres.locomotion_weight==0 and pres.gait_phase==0,"Respawn clears old movement pose")
 print("MODEL LOCOMOTION: %d checks, %d failures"%[checks,failures])
 game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
