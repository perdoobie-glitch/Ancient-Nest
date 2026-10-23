extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.prefs.light_preset();game.prefs.apply();var rows=[]
 var rules=NestMatchPresets.create(2,2,1);rules.max_players_per_team=8;rules.bots_fill_empty_slots=true;rules.bots_team_0=7;rules.bots_team_1=8
 game.apply_game_type_settings(rules)
 for round in range(5):
  game.start_game();game.context="playing"
  await create_timer(10).timeout
  assert(game.actors.size()==16);game.stop_game()
  for i in range(5):await process_frame
  var arenas=0
  for child in game.get_children():
   if child is NestArena:arenas+=1
  assert(arenas==1 and game.actors.is_empty())
  var row={"round":round,"arenas":arenas,"nodes_after_stop":root.get_tree().get_node_count(),"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.,"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)};rows.append(row);print("RESTART ",JSON.stringify(row))
 FileAccess.open("user://restart-plateau.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("PASS one arena and zero actors after each repeated match stop")
 game.queue_free();await create_timer(.3).timeout;quit()
