extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=5):
 for i in range(n):await process_frame
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS VISUAL: "+message)
 else:failures+=1;push_error("FAIL VISUAL: "+message)
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")==OK,"Saved "+name)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 await frames();game.show_lobby();await capture("V31_Organized_Lobby")
 game.open_game_type_settings();await frames();var editor=game.game_type_editor
 check(editor.position.x>=0 and editor.position.y>=0 and editor.position.x+editor.size.x<=root.get_visible_rect().size.x and editor.position.y+editor.size.y<=root.get_visible_rect().size.y,"Match editor fits 1280×800 viewport")
 await capture("V31_Organized_Settings")
 editor.search_box.text="damage";editor.search_box.text_changed.emit("damage");await capture("V31_Settings_Search")
 editor.close_editor();await frames();game.open_settings("lobby");await frames()
 game.preferences_search.text="sensitivity";game.preferences_search.text_changed.emit("sensitivity");await capture("V31_Preferences_Search")
 # Small supported layout: ensure footer actions remain inside the screen.
 root.size=Vector2i(1024,768);await frames();game.show_lobby();game.open_game_type_settings();await frames();editor=game.game_type_editor
 check(editor.position.x>=0 and editor.position.x+editor.size.x<=root.get_visible_rect().size.x,"Match editor fits 1024px width")
 await capture("V31_Settings_1024")
 game.queue_free();await frames(8)
 print("MENU VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
