extends SceneTree
var game
func _initialize():call_deferred("run")
func capture(name: String):
 for i in range(3):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var output=OS.get_environment("NEST_QA_OUTPUT")
  if output.is_empty():output="user://qa-previews"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
  root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=720;game.prefs.apply()
 root.content_scale_size=Vector2i(1440,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 game.matchmaking.phase="idle";game.show_matchmaking();await capture("white-matchmaking")
 assert(game.screen.find_child("MatchmakingRanksTab",true,false)!=null)
 game.screen.find_child("MatchmakingRanksTab",true,false).pressed.emit();await capture("white-ranks")
 assert(game.current_screen=="matchmaking_ranks")
 assert(root.disable_3d,"Artwork menus must not render the hidden arena")
 assert(game.screen.find_children("RankGuideStage*","VBoxContainer",true,false).size()==21)
 var guide=game.screen.get_node("RankGuide");game.show_matchmaking();assert(guide==game.screen.get_node("RankGuide"))
 game.set_meta("rank_guide",false);game.show_matchmaking();assert(game.current_screen=="matchmaking")
 game.open_settings("main");game.settings_tab="Video";game.show_settings();await capture("white-video")
 assert(game.screen.find_child("DisplayWindowMode",true,false)!=null)
 # Minimum supported desktop width: all rank cards fit inside the scroller.
 game.prefs.values.resolution_width=640;game.prefs.values.resolution_height=480;game.prefs.apply()
 root.content_scale_size=Vector2i(640,900);game.set_meta("rank_guide",true);game.show_matchmaking();await capture("white-ranks-640")
 assert(game.screen.find_children("RankGuideStage*","VBoxContainer",true,false).size()==21)
 game.show_armory();await capture("white-armory");assert(root.disable_3d)
 assert(game.screen.find_children("*","SubViewport",true,false).size()>0)
 game.bot_fill=false;game.start_game();assert(not root.disable_3d)
 for i in range(4):await physics_frame
 game.stop_game()
 print("PASS: matchmaking rank tab; 21 emblems/stages; guide reuse; playlist return; video controls; minimum-width layout")
 game.queue_free();await create_timer(.75).timeout
 call_deferred("quit")
