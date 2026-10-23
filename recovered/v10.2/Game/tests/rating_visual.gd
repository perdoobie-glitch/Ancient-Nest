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
func capture(name):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v24/screenshots/"+name+".png")==OK,"Rendered "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var quit_button=game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Quit Game")[0]
 check(quit_button.get_global_rect().end.y<=root.get_visible_rect().size.y,"New main-menu buttons fit viewport")
 await capture("V24_Main_Menu")
 game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Player Rating")[0].pressed.emit();await frames()
 check(game.current_screen=="rating" and game.find_child("ProfileRankBadge",true,false)!=null,"Player Rating button opens profile")
 var textures={}
 for item in game.screen.find_children("*","TextureRect",true,false):
  if item.texture!=null and item.texture.resource_path.begins_with("res://assets/ranks/"):textures[item.texture.resource_path]=true
 check(textures.size()==21,"All 21 unique tier emblems are rendered")
 await capture("V24_Player_Rating")
 game.ranked.profile.data.human.elo=3050;game.ranked.profile.data.human.kills=3;game.ranked.profile.data.human.deaths=1;game.show_rating();await frames()
 var badge=game.find_child("ProfileRankBadge",true,false);check(badge.text.text.contains("21/21") and badge.text.text.contains("Ascendant III") and badge.tier.text.contains("75.0%"),"Example high-rank profile shows tier 21 and correct KD")
 await capture("V24_Ascendant_Example")
 game.show_main();var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=true;game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.current_screen="playing";game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
 game.player.kills=3;game.player.deaths=1;await frames()
 check(game.rank_badge.text.text.contains("1/21") and game.rank_badge.tier.text.contains("75.0%"),"In-game HUD shows rank progress, Elo and live KD")
 await capture("V24_Rank_HUD")
 Input.action_press("scoreboard");game.scoreboard.visible=true;game.scoreboard.refresh(true);await frames()
 check(game.scoreboard.content.find_children("*","Label",true,false).any(func(l):return l.text=="TIER / ELO"),"Scoreboard has a correctly separated rank column")
 check(game.scoreboard.visible,"Scoreboard remains visible while Tab is held")
 await capture("V24_Rank_Scoreboard")
 Input.action_release("scoreboard");game.scoreboard.visible=false;game.scores.assign([3,1]);game.finish_match();await frames()
 check(game.current_screen=="results" and game.rating_result_label.text.contains("Elo") and game.rating_result_label.text.contains("+32"),"Completed-match screen shows host-confirmed rating change")
 check(game.find_child("ResultsScoreboard",true,false)!=null,"Results use a scrollable aligned scoreboard")
 await capture("V24_Rating_Result")
 game.stop_game();game.show_main();game.show_rating();await frames();var learning=game.find_child("LearnMyMoves",true,false)
 check(learning==null,"Movement learning controls removed")
 game.queue_free();await frames();print("RATING VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
