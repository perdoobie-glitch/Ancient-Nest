extends SceneTree
# Reproducible simulated local-player + bot workload, not real network clients.
var game
var samples=[]
var process_ms=[]
var physics_ms=[]
var trace_us=[]
var weapons=["rifle","burst","burst_scoped","sidearm","shotgun","sniper","ak47","rocket"]
var event=0
func _initialize():call_deferred("run")
func q(values: Array,fraction: float):
 if values.is_empty():return 0.
 var sorted=values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,int((sorted.size()-1)*fraction))]
func run():
 var args=OS.get_cmdline_user_args();var count=int(args[0]) if args.size()>0 else 10;var out=args[1] if args.size()>1 else "user://route-benchmark.json";var duration=float(args[2]) if args.size()>2 else 12.;var cap=int(args[3]) if args.size()>3 else 0
 root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=cap
 seed(9173)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null
 game.bot_fill=true;game.team_size=ceili(count/2.);game.mode=2;game.tuning.score_limit=1000;game.start_game();game.clear_screen();game.create_hud();game.hud.visible=true;game.context="playing";game.capture_mouse()
 var p=game.player;p.health=1000000
 game.arena.sun.shadow_enabled=args[4]!="0" if args.size()>4 else true
 var vsync=int(args[5]) if args.size()>5 else 0
 DisplayServer.window_set_vsync_mode(vsync);Engine.max_fps=cap
 # Fixed supported route, changing floors by fixture teleport to exercise visibility/cost.
 var route=[Vector3(-13,.1,-14),Vector3(8,.1,-15),Vector3(12,6.05,0),Vector3(-5,6.05,3),Vector3(10,12,6),Vector3(25,12,8)]
 for i in range(30):await process_frame
 var started=Time.get_ticks_usec();var previous=started;var next_action=0.;var next_waypoint=0.;var actions=0;var waypoints=0;var first_hitches=[];var max_effects=0;var max_corpses=0;var scripted_deaths=0;var death_load=args.size()>6 and args[6]=="1"
 while Time.get_ticks_usec()-started<int(duration*1e6):
  await process_frame
  var tick=Time.get_ticks_usec();var elapsed=(tick-started)/1e6;var frame=(tick-previous)/1000.;previous=tick
  samples.append(frame);process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.);physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
  if frame>33.333:first_hitches.append({"elapsed":elapsed,"frame_ms":frame,"action":actions})
  if elapsed>=next_waypoint:
   p.position=route[waypoints%route.size()];p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.reset_physics_interpolation();waypoints+=1;next_waypoint=(floor(elapsed/1.4)+1)*1.4
  var motion=InputEventMouseMotion.new();motion.screen_relative=Vector2(130*cos(elapsed*3),20*sin(elapsed*2));motion.relative=motion.screen_relative;Input.parse_input_event(motion)
  Input.action_press("forward");Input.action_press("right",.5)
  if elapsed>=next_action:
   var w=NestWeaponCatalog.profile(weapons[actions%weapons.size()]);p.weapons.assign([w]);p.slot=0;p.ammo.assign([1000]);p.reserve.assign([1000]);p.action_state="ready";p.burst_left=0;p.cooldown=0;p.fire_trigger()
   # Guaranteed visible impacts and explosions alongside normal weapon/bot firing.
   if actions%4==0:game.impact(p.position+p.aim_direction()*4+Vector3.UP,Vector3.UP,true)
   else:game.impact(p.position+p.aim_direction()*3+Vector3.UP,Vector3.UP)
   if death_load and actions%12==0:
    for actor in game.actors:
     if actor!=p and actor.alive:
      actor.take_damage(10000,"torso","heavy",false,p,game.next_event(),p.eye.global_position,"rocket",0,actor.global_position+Vector3.UP);scripted_deaths+=1;break
   actions+=1;next_action=(floor(elapsed/.20)+1)*.20
  max_effects=maxi(max_effects,game.effects.get_child_count());max_corpses=maxi(max_corpses,game.corpses.get_child_count())
 Input.action_release("forward");Input.action_release("right")
 var r={"engine":Engine.get_version_info().string,"build":"editor runtime" if OS.has_feature("editor") else "standalone","renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"resolution":[960,600],"shadows":game.arena.sun.shadow_enabled,"vsync_requested":vsync,"vsync_observed":DisplayServer.window_get_vsync_mode(),"fps_cap":cap,"physics_hz":Engine.physics_ticks_per_second,"actors":game.actors.size(),"participants":"one scripted local player plus simulated bots; zero separate clients","duration_seconds":(Time.get_ticks_usec()-started)/1e6,"frames":samples.size(),"frame_median_ms":q(samples,.5),"frame_p95_ms":q(samples,.95),"frame_p99_ms":q(samples,.99),"worst_ms":samples.max(),"observed_fps":samples.size()/((Time.get_ticks_usec()-started)/1e6),"process_median_ms":q(process_ms,.5),"process_p95_ms":q(process_ms,.95),"physics_median_ms":q(physics_ms,.5),"physics_p95_ms":q(physics_ms,.95),"gpu_time_ms":null,"gpu_time_note":"Not available from this Compatibility/software GL harness","actions":actions,"route_points":waypoints,"max_effect_nodes":max_effects,"max_corpses":max_corpses,"scripted_fixture_deaths":scripted_deaths,"draw_calls_last":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"hitches_over_33ms":first_hitches,"raw_frame_ms":samples}
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(r,"  "));r.erase("raw_frame_ms");r.erase("hitches_over_33ms");print("ROUTE BENCHMARK ",JSON.stringify(r));game.stop_game();game.queue_free();await process_frame;quit()
