extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var report=[]
 for seed_id in [910,911]:
  for swap in [false,true]:
   seed(seed_id)
   var rules=NestMatchPresets.create(2,2,1);rules.max_players=10;rules.max_players_per_team=5;rules.bots_fill_empty_slots=true;rules.bots_team_0=-1;rules.bots_team_1=-1;rules.score_to_win=1000
   game.apply_game_type_settings(rules)
   var original=game.arena.spawns.duplicate(true)
   if swap:game.arena.spawns[0]=original[1];game.arena.spawns[1]=original[0]
   game.start_game();game.context="playing";game.player.local_player=false;game.player.bot_movement=NestBotMovement.new(game.player)
   var started=Time.get_ticks_msec();var ticks=0
   while Time.get_ticks_msec()-started<45000:
    await physics_frame;ticks+=1
    assert(game.actors.size()==10)
    for actor in game.actors:assert(actor.global_position.is_finite())
   var entry={"seed":seed_id,"swapped":swap,"scores":game.scores.duplicate(),"south_kills":game.scores[1] if swap else game.scores[0],"north_kills":game.scores[0] if swap else game.scores[1],"ticks":ticks};report.append(entry);print("SCRIMMAGE ",JSON.stringify(entry))
   game.stop_game();game.arena.spawns=original;await process_frame
 FileAccess.open("user://savannah-scrimmages.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.queue_free();await create_timer(.3).timeout;quit()
