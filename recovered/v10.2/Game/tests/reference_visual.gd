extends SceneTree
var game
var camera: Camera3D
var failures=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func shot(name: String):
 await frames(6);await RenderingServer.frame_post_draw
 var error=root.get_texture().get_image().save_png("user://"+name+".png")
 if error!=OK:failures+=1
 print("CAPTURE ",name," ",error)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.vsync=false;game.prefs.apply();root.size=Vector2i(1280,800)
 await shot("01-main-menu")
 game.show_play_menu();await shot("02-play-menu")
 game.show_armory();game.armory_select("plasma_br");await shot("03-triad-armory")
 game.armory_select("smg");await shot("04-falcon-armory")
 game.armory_select("plasma_sniper");await shot("05-plasma-sniper-armory")
 game.show_main();game.clear_screen();var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;rules.map_selection=0;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 for actor in game.actors:actor.set_physics_process(false);actor.set_process(false)
 game.hud.visible=false
 camera=Camera3D.new();camera.fov=70;game.add_child(camera);camera.current=true
 camera.position=Vector3(52,43,59);camera.look_at(Vector3(0,6,0));await shot("06-sanctuary-overview")
 camera.position=game.arena.to_global(Vector3(-3,8.7,8));camera.look_at(game.arena.to_global(Vector3(8,9,-12)));await shot("07-sanctuary-interior")
 camera.position=game.arena.to_global(Vector3(24,16,15));camera.look_at(game.arena.to_global(Vector3(4,14,5)));await shot("08-sanctuary-upper")
 game.stop_game();game.queue_free();await frames(6)
 print("NATIVE VISUAL: 8 captures, ",failures," failures");quit(1 if failures else 0)
