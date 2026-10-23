extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 var rng=RandomNumberGenerator.new();rng.seed=35
 check(NestMatchmaking.winner([2,2,2,2,4,4],[0,2,3,4],rng)==2,"Four of six mode votes is a majority")
 check(NestMatchmaking.winner([1,1,1,1,0,0],[0,1],rng)==1,"Map majority counted independently")
 var outcomes={}
 for i in range(100):outcomes[NestMatchmaking.winner([2,2,2,4,4,4],[0,2,3,4],rng)]=true
 check(outcomes.size()==4,"Three-three tie randomly selects among available modes")
 check(NestMatchmaking.winner([], [0,1],rng) in [0,1],"Abstentions permit a random fallback")
 var entries={}
 for i in range(6):entries[i+100]={"rating":{"human":i*400}}
 var teams=NestMatchmaking.balanced_teams(entries);var counts=[0,0];var totals=[0,0]
 for id in teams:counts[teams[id]]+=1;totals[teams[id]]+=entries[id].rating.human
 check(counts==[3,3],"Solo queue always assigns three per team")
 check(absi(totals[0]-totals[1])==400,"Solo assignment finds minimum possible rating difference")
 check(NestMatchmaking.balanced_teams({}).is_empty(),"Incomplete rosters cannot form teams")
 check(FileAccess.file_exists("res://data/matchmaking.cfg"),"Packaged matchmaking endpoint configuration is available")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var mm=game.matchmaking
 check(mm.start_server(17956,"127.0.0.1")==OK,"Dedicated service opens without a host player")
 check(not game.multiplayer.server_relay,"Dedicated matchmaking disables unnecessary client-to-client relay")
 check(game.lobby_members.is_empty() and game.actors.is_empty(),"Server itself never occupies a human seat")
 check(game.lobby_kind=="matchmaking" and not game.bot_fill and game.team_size==3,"Matchmaking enforces six seats and disables initial bot filling")
 check(not game.apply_game_type_settings(GameTypeSettings.new()),"Custom lobby edits cannot mutate dedicated matchmaking rules")
 check(not game.apply_lobby_team(1,1),"Clients cannot override automatic teams")
 game.start_game();check(not game.running,"Manual start cannot bypass six-human/loading gate")
 mm.phase="loading";mm.loaded={1:true,2:true,3:true,4:true,5:true,6:true};game.start_game()
 check(not game.running,"Forged loading count cannot bypass actual connected peers")
 mm.phase="voting";mm.epoch=7;mm.abort_staging()
 check(mm.phase=="queue" and mm.epoch==8 and mm.loaded.is_empty() and mm.votes.is_empty(),"Interrupted staging invalidates old votes and loading acknowledgements")
 mm.phase="playing";game.running=true
 mm.slots[42]={"peer":55,"secret":"test-only","name":"Reserved","faction":0,"rating":{"human":0,"practice":0},"bot":true};mm.peers[55]=42;mm.rejoin_deadlines[55]=mm.clock()-1
 mm._process(0)
 check(not mm.peers.has(55) and mm.slots[42].peer==0 and mm.slots[42].bot and mm.rejoin_deadlines.is_empty(),"Stalled reconnect expires its connection while preserving the reserved bot slot")
 game.running=false
 mm.slots.clear();mm.peers.clear();mm.rejoin_deadlines[999]=mm.clock()+40
 mm.reset_queue()
 check(mm.rejoin_deadlines.is_empty(),"New queue cancels previous match reconnect deadlines")
 mm.slots[42]={"peer":0,"secret":"old-server-session","name":"Old","faction":0,"rating":{"human":0},"bot":true}
 check(mm.available_slot(42)==43 and mm.slots[42].name=="Old","Transport ID collision cannot overwrite an existing stable player slot")
 mm.last_request[88]=mm.clock();mm.anonymous[88]=mm.clock()+10
 check(mm.start_server(17956,"127.0.0.1")==OK,"Same process can restart dedicated service")
 check(mm.slots.is_empty() and mm.peers.is_empty() and mm.anonymous.is_empty() and mm.last_request.is_empty(),"Restart discards all old server reservations and transport bookkeeping")
 game.running=false;mm.slots.clear();mm.peers.clear();mm.active=false;game.close_connection();game.show_main();game.show_play_menu()
 check(game.screen.find_children("*","Button",true,false).any(func(b):return b.text=="Matchmaking · 3 vs 3"),"Play menu exposes matchmaking")
 game.open_matchmaking();await process_frame
 check(game.current_screen=="matchmaking" and game.context=="menu","Matchmaking screen does not launch custom auto-host")
 check(game.screen.find_children("*","ProgressBar",true,false).size()==1,"Connection progress animation is present")
 game.leave_matchmaking();check(game.current_screen=="main" and not mm.active,"Leaving restores normal main menu")
 game.queue_free();await process_frame
 print("MATCHMAKING UNIT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
