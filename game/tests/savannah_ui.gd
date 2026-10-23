extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(4,2);var data=rules.to_network_dict();var copy=GameTypeSettings.new();copy.apply_network_dict(data)
 assert(copy.map_selection==2 and copy.map_name=="Savannah")
 game.apply_game_type_settings(rules);game.show_lobby();await process_frame
 var options=game.screen.find_children("*","OptionButton",true,false);var found=false
 for option in options:
  for i in range(option.item_count):
   if option.get_item_text(i).begins_with("Savannah"):found=true
 assert(found)
 assert(NestMatchmaking.MAPS==[0,1,2])
 game.lobby_vote.state.stage="map";assert(game.lobby_vote.options()==[0,1,2])
 var forge=NestForgeMap.new(game);forge.game=game;forge.arena=game.arena
 assert(forge.save_path()=="user://forge_savannah_layout.json" and forge.map_id()=="savannah-v9-1")
 print("PASS: Savannah survives settings serialization; custom lobby option; three map votes; isolated Forge layout")
 game.queue_free();await create_timer(.3).timeout;quit()
