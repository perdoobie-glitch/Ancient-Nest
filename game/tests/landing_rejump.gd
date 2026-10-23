extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func key(code: Key,pressed: bool):
 var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="playing"
 var p=game.player;p.set_physics_process(false)
 var floor=StaticBody3D.new();var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=Vector3(60,1,40);c.shape=s;floor.add_child(c);game.add_child(floor);floor.position=Vector3(200,99.5,200)
 for mode in ["standing","hold_crouch","slope"]:
  floor.rotation.z=deg_to_rad(20) if mode=="slope" else 0.0;await physics_frame
  p.respawn();p.set_physics_process(false);p.global_position=Vector3(200,100.3,200);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.reset_physics_interpolation();p.set_physics_process(true)
  for i in range(40):await physics_frame
  key(KEY_SPACE,true);key(KEY_SPACE,false)
  var airborne=false
  for i in range(15):
   await physics_frame
   airborne=airborne or not p.is_on_floor()
  check(airborne,mode+" first short jump press is consumed")
  if mode=="hold_crouch":key(KEY_CTRL,true)
  var landed=false
  for i in range(150):
   await physics_frame
   if p.is_on_floor():landed=true;break
  check(landed,mode+" obtains floor contact at touchdown")
  # Send a fresh released press at the first observed landed tick, without
  # waiting for any cosmetic pose, crouch transition or cooldown.
  var y=p.global_position.y
  key(KEY_SPACE,true);key(KEY_SPACE,false)
  var rose=false
  for i in range(15):
   await physics_frame
   if not p.is_on_floor() and p.global_position.y>y+.2:rose=true
  check(rose,mode+" re-jumps immediately after touchdown")
  if mode=="hold_crouch":key(KEY_CTRL,false)
  p.set_physics_process(false)
 check(p.camera.top_level and p.camera.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Camera rotation remains outside inherited physics interpolation")
 check(p.view_position_anchor.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_ON,"Complete eye position has its own interpolated anchor")
 print("LANDING REJUMP: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
