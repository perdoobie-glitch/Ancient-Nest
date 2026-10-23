extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String):marks[key]=true
var game
var gate
var role
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+role+": "+label)
 else:failures+=1;push_error("FAIL "+role+": "+label)
func wait_for(test: Callable):
 var until=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<until:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func freeze():
 for a in game.actors:a.set_physics_process(false);a.global_position=Vector3(200,100,200);a.reset_physics_interpolation()
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules)
 game.ranked.profile.data.human.elo=1200 if role=="host" else 1600;game.ranked.profile.save_data()
 gate=Gate.new();gate.name="RankGate";game.add_child(gate)
 check((game.host_direct(17927,"RankHost",0) if role=="host" else game.join_direct("127.0.0.1",17927,"RankClient",1))==OK,"Real ENet peer opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join v24 rating protocol")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id>1)[0]
  check(game.lobby_members[peer].rating.human==1600,"Client rating summary is received and bounded by host")
  game.start_game();freeze();game.context="pause"
  gate.mark.rpc_id(peer,"ready");check(await phase("client_ready"),"Client creates identical ranked match")
  check(game.ranked.eligible and game.ranked.channel=="human","Human-only match is eligible for human rating")
  check(game.actor_by_id(peer).rank_human==1600,"Server actor gets declared starting Elo")
  game.player.kills=4;game.player.deaths=1;game.actor_by_id(peer).kills=1;game.actor_by_id(peer).deaths=4;game.scores.assign([3,1]);game.finish_match()
  check(game.ranked.profile.data.human.elo==1229 and game.ranked.profile.data.practice.elo==0,"Upset win applies chess formula to Human only")
  check(game.ranked.profile.data.human.games==1 and game.ranked.profile.data.human.kills==4,"Completed match records KD once")
  gate.mark.rpc_id(peer,"finished");check(await phase("result_seen"),"Separate client receives authoritative result")
  game.receive_rating_result.rpc_id(peer,game.ranked.last_packet)
  gate.mark.rpc_id(peer,"duplicate");check(await phase("duplicate_seen"),"Duplicate result received without duplicate award")
  gate.mark.rpc_id(peer,"acknowledged");await create_timer(.25).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client starts match")
  freeze();game.context="pause";check(await phase("ready"),"Host signals fixture ready")
  check(game.ranked.eligible and game.ranked.channel=="human" and not game.ranked.token.is_empty(),"Client installs same human channel and stable token")
  check(game.player.rank_human==1600 and game.ranked.roster[1].before==1200,"Client receives both starting Elo values")
  gate.mark.rpc_id(1,"client_ready")
  check(await phase("finished") and await wait_for(func():return game.ranked.profile.data.human.games==1),"Reliable completed-match result reaches local profile")
  check(game.ranked.profile.data.human.elo==1571 and game.ranked.profile.data.practice.elo==0,"Loss decreases only Human rating")
  check(game.ranked.profile.data.human.kills==1 and game.ranked.profile.data.human.deaths==4,"Client receives own authoritative KD totals")
  check(NestRatingProfile.kd_percent(1,4)==20,"Client KD percentage uses confirmed match stats")
  gate.mark.rpc_id(1,"result_seen");check(await phase("duplicate"),"Host resends same completed result")
  await create_timer(.15).timeout;check(game.ranked.profile.data.human.games==1 and game.ranked.profile.data.human.elo==1571,"Repeated packet cannot award another loss or stats")
  var fake=game.ranked.last_packet.duplicate(true);fake.token="wrong-session";check(not game.ranked.accept(fake),"Wrong-session result is rejected")
  gate.mark.rpc_id(1,"duplicate_seen");check(await phase("acknowledged"),"Host acknowledges client checks")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("RATING NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
