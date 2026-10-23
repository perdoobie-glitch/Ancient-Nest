extends SceneTree
var game
var checks=0
var failures=0
var role=""
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS ",role,": ",text)
 else:failures+=1;push_error("FAIL "+role+": "+text)
func wait_until(test: Callable,seconds=12.0):
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not test.call() and Time.get_ticks_msec()<deadline:await process_frame
 return test.call()
func ballot(mode: int):
 var seen={};var vote=game.lobby_vote
 var deadline=Time.get_ticks_msec()+12000
 while Time.get_ticks_msec()<deadline:
  if vote.complete() and int(vote.state.mode)==mode:return true
  if vote.active() and not seen.has(vote.state.epoch):
   seen[vote.state.epoch]=true;vote.vote(0 if vote.state.stage=="map" else mode if vote.state.stage=="mode" else 2)
  await process_frame
 return false
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var error=game.host_direct(17891,"VoteHost",0) if role=="host" else game.join_direct("127.0.0.1",17891,"VoteClient",1)
 check(error==OK,"Direct session opens")
 check(await wait_until(func():return game.lobby_members.size()==2),"Two connected players registered")
 if role=="host":game.lobby_vote.start()
 check(await ballot(0),"Both players' map/mode votes replicate and Extraction resolves")
 check(game.matchup==3,"Extraction life is Annu vs Naki on both peers")
 if role=="host":
  await create_timer(.25).timeout;game.lobby_vote.start()
 else:await wait_until(func():return game.lobby_vote.active())
 check(await ballot(2),"Second vote includes a replicated life stage")
 check(game.matchup==2,"Annu-only life winner applies to both peers")
 if role=="host":game.begin_match()
 check(await wait_until(func():return game.running),"Completed ballot starts synchronized match")
 if game.running:
  game.send_chat("God");await create_timer(.2).timeout
  check(game.god_mode==(role=="host"),"Only player-host can toggle God mode")
  if role=="host":
   check(not game.ranked.eligible,"Edited match is not rated");game.send_chat(":god");check(not game.god_mode,"Host toggle can turn back off")
  else:check(not game.can_edit_match_traits(),"Client trait editor stays locked")
  await create_timer(.5).timeout
 game.stop_game();game.close_connection();game.queue_free()
 for i in range(8):await process_frame
 print("NETWORK VOTE ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
