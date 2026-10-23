extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game()
 game.set_physics_process(false)
 var original=game.player
 game.actors.erase(original);original.queue_free();await frames()
 var p=load("res://tests/smooth_actor_probe.gd").new()
 p.game=game;p.local_player=true;p.faction=0;game.add_child(p);game.player=p;game.actors.append(p)
 p.set_physics_process(false);p.set_process(false);game.capture_mouse()
 game.prefs.values.sensitivity=2.0;game.prefs.values.hover_sensitivity_multiplier=.7125
 var motion=InputEventMouseMotion.new();motion.screen_relative=Vector2(.01,0);motion.relative=Vector2(800,0)
 p.rotation.y=1.5;p.eye.rotation.x=0;p.hover_look_gain=1.0
 var before=p.rotation.y
 for i in range(1000):p._input(motion)
 check(absf(angle_difference(before,p.rotation.y)+deg_to_rad(.44))<.00008,"Sub-count mouse deltas accumulate without a grid, pixel rounding or delta scaling")
 check(p.hover_queries==0,"1000 mouse events perform zero hover collision queries")
 check((-p.camera.global_basis.z).dot(-p.eye.global_basis.z)>.999999,"Visible aim matches current input without waiting for physics")
 p.forced_hover=.7125
 for fps in [30,60,120,144]:
  p.hover_queries=0;p.hover_look_gain=1
  var elapsed=0.0;var last=1.0;var continuous=true
  while elapsed<.06-.000001:
   var dt=minf(1.0/fps,.06-elapsed);p.update_hover_look(dt);elapsed+=dt
   continuous=continuous and p.hover_look_gain<=last and p.hover_look_gain>=.7125
   last=p.hover_look_gain
  check(continuous and absf(p.hover_look_gain-.7125)<.000001,"Hover slowdown reaches the chosen strength smoothly at %d FPS"%fps)
  check(p.hover_queries==int(ceil(.06*fps)),"Hover query count is bounded by rendered updates at %d FPS"%fps)
 p.forced_hover=1;p.update_hover_look(.03)
 check(p.hover_look_gain>.7125 and p.hover_look_gain<1,"Leaving a target avoids a single-event sensitivity jump")
 p.update_hover_look(.03);check(is_equal_approx(p.hover_look_gain,1.0),"Normal sensitivity returns after 60 ms")
 p.hover_look_gain=.8;before=p.rotation.y;p._input(motion)
 check(absf(angle_difference(before,p.rotation.y)+deg_to_rad(.00044)*.8)<.000001,"Hover gain scales displacement immediately without filtering rotation")
 p.clear_local_input();check(p.hover_look_gain==1.0,"Pause/focus input reset clears the old hover gain")
 p.hover_look_gain=1;p.rotation.y=0;p.eye.rotation.x=0
 game.prefs.values.invert_y=true;motion.screen_relative=Vector2(0,10);p._input(motion)
 check(p.eye.rotation.x>0,"Inversion remains reliable")
 motion.screen_relative=Vector2(0,1e6);p._input(motion)
 check(p.eye.rotation.x<=deg_to_rad(89)+.000001,"Pitch remains clamped")
 p.velocity=Vector3(3,0,0);p.presentation.view_speed=3
 var phase=p.presentation.gait_phase;var origin=p.camera.global_transform
 var pos=p.weapon_view.position
 p.presentation.update_view(1.0/144)
 check(p.weapon_view.position.distance_to(pos)>.000001 and p.presentation.gait_phase==phase,"Weapon bob advances between physics ticks at 144 FPS")
 check(p.camera.global_transform.is_equal_approx(origin),"Weapon bob never changes camera orientation or position")
 for fps in [30,60,120,144]:
  p.presentation.view_speed=3;p.presentation.view_gait_phase=0
  for i in range(fps):p.presentation.update_view(1.0/fps)
  check(absf(p.presentation.view_gait_phase-6.0)<.0001,"One second of view bob is consistent at %d FPS"%fps)
 check(Engine.physics_ticks_per_second==60 and ProjectSettings.get_setting("physics/common/physics_interpolation"),"Collision remains at fixed 60 Hz with interpolated positional rendering")
 p.global_position=Vector3(80,25,80);p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.aim_punch=Vector2.ZERO
 p.camera.global_position=p.eye.global_position;p.apply_aim_rotation();game.mode=2
 var target=NestActor.new();target.game=game;target.faction=1;game.add_child(target);game.actors.append(target);target.set_physics_process(false)
 target.global_position=Vector3(80,25,70);target.update_visual(.016);await frames()
 var offset=target.hitboxes[1].global_position-p.camera.global_position
 p.rotation.y=atan2(-offset.x,-offset.z);p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.apply_aim_rotation()
 check(is_equal_approx(p.query_actual(),.7125),"Real enemy body hitboxes request the configured slowdown")
 target.faction=0;check(p.query_actual()==1.0,"Friendly hitboxes do not request slowdown")
 target.faction=1
 var wall=Node3D.new();game.add_child(wall);game.arena.kit.box(wall,Vector3(80,26,75),Vector3(4,4,.2),game.arena.kit.stone,true);await frames()
 check(p.query_actual()==1.0,"World cover blocks the actual hover query")
 wall.queue_free();await frames()
 p.rotation.y=PI/2;p.apply_aim_rotation();check(p.query_actual()==1.0,"Looking away requests normal sensitivity")
 print("CONTROL SMOOTHNESS: %d checks, %d failures"%[checks,failures])
 game.stop_game();game.queue_free();await frames(8);quit(1 if failures else 0)
