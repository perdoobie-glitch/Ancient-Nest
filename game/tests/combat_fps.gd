extends SceneTree
var game
var shots=[]
var failures=0
var results=[]
func _initialize():call_deferred("run")
func frames(n=2):
 for i in range(n):await process_frame
func click(pressed):
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.selected_faction=0;game.start_game()
 var p=game.player;p.shot_fired.connect(func(id,t,_origin,_directions):shots.append({"time":t,"frame":Engine.get_process_frames()}))
 var cases=[]
 for fps in [30,60,120,144]:
  for kind in ["rifle","ak47","burst","burst_scoped","sidearm","sniper","shotgun","rocket"]:cases.append({"fps":fps,"kind":kind})
 for spec in cases:
  var fps=spec.fps
  game.starting_primary={"rifle":"assault_rifle","ak47":"ak47","burst":"battle_rifle","burst_scoped":"battle_rifle_scoped","sidearm":"magnum","sniper":"sniper_rifle","shotgun":"shotgun","rocket":"rocket_launcher"}[spec.kind];game.starting_secondary="none"
  Engine.max_fps=fps
  game.sync_legacy_to_game_type();p.reset_loadout();p.clear_local_input();p.suppressed_actions.clear();p.eye.rotation.x=.45;p.rotation.y=0;p.apply_aim_rotation();await frames(3)
  var start=game.now;var ammo=p.ammo[0];shots=[];var renders=Engine.get_process_frames();var wall=Time.get_ticks_usec();click(true)
  while game.now-start<1.999:await process_frame
  click(false);var elapsed=(Time.get_ticks_usec()-wall)/1000000.0
  var count=shots.size();var by_frame={};var minimum=INF
  for i in range(count):
   by_frame[shots[i].frame]=int(by_frame.get(shots[i].frame,0))+1
   if i>0:minimum=minf(minimum,shots[i].time-shots[i-1].time)
  var ok=(count>=20 and count<=21 if spec.kind in ["rifle","ak47"] else count==9 if spec.kind in ["burst","burst_scoped"] else count==1) and ammo-p.ammo[0]==count and by_frame.values().all(func(n):return n==1) and minimum>=(.0833 if spec.kind in ["rifle","ak47"] else .04999)
  if not ok:failures+=1
  results.append({"weapon":spec.kind,"requested_fps":fps,"observed_process_fps":(Engine.get_process_frames()-renders)/elapsed,"simulation_seconds":game.now-start,"shots":count,"ammo_used":ammo-p.ammo[0],"minimum_simulation_interval":minimum if count>1 else null,"pass":ok})
  print("FPS CASE ",JSON.stringify(results[-1]))
 # Block the actual main loop to force a catch-up frame while holding fire.
 game.sync_legacy_to_game_type();p.reset_loadout();p.clear_local_input();p.suppressed_actions.clear();await frames(2);shots=[];click(true);OS.delay_msec(300);await frames(3);click(false)
 var by_frame={}
 for shot in shots:by_frame[shot.frame]=int(by_frame.get(shot.frame,0))+1
 var hitch_ok=by_frame.values().all(func(n):return n==1) and (p.burst_left==0 or p.burst_next>game.now)
 if not hitch_ok:failures+=1
 print("HITCH CASE: maximum one shot per render epoch = ",hitch_ok)
 FileAccess.open(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://combat-fps-results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 game.stop_game();game.queue_free();await frames(6);print("COMBAT FPS: 33 cases, %d failures"%failures);quit(1 if failures else 0)
