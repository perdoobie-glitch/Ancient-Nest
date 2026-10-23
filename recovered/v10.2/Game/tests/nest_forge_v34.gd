extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error(message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 check(game.screen.find_children("*","Button",true,false).any(func(b):return b.text=="Nest Forge"),"Main menu uses Nest Forge")
 var arena=game.arena;var file=FileAccess.open("user://forge_sanctuary_wide_layout.json",FileAccess.WRITE);file.store_string("{broken");file.close()
 check(not game.forge_session.load_saved(),"Invalid saved JSON is rejected")
 check(game.forge_session.model==null and game.arena==arena,"Rejected JSON does not replace the map or create an editor model")
 game.open_forge();await process_frame
 check(game.restore_focus=="Nest Forge" and game.screen.find_children("*","Label",true,false).any(func(l):return l.text=="NEST FORGE LOBBY"),"Nest Forge lobby and return focus use the new name")
 game.start_forge_session();await process_frame
 var session=game.forge_session
 check(session.active and game.forge_editor.editing,"Nest Forge opens the working shared editor")
 check(session.save(),"Current layout saves successfully")
 var reloads_ok=true
 for i in range(32):reloads_ok=session.load_saved() and reloads_ok
 check(reloads_ok,"Repeated saved-layout reloads succeed")
 check(session.history.size()<=30,"Repeated saved-layout loads keep the same bounded undo history as edits")
 session.stop_editing();game.show_main();await process_frame
 check(game.screen.find_children("*","Button",true,false).any(func(b):return b.text=="Nest Forge"),"Leaving editor returns to renamed menu")
 game.queue_free();await process_frame;await process_frame
 print("V34 NEST FORGE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
