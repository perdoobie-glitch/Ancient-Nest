extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null
 await process_frame;game.show_lobby();game.open_game_type_settings()
 for spec in [[1,"player"],[2,"movement"],[4,"weapons"]]:
  game.game_type_editor.tabs.current_tab=spec[0]
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/settings-editor/"+spec[1]+"-settings.png")
 game.game_type_editor.close_editor();game.queue_free();await process_frame;quit()
