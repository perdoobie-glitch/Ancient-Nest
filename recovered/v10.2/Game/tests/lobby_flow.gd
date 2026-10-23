extends SceneTree
var checks=0
var failures=0
var game
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func screenshot(name):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/lobby-flow/"+name+".png")
func within(child: Control, parent: Control) -> bool:
 return parent.get_global_rect().grow(1).encloses(child.get_global_rect())
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null
 await frames()
 var rules=GameTypeSettings.new();rules.game_type_name="Arena Custom";rules.mode=2;rules.score_to_win=450;rules.time_limit_seconds=0;rules.max_players_per_team=8;rules.bots_fill_empty_slots=false;rules.matchup=2;rules.bag_stock=7;rules.starting_primary="battle_rifle";rules.starting_secondary="ak47"
 check(game.apply_game_type_settings(rules),"Consolidated rules can be applied by the host")
 game.show_lobby();await frames()
 var lobby=game.screen.find_child("CustomLobby",true,false)
 var tabs=game.screen.find_child("LobbyTabs",true,false)
 check(tabs.get_tab_count()==2 and tabs.get_tab_title(0)=="Match Setup" and tabs.get_tab_title(1)=="Connection","Match setup and connections are separate grouped views")
 check(game.screen.find_children("*","SpinBox",true,false).is_empty() and game.screen.find_children("*","CheckButton",true,false).all(func(control):return control.name=="LobbyReady"),"Duplicate gameplay controls have been removed from the lobby")
 var summary=game.screen.find_child("MatchSummary",true,false)
 check(summary.text.contains("450") and summary.text.contains("No time limit") and summary.text.contains("Annu vs Annu") and summary.text.contains("8 players per team"),"Lobby summary accurately reflects advanced rules without clamping them")
 check(not summary.text.contains("gold bags") and game.screen.find_child("LoadoutSummary",true,false).text.contains("Bots off"),"Summary hides irrelevant extraction rules and explains disabled bots")
 check(within(game.lobby_faction,game.screen.find_child("PlayersPanel",true,false)) and within(game.screen.find_child("ViewCharacter",true,false),game.screen.find_child("PlayersPanel",true,false)),"Team and character actions are grouped with players")
 check(within(tabs,lobby) and within(game.screen.find_child("StartGame",true,false),lobby),"Lobby panels and start action fit within the window")
 await screenshot("match-setup")
 tabs.current_tab=1;await frames()
 var join=game.screen.find_child("JoinByAddress",true,false);var copy=game.screen.find_child("CopyJoinAddress",true,false)
 check(join.is_visible_in_tree() and copy.is_visible_in_tree(),"Join by IP/link and copy join address are together under Connection")
 join.pressed.emit();await frames()
 check(game.modal.visible and game.modal.title=="Join direct match","Grouped Join button still opens the working address dialog")
 game.modal.canceled.emit();await frames();await screenshot("connection")
 # Check a smaller viewport with a full roster. The roster scrolls; actions stay available.
 var old_size=root.size;root.size=Vector2i(1024,768)
 for id in range(1,17):game.lobby_members[id]={"name":"Player %d"%id,"faction":id%2}
 game.show_lobby();await frames(5)
 lobby=game.screen.find_child("CustomLobby",true,false);tabs=game.screen.find_child("LobbyTabs",true,false)
 check(within(lobby,game.screen) and within(tabs,lobby) and within(game.lobby_faction,lobby),"A full 16-player lobby fits at 1024 by 768")
 await screenshot("small-lobby")
 root.size=old_size;game.lobby_members.clear();game.show_lobby();game.open_game_type_settings();await frames()
 var editor=game.game_type_editor
 check(editor.controls.has("matchup") and editor.controls.has("bag_stock") and editor.tabs.get_tab_count()==7,"Previously separate rules are combined in the editor and Radar/Bots are split")
 check(not editor.controls.bag_stock.get_parent().visible and not editor.extraction_heading.visible,"Extraction-only fields and heading are hidden for deathmatch")
 editor.controls.mode.select(0);editor.controls.mode.item_selected.emit(0);await frames()
 check(editor.controls.bag_stock.get_parent().visible,"Changing mode reveals extraction rules immediately")
 editor.controls.matchup.select(1);editor.controls.matchup.item_selected.emit(1);editor.controls.bag_stock.value=9
 var saved=NestGameTypeLibrary.save_new(editor.draft,"Extraction Custom")
 var readback=NestGameTypeLibrary.load_saved(saved.id)
 check(readback.matchup==1 and readback.bag_stock==9,"Named game types retain both matchup and extraction settings")
 await screenshot("combined-rules")
 editor.apply_changes();await frames()
 check(game.matchup==1 and game.tuning.bag_stock==9 and game.lobby_faction.get_item_text(1).contains("Naki"),"Apply updates actual rules and team labels together")
 game.load_custom_preset()
 check(game.matchup==1 and game.game_type.matchup==1 and game.tuning.bag_stock==9,"Automatic lobby saves retain consolidated faction and objective settings")
 game.screen.find_child("StartGame",true,false).pressed.emit();await frames(8)
 check(game.running and game.mode==0 and is_inf(game.deadline) and game.tuning.score_limit==450 and game.team_size==8 and game.tuning.bag_stock==9,"Start Game uses applied rules without reading stale duplicate controls")
 game.stop_game();game.queue_free();await frames(5)
 print("LOBBY FLOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
