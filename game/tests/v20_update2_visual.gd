extends SceneTree
var game
var checks=0
var failures=0
const OUT="/workspace/work/v20_update2/screenshots/"
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=4):
 for i in range(n):await process_frame
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Rendered "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.apply_game_type_settings(NestGameTypeLibrary.load_type("builtin:4"));game.selected_character=1;game.show_lobby();await frames()
 var a=game.find_child("TeamAFaction",true,false);var b=game.find_child("TeamBFaction",true,false)
 check(a.is_visible_in_tree() and b.is_visible_in_tree(),"Both matchup selectors render inside lobby")
 game.lobby_character.get_popup().popup();await capture("Annu_Character_Options");game.lobby_character.get_popup().hide()
 await capture("Counter_Strike_Lobby")
 game.open_game_type_settings();await frames();var e=game.game_type_editor;e.tabs.current_tab=1
 e.set_draft_value("health_type",1);e.sync_draft_controls();await capture("Naki_Health_Settings")
 e.set_draft_value("health_type",2);e.sync_draft_controls();await capture("Annu_Health_Settings")
 check(e.size.x<=root.size.x and e.size.y<=root.size.y,"Embedded editor fits viewport")
 e.tabs.current_tab=0;e.saved_types.select(5);e.saved_types.item_selected.emit(5);e.load_selected_preset();await capture("Bomb_Round_Settings")
 e.close_editor();await frames();root.size=Vector2i(1280,720);await frames();game.show_lobby();await frames()
 var panel=game.find_child("CustomLobby",true,false);var bounds=panel.get_global_rect()
 check(bounds.end.x<=root.get_visible_rect().size.x+1 and bounds.end.y<=root.get_visible_rect().size.y+1,"Lobby fits logical viewport at a 1280 by 720 window")
 game.start_game();game.set_physics_process(false);game.context="pause"
 for actor in game.actors:actor.set_physics_process(false)
 game.player.global_position=game.arena.sites[0]+Vector3(-2.4,0,0);game.player.reset_physics_interpolation();game.player.rotation.y=-PI/2;game.player.reset_aim();game.player.camera.global_transform=game.player.eye.global_transform
 game.create_hud();game.hud.visible=true;game.clear_screen();game._process(.016)
 game.complete_interaction(game.player,game.interaction_for(game.player));game.cs_visual._process(0);game._process(.016)
 check(game.cs_planted() and game.cs_visual.visible,"Planted bomb has a visible device and armed HUD")
 await capture("Bomb_Planted_In_Game")
 game.stop_game();game.queue_free();await frames();print("V20 UPDATE2 VISUAL: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
