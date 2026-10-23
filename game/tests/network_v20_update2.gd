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
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for a in game.actors:
  a.set_physics_process(false);a.global_position=game.arena.sites[0]+Vector3(0,0,2.4 if a.remote_peer>1 else -2.4);a.reset_physics_interpolation();a.reset_aim();a.update_visual(.016)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestGameTypeLibrary.load_type("builtin:4");rules.bots_fill_empty_slots=false;rules.max_players_per_team=2;game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="BombRoundGate";game.add_child(gate)
 check((game.host_direct(17922,"BombHost",0) if role=="host" else game.join_direct("127.0.0.1",17922,"BombClient",1))==OK,"Real ENet peer opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join update2 protocol")
 if role=="host":
  check(await wait_for(func():return game.lobby_members.values().all(func(m):return int(m.faction)==0)),"Client can change into host’s team through server validation")
  gate.mark.rpc("team_ok")
  check(await wait_for(func():return game.lobby_members.values().any(func(m):return int(m.faction)==1)),"Client can choose the second Annu team")
  check(await phase("lobby_ok"),"Client confirms all team and character options")
  game.start_game();game.context="pause";place()
  var remote=game.actors.filter(func(a):return a.remote_peer>1)[0];var peer=remote.remote_peer
  check(game.cs_carrier==game.player.net_id,"Host assigns authoritative bomb carrier")
  gate.mark.rpc_id(peer,"match_ready")
  check(await phase("client_match_ok"),"Client confirms bomb rules and carrier snapshot")
  var choice=game.interaction_for(game.player)
  check(choice.get("key","")=="cs_plant:0" and choice.get("seconds",0)==3.2,"Host sees valid CS plant duration at real map site")
  game.complete_interaction(game.player,choice)
  gate.mark.rpc_id(peer,"planted")
  check(await phase("use_sent"),"Client starts actual use input")
  check(await wait_for(func():return remote.cmd_queue.size()>0),"Sequenced use command reaches host")
  remote.process_remote_commands(1.0/60);remote.global_position=game.arena.sites[0]+Vector3(0,0,2.4);remote.net_last_command=game.now
  check(remote.net_interact,"Host processes held use command")
  game.remote_interactions.erase(peer);game.update_remote_interaction(remote,.1)
  check(game.remote_interactions.has(peer),"Host begins authoritative defusing")
  var ammo=remote.ammo[remote.slot]
  gate.mark.rpc_id(peer,"defusing")
  check(await phase("fire_sent"),"Client attack request arrives during defuse")
  await create_timer(.2).timeout
  check(remote.ammo[remote.slot]==ammo and game.net_stats.get("shots_rejected_state",0)>0,"Host rejects firing during defuse without spending ammo")
  game.remote_interactions[peer].time=0.0;remote.net_last_command=game.now
  game.update_remote_interaction(remote,9.99)
  check(game.break_until==0,"Authoritative defuse does not complete at 9.99 simulated seconds")
  remote.net_last_command=game.now;game.update_remote_interaction(remote,.02)
  check(game.break_until>game.now and game.scores[remote.faction]==1,"Ten simulated seconds defusing awards exactly one defender round")
  gate.mark.rpc_id(peer,"defused")
  check(await phase("client_score_ok"),"Client confirms winning round and break snapshots")
  # A new round restores exactly one life and transfers/drops the bomb correctly.
  game.reset_round();place();var p=game.player;p.die(remote,"test");place()
  check(game.cs_carrier==0 and game.cs_drop_position.is_finite(),"Server drops carrier’s bomb on death")
  gate.mark.rpc_id(peer,"dropped")
  check(await phase("client_drop_ok"),"Client sees dropped bomb and dead carrier")
  gate.mark.rpc_id(peer,"done");await create_timer(.2).timeout
 else:
  game.set_personal_team(0)
  check(await phase("team_ok") and await wait_for(func():return game.selected_faction==0),"Server acknowledges first-team choice")
  game.set_personal_team(1)
  check(await wait_for(func():return game.selected_faction==1),"Second Annu team selection is acknowledged")
  game.show_lobby();await process_frame
  check(not game.lobby_faction.disabled and game.lobby_faction.item_count==2,"Client team dropdown remains enabled with both teams")
  check(game.lobby_character.get_item_text(2)=="Annu","Client character menu includes Annu")
  game.set_personal_lobby(1,false);gate.mark.rpc_id(1,"lobby_ok")
  check(await wait_for(func():return game.running and game.player!=null),"Client enters authoritative match")
  game.context="pause";place()
  check(await phase("match_ready") and await wait_for(func():return game.cs_carrier!=0),"Bomb carrier reaches client through snapshots")
  check(game.mode==4 and game.tuning.round_seconds==120 and game.player.character==1,"CS mode, timing and chosen Annu character replicate")
  check(not game.complete_cs_interaction(game.player,{"key":"defuse:0","site":0}),"Client cannot directly award a defuse or round")
  gate.mark.rpc_id(1,"client_match_ok")
  check(await phase("planted") and await wait_for(func():return game.cs_planted()),"Plant and forty-second fuse replicate")
  check(game.interaction_for(game.player).get("seconds",0)==10,"Client shows ten-second defuse prompt")
  game.player.record_client_command(Vector2.ZERO,false,-1,true,0);gate.mark.rpc_id(1,"use_sent")
  check(await phase("defusing"),"Host confirms defuse progress")
  var p=game.player
  game.authorize_shot.rpc_id(1,game.next_event()*16,p.life_id,game.round_number,p.weapons[p.slot].kind,p.eye.global_position,Vector3.FORWARD,game.match_session,0)
  gate.mark.rpc_id(1,"fire_sent")
  check(await phase("defused") and await wait_for(func():return game.scores[p.faction]==1 and game.break_until>game.now),"Client receives single defender round score and break")
  gate.mark.rpc_id(1,"client_score_ok")
  check(await phase("dropped") and await wait_for(func():return game.cs_carrier==0 and game.cs_drop_position.is_finite()),"Dropped bomb position reaches client")
  check(await wait_for(func():return game.actors.any(func(a):return not a.alive and a.faction==0)),"Carrier death reaches client without auto-respawn")
  gate.mark.rpc_id(1,"client_drop_ok");check(await phase("done"),"Host completes round test")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("V20 UPDATE2 NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
