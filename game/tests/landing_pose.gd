extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.start_game();game.set_physics_process(false);game.context="pause";var p=game.player;p.set_physics_process(false);p.set_process(false)
 var sk=p.skeleton;var pelvis=sk.find_bone("pelvis")
 for age in [0.0,.10,.20,.34]:
  p.animation.play(p.clips.idle);p.animation.advance(0);p.presentation.first_foot_left=true;p.presentation.landing_age=age
  var root_position=p.global_position;var camera_basis=p.camera.global_basis
  p.presentation.pose_upper_body()
  for side in ["l","r"]:
   var thigh=sk.get_bone_global_pose(sk.find_bone("thigh_"+side)).origin
   var calf=sk.get_bone_global_pose(sk.find_bone("calf_"+side)).origin
   var foot=sk.get_bone_global_pose(sk.find_bone("foot_"+side)).origin
   check(foot.y<calf.y and calf.y<thigh.y,"Landing keeps "+side+" leg below the body at "+str(age)+" s")
  check(root_position==p.global_position and camera_basis==p.camera.global_basis,"Landing pose has no camera or collision-root movement at "+str(age)+" s")
 p.presentation.landing_age=.1;p.presentation.airborne_seconds=0;p.presentation.landing_life=p.life_id
 # A remote snapshot is enough to exercise the pure cosmetic grounded state.
 p.presentation.landing_age=INF
 check(p.presentation.landing_foot_lift(true)==0 and p.presentation.landing_foot_lift(false)==0,"Cancelled landing has no residual foot layer")
 print("LANDING POSE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
