extends SceneTree
class Bridge extends NestHybridNetwork:
 func master_connected() -> bool:return true
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(8):await process_frame
 var mm=game.matchmaking;mm.hybrid.queue_free();mm.hybrid=Bridge.new();mm.hybrid.game=game;mm.hybrid.mm=mm;mm.hybrid.player_id="me";mm.add_child(mm.hybrid);mm.active=true;mm.phase="party";mm.playlist="tactical_3v3";mm.party={"code":"TEST","leader":"me","members":[{"user":"me","name":"Perdoobie","leader":true},{"user":"friend","name":"Mishwad","leader":false}]};mm.status="Invite friends or choose a playlist and search.";game.show_matchmaking()
 for size in [Vector2i(1280,720),Vector2i(640,360)]:
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(size);root.size=size;root.content_scale_size=size;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  for i in range(10):await process_frame
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/v8/lobby-%dx%d.png"%[size.x,size.y])
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit()
