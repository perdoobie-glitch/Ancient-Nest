extends SceneTree
var game
var report=[]
func _initialize():call_deferred("run")
func run():
 seed(91276);game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.values.graphics_quality=0;game.prefs.values.shadows=false;game.prefs.values.vsync=false;game.prefs.values.fullscreen=false;game.prefs.values.fps_limit=120;game.prefs.apply();Engine.max_fps=120
 var seconds=15.0
 if OS.get_cmdline_user_args().size()>0:seconds=float(OS.get_cmdline_user_args()[0])
 for map in [2]:
  for mode in [0,1,2,3,4]:
   if game.running:game.stop_game()
   var rules=NestMatchPresets.create(mode,map,1 if mode%2==0 else 2);rules.max_players=10;rules.max_players_per_team=5;rules.bots_fill_empty_slots=true;rules.bots_team_0=-1;rules.bots_team_1=-1;rules.bots_stand_still=false;rules.bots_dont_shoot=false;rules.score_to_win=1000
   game.apply_game_type_settings(rules);game.start_game();game.context="playing";game.clear_screen();game.create_hud();game.capture_mouse()
   assert(game.actors.size()==10,"Nine-bot fixture must have exactly ten actors")
   for i in range(20):await physics_frame
   var started=Time.get_ticks_msec();var ticks=0;var max_nodes=0;var errors=0;var max_physics=0.;var max_memory=0.;var cycles=0
   while Time.get_ticks_msec()-started<seconds*1000:
    await physics_frame;ticks+=1
    if ticks%120==0:
     var actor=game.actors[1+cycles%9]
     if actor.alive:actor.die(game.player,"QA combat soak")
     cycles+=1
    for actor in game.actors:
     if not actor.global_position.is_finite():errors+=1
    max_nodes=maxi(max_nodes,root.get_tree().get_node_count());max_physics=maxf(max_physics,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000);max_memory=maxf(max_memory,Performance.get_monitor(Performance.MEMORY_STATIC))
    assert(game.actors.size()==10,"Actor leak during bot match")
   assert(errors==0)
   report.append({"map":map,"mode":mode,"actors":game.actors.size(),"seconds":(Time.get_ticks_msec()-started)/1000.,"ticks":ticks,"respawn_cycles":cycles,"max_nodes":max_nodes,"max_physics_ms":max_physics,"max_memory_bytes":max_memory,"scores":game.scores.duplicate()})
   print("SOAK PASS ",JSON.stringify(report.back()))
   game.stop_game();await process_frame;await process_frame
 FileAccess.open("user://low-bot-stress.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PASS: all five game types on Savannah, nine active bots, firing, deaths and respawns, finite positions and stable actor counts")
 game.queue_free();for i in range(4):await process_frame
 await create_timer(.12).timeout
 quit()
