extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func frames(n=4):
 for i in range(n):await process_frame
func capture(label: String):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v20_round/screenshots/"+label+".png")==OK,"Rendered "+label)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.create_hud();game.set_physics_process(false);game.set_process(false)
 game.player.set_physics_process(false);game.player.set_process(false);game.clear_screen();game.hud.visible=false;game.context="review";game.menu_camera.current=true
 for view in [["Central_Middle_Ramp",Vector3(7,6,-18),Vector3(0,3.5,-12),80],["Exterior_Ramp_Cover",Vector3(54,19,-13),Vector3(48.5,12,0),75],["Exterior_Ramp_Inside",Vector3(45,12,-9),Vector3(48,14,2),75],["Top_Floor_Glass",Vector3(27,17,15),Vector3(34,15,8),80],["Bottom_Ramp_Paths",Vector3(-19,8,20),Vector3(-25,1,10),80]]:
  game.menu_camera.global_position=view[1]*.85;game.menu_camera.look_at(view[2]*.85);game.menu_camera.fov=view[3];await capture(view[0])
 game.show_pause();await frames();var button=game.find_child("RestartRound",true,false)
 check(button!=null and not button.disabled,"Host can access Restart Round from pause")
 var bounds=button.get_parent().get_parent().get_global_rect();check(bounds.end.y<=root.get_visible_rect().size.y+1 and bounds.position.y>=-1,"Pause controls fit logical viewport")
 await capture("Pause_Restart_Round")
 game.open_game_type_settings();await frames();var editor=game.game_type_editor
 check(not editor.controls.mode.disabled and editor.apply_button.text=="Save Pending Changes","Mode edits and pending-save action are visible mid-match")
 await capture("In_Match_All_Settings")
 editor.set_draft_value("movement_speed_percent",120);editor.apply_changes();await frames()
 check(game.pending_game_type!=null and game.find_child("RestartRound",true,false).text.contains("Apply Settings"),"Pause button advertises applying pending rules")
 await capture("Pause_Apply_Pending")
 game.find_child("RestartRound",true,false).pressed.emit();await frames()
 check(game.running and not game.finished and game.player.traits.movement_speed_percent==120,"Restart button applies staged settings and returns to playing")
 game.stop_game();game.queue_free();await frames();print("ROUND VISUAL: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
