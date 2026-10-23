extends SceneTree
class BallotFixture:
 extends NestMatchmaking
 var connections=6
 func connected_count()->int:return connections
 func publish()->void:pass
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: ",text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var mm=BallotFixture.new();mm.game=game;game.add_child(mm);mm.set_process(false);mm.dedicated=true
 mm.phase="voting";mm.vote_stage="setup";mm.epoch=10
 for i in range(6):mm.votes[i]={"mode":1,"map":1}
 mm.last_request[42]=mm.clock()
 mm.resolve_vote()
 check(mm.last_request.is_empty(),"New life stage does not throttle the first valid fresh ballot")
 check(mm.phase=="voting" and mm.vote_stage=="life" and mm.epoch==11,"Dedicated FFA result advances to distinct life stage")
 check(mm.selected_mode==1 and mm.selected_map==1 and mm.votes.is_empty(),"Mode/map winners retained, old ballots discarded")
 check(NestMatchmaking.MODES.size()==5 and 1 in NestMatchmaking.MODES,"All five game types are available")
 for i in range(6):mm.votes[i]={"life":2}
 mm.resolve_vote()
 check(mm.phase=="loading" and mm.selected_matchup==2,"Life majority enters world loading")
 check(game.game_type.mode==1 and game.game_type.map_selection==1 and game.game_type.matchup==2,"Selected mode/map/life are authoritative rules")
 check(game.team_size==3 and not game.bot_fill and game.game_type.max_players==6,"Six human slots and no starting bots retained")
 mm.phase="voting";mm.vote_stage="setup";mm.votes.clear()
 for i in range(6):mm.votes[i]={"mode":0,"map":0}
 mm.resolve_vote()
 check(mm.phase=="loading" and mm.selected_matchup==3 and game.game_type.matchup==3,"Extraction skips life ballot and is Annu vs Naki")
 mm.phase="voting";mm.vote_stage="life";mm.connections=5;mm.resolve_vote()
 check(mm.phase=="queue" and mm.votes.is_empty(),"Lost human connection cancels life staging")
 mm.dedicated=false;mm.queue_free();game.queue_free()
 for i in range(6):await process_frame
 print("MATCHMAKING LIFE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
