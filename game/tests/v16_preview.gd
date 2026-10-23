extends SceneTree
var game
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func run():
 root.size=Vector2i(1280,720)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await frames()
 game.bot_fill=false;game.start_game();game.create_hud();game.set_physics_process(false)
 for actor in game.actors:actor.set_physics_process(false)
 game.clear_screen();game.hud.visible=false;game.player.camera.current=false;game.menu_camera.current=true;game.current_screen="review";game.arena.set_shadows_enabled(true)
 var views=[
 ["top",Vector3(7,17,16),Vector3(0,20,-15)],
 ["middle",Vector3(-7,10,10),Vector3(16,9,0)],
 ["bottom",Vector3(-4,3,5),Vector3(6,2,-5)],
 ["rafters",Vector3(-17,25,-17),Vector3(0,25,5)],
 ["exterior",Vector3(52,23,24),Vector3(20,17,10)]]
 for v in views:
  game.menu_camera.global_position=v[1]*.85;game.menu_camera.look_at(v[2]*.85);await frames(4);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v16/review-"+v[0]+".png");print("VIEW ",v[0])
 game.show_pause();game.show_join_notification("Player Two");await frames(4);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/v16/review-pause.png")
 game.stop_game();game.queue_free();await frames(2);quit()
