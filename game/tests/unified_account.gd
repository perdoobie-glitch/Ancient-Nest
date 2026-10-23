extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(5):await physics_frame
 assert(not game.accounts.linked())
 assert(game.NETWORK_VERSION=="10.5-discord1")
 game.accounts.show_panel();await process_frame
 assert(game.current_screen=="account")
 game.accounts.show_service_card();await process_frame
 assert(is_instance_valid(game.accounts.service_dialog))
 game.accounts.service_dialog.queue_free();await process_frame
 game.show_main();await process_frame
 assert(game.accounts.playlist_profiles.is_empty())
 game.queue_free();await create_timer(.5).timeout
 print("UNIFIED ACCOUNT UI: Discord account panel, unavailable service card, main menu and protocol passed")
 quit()
