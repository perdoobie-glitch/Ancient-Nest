extends SceneTree
var checks=0
var failures=0
var game
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=2):
 for i in range(n):await process_frame
func finish():
 print("GAME TYPE LIBRARY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func run():
 if "readback" in OS.get_cmdline_user_args():
  var entries=NestGameTypeLibrary.list_saved()
  var saved=entries.filter(func(e):return e.name=="Low Gravity Duel")
  check(saved.size()==1,"Named game type is still present after a process restart")
  if saved.size()==1:
   var rules=NestGameTypeLibrary.load_saved(saved[0].id)
   check(rules.gravity_percent==55 and rules.damage_dealt_percent==350,"A new process loads the complete saved rules")
  finish();return
 var rules=GameTypeSettings.new();rules.gravity_percent=35;rules.shield_strength_percent=250
 var first=NestGameTypeLibrary.save_new(rules,"  Moon Duel  ")
 check(first.ok and first.name=="Moon Duel","A new named game type is saved with a trimmed name")
 var second_rules=rules.duplicate_settings();second_rules.gravity_percent=200
 var second=NestGameTypeLibrary.save_new(second_rules,"Heavy Gravity")
 check(second.ok and first.id!=second.id,"Each game type gets its own save file")
 var loaded=NestGameTypeLibrary.load_saved(first.id)
 check(loaded.gravity_percent==35 and loaded.shield_strength_percent==250 and NestGameTypeLibrary.load_saved(second.id).gravity_percent==200,"Independent saves retain different rule values")
 var duplicate=NestGameTypeLibrary.save_new(second_rules,"moon duel")
 check(not duplicate.ok and NestGameTypeLibrary.load_saved(first.id).gravity_percent==35,"Duplicate names cannot overwrite existing game types")
 check(not NestGameTypeLibrary.save_new(rules,"   ").ok and not NestGameTypeLibrary.save_new(rules,"x".repeat(49)).ok,"Empty and overly long names are rejected")
 check(NestGameTypeLibrary.load_saved("../custom_game")==null and not NestGameTypeLibrary.valid_id("a/b"),"Preset identifiers cannot select paths outside the library")
 var path=NestGameTypeLibrary.DIRECTORY+"/"+"f".repeat(24)+".json"
 var corrupt=FileAccess.open(path,FileAccess.WRITE);corrupt.store_string("not JSON");corrupt.close()
 check(NestGameTypeLibrary.list_saved().size()==2,"Malformed saves do not prevent listing valid presets")
 var too_big=FileAccess.open(NestGameTypeLibrary.DIRECTORY+"/"+"e".repeat(24)+".json",FileAccess.WRITE);too_big.store_string("x".repeat(NestGameTypeLibrary.MAX_FILE_BYTES+1));too_big.close()
 check(NestGameTypeLibrary.list_saved().size()==2,"Oversized saves are ignored before parsing")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null
 await frames();game.show_lobby();game.open_game_type_settings();await frames()
 var editor=game.game_type_editor
 check(editor.save_new_button.text=="Save as New Game Type" and editor.saved_types.item_count==3,"The in-game editor lists saved game types and offers Save as New")
 editor.controls.gravity_percent.value=55;editor.controls.damage_dealt_percent.value=350
 editor.open_save_prompt();await frames()
 check(editor.name_dialog.visible and editor.saved_name_input.editable,"Save as New opens an embedded naming prompt")
 editor.saved_name_input.text="Moon Duel";editor.save_named_preset()
 check(editor.name_dialog.visible and not editor.save_error.text.is_empty(),"Duplicate-name errors stay visible in the naming prompt")
 editor.saved_name_input.text="Low Gravity Duel";editor.save_named_preset()
 check(not editor.name_dialog.visible and editor.saved_types.get_item_text(editor.saved_types.selected)=="Low Gravity Duel","Successful save selects the new game type")
 check(game.game_type.gravity_percent==100 and editor.draft.game_type_name=="Low Gravity Duel","Saving a named copy leaves active host rules unchanged")
 var count=NestGameTypeLibrary.list_saved().size();editor.open_save_prompt();editor.saved_name_input.text="Cancelled Copy";editor.dismiss_back()
 check(editor.visible and not editor.name_dialog.visible and NestGameTypeLibrary.list_saved().size()==count,"Back cancels the naming prompt without closing the editor or saving")
 editor.controls.gravity_percent.value=100;editor.controls.damage_dealt_percent.value=100;editor.load_selected_preset()
 check(editor.draft.gravity_percent==55 and editor.controls.gravity_percent.value==55 and editor.controls.damage_dealt_percent.value==350,"Loading restores the complete rule draft and visible controls")
 check(game.game_type.gravity_percent==100,"Loading a draft does not silently change the match")
 # Render both editor and nested save prompt during a native run.
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/game-type-library/library.png")
  editor.open_save_prompt();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/game-type-library/name-prompt.png");editor.name_dialog.hide()
 editor.apply_changes();await frames()
 check(game.game_type.game_type_name=="Low Gravity Duel" and game.game_type.gravity_percent==55,"Apply selects the loaded named game type for the next match")
 check(NestGameTypeLibrary.load_saved(first.id).gravity_percent==35,"Applying another game type preserves older saved files")
 game.queue_free();await frames(4);finish()
