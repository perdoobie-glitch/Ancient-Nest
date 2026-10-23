extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var sensitivity=game.prefs.values.sensitivity
 game.open_settings("main");game.settings_tab="Controls";game.show_settings()
 var labels=game.screen.find_children("*","Label",true,false)
 assert(labels.any(func(label):return label.text=="Mouse sensitivity"))
 assert(not labels.any(func(label):return label.text.to_lower().contains("counter-strike")))
 assert(game.prefs.values.sensitivity==sensitivity)
 print("PASS: Mouse sensitivity label has no third-party reference; saved sensitivity unchanged")
 game.queue_free();for i in range(5):await process_frame
 quit()
