extends SceneTree
func _initialize():call_deferred("run")
func run():
 assert(not ResourceLoader.exists("res://scripts/bot_learning.gd"))
 assert(not GameTypeSettings.new().get_property_list().any(func(p):return p.name=="bot_copy_moves"))
 assert(not GameTypeSettings.definitions().any(func(d):return d.key=="bot_copy_moves"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 assert(not game.get_property_list().any(func(p):return p.name=="learning"))
 game.show_rating();assert(game.find_child("LearnMyMoves",true,false)==null)
 # Old stored settings must load without restoring the retired feature.
 var old=GameTypeSettings.new();old.apply_network_dict({"bot_copy_moves":true,"mode":2})
 print("PASS: recorder/replay class, setting, runtime field and menu removed")
 game.queue_free();for i in range(5):await process_frame
 quit()
