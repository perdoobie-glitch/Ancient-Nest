extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_physics_process(false);game.accounts.show_panel()
 for i in range(5):await process_frame
 var visible=root.get_visible_rect();var failures=0
 for button in game.screen.find_children("*","Button",true,false):
  var rect=button.get_global_rect()
  if rect.end.x>visible.size.x+1 or rect.end.y>visible.size.y+1 or rect.position.x<0 or rect.position.y<0:failures+=1;push_error("Account button outside viewport: "+button.text)
 print("ACCOUNT MENU: "+str(game.screen.find_children("*","Button",true,false).size())+" buttons, "+str(failures)+" layout failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
