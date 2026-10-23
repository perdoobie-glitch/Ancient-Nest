extends SceneTree
var game
var failures=0
var captures=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func shot(name: String):
 await frames(6);await RenderingServer.frame_post_draw
 var directory=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
 var error=root.get_texture().get_image().save_png(directory.path_join(name+".png"));captures+=1
 if error!=OK:failures+=1
 print("CAPTURE ",name," ",error)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.lobby_network.set_process(false);game.lobby_network=null
 game.prefs.values.fullscreen=false;game.prefs.values.graphics_quality=0;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.apply();root.size=Vector2i(1280,800)
 await shot("01-main-menu")
 game.show_play_menu();await shot("02-play")
 game.show_player_menu();await shot("03-player")
 game.open_custom_lobby();await shot("04-lobby")
 var picker=game.screen.find_child("LobbyCategory",true,false);picker.select(1);picker.item_selected.emit(1);await shot("05-map-category")
 game.open_game_type_settings();await shot("06-match-settings");game.game_type_editor.close_editor();await frames()
 game.show_main();root.size=Vector2i(960,540);game.show_main();await shot("07-main-960")
 root.size=Vector2i(1280,800);game.show_main();game.clear_screen();var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;rules.map_selection=0;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 for actor in game.actors:actor.set_physics_process(false);actor.set_process(false)
 game.hud.visible=false
 var camera=Camera3D.new();camera.fov=70;game.add_child(camera);camera.current=true
 camera.position=game.arena.to_global(Vector3(-3,8.7,8));camera.look_at(game.arena.to_global(Vector3(8,9,-12)));await shot("08-sanctuary-interior-low")
 camera.position=game.arena.to_global(Vector3(24,16,15));camera.look_at(game.arena.to_global(Vector3(4,14,5)));await shot("09-sanctuary-upper-low")
 game.stop_game();game.remove_child(camera);camera.queue_free();game.show_main();rules.map_selection=1;game.apply_game_type_settings(rules);await frames();game.clear_screen();game.start_game();game.set_physics_process(false);game.set_process(false)
 for actor in game.actors:actor.set_physics_process(false);actor.set_process(false)
 game.hud.visible=false;camera=Camera3D.new();camera.fov=70;game.add_child(camera);camera.current=true
 camera.position=game.arena.to_global(Vector3(-29,2.2,-6));camera.look_at(game.arena.to_global(Vector3(-29,2,-23)));await shot("10-crossroads-court-low")
 camera.position=game.arena.to_global(Vector3(1,2.4,16));camera.look_at(game.arena.to_global(Vector3(0,2,-12)));await shot("11-crossroads-mid-low")
 game.stop_game();game.queue_free();await frames(5);print("POLISHED VISUAL: ",captures," captures, ",failures," failures");quit(1 if failures else 0)
