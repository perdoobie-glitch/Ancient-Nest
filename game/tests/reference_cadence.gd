extends SceneTree
var game
var shots=[]
var failures=0
var rows=[]
func _initialize():call_deferred("run")
func frames(n=2):
 for i in range(n):await process_frame
func click(value: bool):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value;Input.parse_input_event(event)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();var p: NestActor=game.player
 p.shot_fired.connect(func(_id,time,_origin,_directions):shots.append({"time":time,"frame":Engine.get_process_frames()}))
 for fps in [30,60,120,144]:
  Engine.max_fps=fps
  for kind in ["smg","plasma_smg","plasma_sniper"]:
   p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.ammo.assign([p.weapons[0].magazine]);p.reserve.assign([p.weapons[0].reserve]);p.slot=0;p.action_state="ready";p.cooldown=game.now;p.burst_left=0;p.clear_local_input();p.suppressed_actions.clear();p.position=Vector3(600,80,600);p.controlled=Vector3.ZERO
   await frames(3);shots=[];var start=game.now;var wall=Time.get_ticks_usec();var frame_start=Engine.get_process_frames();var ammo=p.ammo[0];click(true)
   while game.now-start<1.19:await process_frame
   click(false);var span=game.now-start;var elapsed=(Time.get_ticks_usec()-wall)/1000000.0
   var counts={}
   for shot in shots:counts[shot.frame]=int(counts.get(shot.frame,0))+1
   var expected=1+floori((span-.0001)/p.weapons[0].interval) if p.weapons[0].automatic else 1
   var pass_case=absi(shots.size()-expected)<=1 and ammo-p.ammo[0]==shots.size() and counts.values().all(func(n):return n==1)
   if not pass_case:failures+=1
   var row={"kind":kind,"requested_render_cap":fps,"observed_process_fps":(Engine.get_process_frames()-frame_start)/elapsed,"simulation_seconds":span,"shots":shots.size(),"expected_with_tick_tolerance":expected,"ammo_used":ammo-p.ammo[0],"pass":pass_case};rows.append(row);print("CADENCE ",JSON.stringify(row))
 game.stop_game();game.queue_free();await frames(5)
 FileAccess.open("user://reference-cadence.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("REFERENCE CADENCE: 12 cases, ",failures," failures");quit(1 if failures else 0)
