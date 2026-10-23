extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func freeze():
 game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.apply_game_type_settings(GameTypeSettings.new());game.bot_fill=false;game.mode=2;game.clear_screen();game.start_game();freeze()
 game.show_pause();check(game.screen.find_child("PauseGameTypeSettings",true,false)!=null,"Pause offers game type and add/remove bots")
 game.open_match_setup();await frames();var ui=game.game_type_editor
 check(ui.visible and ui.controls.mode.item_count==5,"In-match setup shows all five modes")
 ui.controls.mode.select(3);ui.controls.mode.item_selected.emit(3);ui.controls.max_players_per_team.value=4;ui.controls.bots_team_0.value=2;ui.controls.bots_team_1.value=3;ui.controls.bot_difficulty.select(2);ui.controls.bot_difficulty.item_selected.emit(2)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/V26_Match_Setup.png")
 var session=game.match_session;ui.apply_changes();await frames()
 check(game.pending_game_type!=null and game.pending_game_type.bots_team_0==2 and game.pending_game_type.bots_team_1==3,"Exact per-team counts are staged")
 check(game.mode==2 and game.actors.size()==1 and game.match_session==session,"Saving leaves live roster and mode unchanged")
 var wire=game.pending_game_type.to_network_dict();var decoded=GameTypeSettings.new();decoded.apply_network_dict(wire)
 check(decoded.bots_team_0==2 and decoded.bots_team_1==3,"Bot counts serialize with validated game rules")
 game.scores.assign([3,2]);game.player.kills=4;game.ranked.eligible=true
 check(game.restart_round_in_match(),"Restart applies queued setup without leaving the match");freeze()
 check(game.mode==3 and game.actors.size()==6 and game.scores==[3,2] and game.player.kills==4,"Restart applies mode and exact bots while keeping scores")
 check(not game.ranked.eligible,"Changing the mode or roster mid-match cannot award a mismatched rating")
 check(game.actors.filter(func(a):return not a.local_player and a.faction==0).size()==2 and game.actors.filter(func(a):return not a.local_player and a.faction==1).size()==3,"Each faction gets its requested bot count")
 game.show_pause();game.open_match_setup();await frames();ui=game.game_type_editor
 ui.controls.bots_team_0.value=0;ui.controls.bots_team_1.value=0;ui.apply_and_restart();await frames();freeze()
 check(game.actors.size()==1 and game.context=="playing","Apply & Restart removes all bots and resumes gameplay")
 game.show_pause();game.open_match_setup();await frames();ui=game.game_type_editor
 ui.controls.max_players_per_team.value=2;ui.controls.bots_team_0.value=16;ui.controls.bots_team_1.value=-1;ui.apply_and_restart();await frames();freeze()
 check(game.actors.size()==4 and game.round_bot_count(0,1)==1 and game.round_bot_count(1,0)==2,"Explicit and automatic bot counts respect available team slots")
 game.show_pause();game.open_match_setup();await frames();ui=game.game_type_editor
 ui.controls.bots_fill_empty_slots.button_pressed=false;ui.apply_and_restart();await frames();freeze()
 check(game.actors.size()==1,"Disable bots overrides per-team counts")
 game.show_pause();game.open_match_setup();await frames();ui=game.game_type_editor
 ui.controls.mode.select(4);ui.close_editor();await frames()
 check(game.pending_game_type==null and game.mode==3,"Cancel discards the private setup draft")
 var invalid=GameTypeSettings.new();invalid.apply_network_dict({"bots_team_0":999,"bots_team_1":-999})
 check(invalid.bots_team_0==16 and invalid.bots_team_1==-1,"Untrusted counts are clamped")
 game.stop_game();game.queue_free();await frames(8)
 print("MATCH SETUP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
