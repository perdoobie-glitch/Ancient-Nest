extends SceneTree
var game
func _initialize():call_deferred("run")
func frames(n=6):
 for i in range(n):await process_frame
func snap(name):
 await frames(12);await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("/workspace/work/v5-hands/screenshots/"+name+".png")==OK);print("CAPTURE "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.lobby_network.set_process(false);game.lobby_network=null
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.apply()
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 game.show_main();await snap("01-main-menu")
 game.open_matchmaking();await snap("02-matchmaking")
 game.matchmaking.leave();game.open_custom_lobby(false);await snap("03-custom-lobby")
 game.bot_fill=true;game.team_size=3;game.game_type.bots_fill_empty_slots=true;game.game_type.bots_team_0=2;game.game_type.bots_team_1=3;game.game_type.bots_stand_still=true;game.game_type.bots_dont_shoot=true
 game.start_game();game.clear_screen();game.create_hud();game.hud.visible=true;game.context="playing"
 game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
 var p=game.player;p.global_position=Vector3(-8,12,17)*.85;p.rotation.y=0;p.eye.rotation.x=-.06
 var target=Vector3(20,10,-6)*.85;p.rotation.y=atan2(-(target.x-p.global_position.x),-(target.z-p.global_position.z));p.eye.rotation.x=atan2(target.y-p.eye.global_position.y,Vector2(target.x-p.global_position.x,target.z-p.global_position.z).length())
 p.presentation.update_view(.016);await snap("04-sanctuary-match")
 p.global_position=game.arena.spawns[0][0];p.rotation.y=PI*.5;p.eye.rotation.x=0;p.presentation.update_view(.016);await snap("05-match-hands")
 game.stop_game();game.queue_free();await frames();quit()
