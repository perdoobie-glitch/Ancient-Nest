extends SceneTree
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=60
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rows=[]
 for map in [3,4,5]:
  for mode in [0,1,2,3,4]:
   var rules=NestMatchPresets.create(mode,map,1);rules.bots_fill_empty_slots=true;rules.bots_team_0=2;rules.bots_team_1=2
   game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.context="playing";game.current_screen="playing";game.create_hud();game.hud.visible=true
   assert(game.arena.map_selection==map and game.actors.size()==5,"Map or bot roster failed")
   await create_timer(4).timeout
   var bad=0
   for actor in game.actors:
    if not actor.position.is_finite() or actor.position.y< -6:bad+=1
   assert(bad==0,"Actor escaped the playable structure")
   assert(game.arena.sites.size()==2 and game.arena.flag_positions.size()==2)
   if mode==3:assert(game.flags.size()==2,"Both flag states created")
   if mode==4:assert(game.cs_carrier!=0 or game.cs_drop_position.is_finite() or game.cs_planted(),"Bomb state created")
   var row={"map":NestArena.MAP_NAMES[map],"mode":mode,"actors":game.actors.size(),"round":game.round_number,"invalid":bad,"running":game.running};rows.append(row);print("MODE_SMOKE ",JSON.stringify(row))
   game.stop_game();await process_frame
 FileAccess.open("user://frontier-modes.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
 game.queue_free();await create_timer(.3).timeout;print("FRONTIER MODES: 15 map/mode cases passed");quit()
