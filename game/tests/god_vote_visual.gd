extends SceneTree
var game
var count=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func shot(name):
 await frames(6);await RenderingServer.frame_post_draw
 var dir=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
 assert(root.get_texture().get_image().save_png(dir.path_join(name+".png"))==OK);count+=1;print("CAPTURE ",name)
func run():
 root.size=Vector2i(1280,800);game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null
 game.prefs.values.fullscreen=false;game.prefs.values.graphics_quality=0;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.apply();root.size=Vector2i(1280,800)
 game.show_lobby();await shot("01-normal-lobby-locked")
 game.lobby_vote.start();await shot("02-map-vote")
 game.lobby_vote.vote(0);await shot("03-mode-vote")
 game.lobby_vote.vote(2);await shot("04-life-vote")
 game.lobby_vote.vote(2);await shot("05-vote-result")
 game.begin_match();await frames(8);game.show_pause();await shot("06-pause-locked")
 game.send_chat("God");await frames();await shot("07-pause-unlocked")
 game.open_game_type_settings();await frames();game.game_type_editor.jump_to_category("Weapon Damage");await shot("08-god-weapon-damage")
 game.game_type_editor.close_editor();await frames();game.stop_game();game.show_main()
 var mm=game.matchmaking;mm.set_process(false);mm.active=true;mm.phase="voting";mm.local_slot=1;mm.until=mm.clock()+25
 var members={}
 for i in range(6):members[i+1]={"name":"QA player "+str(i+1),"faction":0 if i<3 else 1,"rating":{"human":0},"character":-1}
 mm.public_state={"connected":6,"members":members,"votes":{},"mode":2,"map":0,"vote_stage":"life","seconds":25};game.show_matchmaking();await shot("09-matchmaking-life-vote")
 mm.active=false;game.queue_free();await frames(8);print("GOD VOTE VISUAL: ",count," captures, 0 failures");quit()
