extends SceneTree
var checks=0
var failures=0
var sync_dir=""
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func wait_for(test: Callable,seconds: float=60):
 var until=Time.get_ticks_msec()+int(seconds*1000)
 while not test.call() and Time.get_ticks_msec()<until:await process_frame
 return test.call()
func run():
 Engine.max_fps=60
 sync_dir=OS.get_environment("ANCIENT_NEST_QA_SYNC")
 var index=int(OS.get_cmdline_user_args()[-1]);var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.values.username="Production"+str(index)
 var mm=game.matchmaking
 check(mm.search("127.0.0.1",17960)==OK,"Connects to unmodified exported dedicated server")
 check(await wait_for(func():return mm.phase=="voting"),"Six real clients reach production voting lobby")
 check(mm.public_state.connected==6 and mm.public_state.members.size()==6,"Production roster contains exactly six humans")
 await create_timer(.3).timeout;mm.vote(2,0)
 check(await wait_for(func():return game.running and mm.phase=="playing"),"Production server completes timed ballot and all-client load gate")
 check(game.mode==2 and game.game_type.map_selection==0,"Production server honors mode and map majority")
 check(game.actors.size()==6 and game.player!=null,"Production match has six actors and one local owner")
 check(await wait_for(func():return game.player.ack_seen>3),"Server acknowledges sequenced movement simulation")
 var before=int(game.player.ammo[game.player.slot])
 print("SHOT BEFORE faction=",game.player.faction," char=",game.player.character," kind=",game.player.weapons[game.player.slot].kind," ammo=",game.player.ammo," accepted=",game.player.accepted_shots," life=",game.player.life_id," pos=",game.player.global_position," eye=",game.player.eye.global_position," cam=",game.player.camera.global_position," seq=",game.command_sequence," ack=",game.player.ack_seen)
 check(game.player.fire_trigger(),"Local gun fires in production dedicated match")
 check(await wait_for(func():return game.player.ammo[game.player.slot]<before and game.player.pending_shots.is_empty(),10),"Production server confirms ammunition and shot acknowledgement")
 print("SHOT AFTER ammo=",game.player.ammo," accepted=",game.player.accepted_shots," pending=",game.player.pending_shots," life=",game.player.life_id," pos=",game.player.global_position," eye=",game.player.eye.global_position," cam=",game.player.camera.global_position," ack=",game.player.ack_seen)
 var file=FileAccess.open(sync_dir+"/client"+str(index),FileAccess.WRITE);file.store_string("done");file.close()
 check(await wait_for(func():return DirAccess.get_files_at(sync_dir).size()==6,20),"All six clients complete live gameplay checks")
 mm.leave();game.queue_free();await create_timer(.2).timeout
 print("PRODUCTION SERVER CLIENT %d: %d checks, %d failures"%[index,checks,failures]);quit(1 if failures else 0)
