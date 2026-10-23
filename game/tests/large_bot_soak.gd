extends SceneTree
func _initialize():call_deferred("run")
func run():
 seed(91276);var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.prefs.light_preset();game.prefs.apply();var report=[]
 for bots in [12,15]:
  for map in ([2] if bots==12 else [0,1,2]):
   for mode in [0,1,2,3,4]:
    var rules=NestMatchPresets.create(mode,map,1);rules.max_players_per_team=8;rules.max_players=16;rules.bots_fill_empty_slots=true;rules.bots_team_0=bots/2;rules.bots_team_1=bots-bots/2;rules.score_to_win=1000
    game.apply_game_type_settings(rules);game.start_game();game.context="playing";game.clear_screen();game.create_hud();assert(game.actors.size()==bots+1);assert(Engine.physics_ticks_per_second==60)
    for i in range(20):await physics_frame
    var started=Time.get_ticks_msec();var ticks=0;var peak_nodes=0;var cycles=0;var seconds=10 if bots==12 else 6
    while Time.get_ticks_msec()-started<seconds*1000:
     await physics_frame;ticks+=1;assert(game.actors.size()==bots+1)
     if ticks%120==0:
      var actor=game.actors[1+cycles%bots]
      if actor.alive:actor.die(game.player,"Performance soak")
      cycles+=1
     for actor in game.actors:assert(actor.global_position.is_finite())
     peak_nodes=maxi(peak_nodes,root.get_tree().get_node_count())
    var row={"bots":bots,"map":map,"mode":mode,"seconds":(Time.get_ticks_msec()-started)/1000.,"ticks":ticks,"actors":game.actors.size(),"forced_death_cycles":cycles,"peak_nodes":peak_nodes,"memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.};report.append(row);print("SOAK PASS ",JSON.stringify(row))
    game.stop_game();await process_frame;await process_frame
 FileAccess.open("user://large-bot-soak.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PASS 20 large-bot scenarios: 12 bots on Savannah in all modes; 15 bots on all three maps in all modes;60Hz physics preserved")
 game.queue_free();await create_timer(.3).timeout;quit()
