extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.mode=2;game.start_game()
 await create_timer(.25).timeout
 var waterfall=game.get_node("WaterfallAmbience")
 check(waterfall.voice.playing,"Waterfall starts in a running match")
 game.stop_game()
 check(not waterfall.voice.playing and waterfall.gain==0,"Leaving stops the waterfall voice immediately")
 check(waterfall.voice.stream!=null,"Reusable ambience retains its configured stream between matches")
 await process_frame;game.start_game();await create_timer(.2).timeout
 check(waterfall.voice.playing,"Ambience restarts correctly in the next match")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("MATCHMAKING AUDIO CLEANUP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
