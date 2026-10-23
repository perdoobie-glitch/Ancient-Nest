extends SceneTree
var game
var mm
var role=""
var index=-1
var checks=0
var failures=0
var timeout_case=false
var stalled_rejoin=false
var registration_timeout=false
var results_rejoin=false
var voted_mode=2
var voted_map=1
var sync_dir="/workspace/work/v35/network/"
func _initialize():call_deferred("run")
func mark(key: String):
 var f=FileAccess.open(sync_dir+key,FileAccess.WRITE);f.store_string("ok");f.close()
func marked(key: String) -> bool:return FileAccess.file_exists(sync_dir+key)
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS "+role+": "+text)
 else:failures+=1;push_error("FAIL "+role+": "+text)
func wait_for(test: Callable,seconds: float=25.0):
 var until=Time.get_ticks_msec()+int(seconds*1000)
 while not test.call() and Time.get_ticks_msec()<until:await process_frame
 return test.call()
func run():
 Engine.max_fps=60
 if not OS.get_environment("ANCIENT_NEST_QA_SYNC").is_empty():sync_dir=OS.get_environment("ANCIENT_NEST_QA_SYNC").trim_suffix("/")+"/"
 timeout_case="--timeout" in OS.get_cmdline_user_args()
 stalled_rejoin="--stalled-rejoin" in OS.get_cmdline_user_args()
 registration_timeout="--registration-timeout" in OS.get_cmdline_user_args()
 results_rejoin="--results-rejoin" in OS.get_cmdline_user_args()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--vote-mode="):voted_mode=int(argument.get_slice("=",1))
  if argument.begins_with("--vote-map="):voted_map=int(argument.get_slice("=",1))
 role=OS.get_cmdline_user_args()[-1];index=int(role.trim_prefix("client")) if role.begins_with("client") else -1
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 mm=game.matchmaking
 if index==5:
  var bridge=mm.hybrid;mm.set_script(load("res://tests/matchmaking_hold_ack.gd"));mm.game=game;mm.hybrid=bridge
 if registration_timeout:await registration()
 elif role=="server":await server()
 elif role=="intruder":await intruder()
 else:await client()
 mm.active=false
 if game.running:game.stop_game()
 game.close_connection();game.queue_free();await create_timer(.1).timeout
 print("MATCHMAKING NETWORK "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func server():
 check(mm.start_server(17957,"127.0.0.1")==OK,"Dedicated server opens")
 mark("server-ready")
 check(await wait_for(func():return mm.connected_count()==5),"Five separate clients connect")
 check(mm.phase=="queue" and not game.running and game.actors.is_empty(),"Five humans cannot create/start match lobby or spawn filler bots")
 mark("five-checked")
 check(await wait_for(func():return mm.phase=="voting" and mm.connected_count()==6),"Six connected human clients open voting lobby")
 var counts=[0,0]
 for s in mm.slots.values():counts[s.faction]+=1
 check(counts==[3,3],"Solo players assigned to balanced 3v3")
 check(await wait_for(func():return mm.votes.size()==6),"All six map/mode ballots received")
 mm.resolve_vote()
 check(mm.selected_mode==voted_mode and mm.selected_map==voted_map,"Independent strict majorities choose requested mode %d / map %d"%[voted_mode,voted_map])
 if voted_mode!=0:
  check(mm.vote_stage=="life","Non-Extraction creates life stage")
  check(await wait_for(func():return mm.votes.size()==6),"All six life ballots received")
  mm.resolve_vote();check(mm.selected_matchup==2 and game.game_type.matchup==2,"Life majority uses Annu vs Annu")
 check(await wait_for(func():return mm.loaded.size()==5),"Five clients load while sixth deliberately withholds ready acknowledgement")
 check(not game.running and mm.phase=="loading" and game.actors.is_empty(),"Five ready acknowledgements cannot unlock the match")
 if timeout_case:
  mm.until=mm.clock()-1
  check(await wait_for(func():return mm.phase=="queue" and mm.connected_count()==5),"Missing world-ready acknowledgement times out to five-human queue")
  check(not game.running and game.actors.is_empty() and mm.loaded.is_empty(),"Timeout leaves no running match, actors, or stale ready acknowledgements")
  mark("timeout-done");await create_timer(1).timeout;return
 mark("release-load")
 check(await wait_for(func():return game.running),"Match starts only after six world-load acknowledgements")
 check(mm.loaded.size()==6 and game.actors.size()==6 and game.player==null,"Six actors, no server player or initial bots")
 check(game.actors.all(func(a):return a.remote_peer>1 and not a.local_player),"Every initial actor belongs to an actual connected client")
 check(not str(mm.public_state).contains("secret"),"Private resume secrets are excluded from public broadcasts")
 check(await wait_for(func():return game.actors.all(func(a):return a.cmd_last_seq>0)),"All six initial clients send valid session-bound movement commands")
 mark("match-live")
 check(await wait_for(func():return marked("intruder-done")),"Unauthorized seventh client rejected")
 check(mm.slots.size()==6 and game.actors.size()==6,"Wrong resume ticket cannot replace a human or create a bot")
 for actor in game.actors:actor.set_physics_process(false)
 var slot=0
 for id in mm.slots:
  if mm.slots[id].name=="Human0":slot=id
 var actor=game.actor_by_id(slot);var instance=actor.get_instance_id();var old_peer=actor.remote_peer
 var target=game.actors.filter(func(a):return a.faction!=actor.faction)[0]
 for i in range(game.actors.size()):game.actors[i].global_position=Vector3(500+i*8,50,500)
 actor.global_position=Vector3(400,50,410);target.global_position=Vector3(400,50,400);actor.rotation.y=0;actor.eye.rotation.x=0
 actor.weapons.assign([NestWeaponCatalog.profile("assault_rifle")]);actor.ammo.assign([30]);actor.reserve.assign([90]);actor.slot=0;actor.cooldown=0;actor.action_state="ready"
 for a in game.actors:a.reset_physics_interpolation();a.update_visual(.016)
 var target_before=target.health+target.shield+target.armor
 await physics_frame;mark("combat-ready")
 check(await wait_for(func():return actor.ammo[0]==29 and target.health+target.shield+target.armor<target_before),"Dedicated matchmaking routes one authoritative rifle hit and spends one round")
 mark("combat-checked")
 check(await wait_for(func():return marked("combat-client-confirmed")),"Shooter receives confirmed damage/round state before reconnect check")
 actor.health=73;actor.shield=91;actor.ammo[0]=11;actor.kills=4;actor.deaths=2;actor.reserve[0]=99
 mark("leave-now")
 check(await wait_for(func():return actor.remote_peer==0),"Disconnected human changes to server bot control")
 check(game.actors.size()==6 and actor.get_instance_id()==instance and actor.health==73 and actor.ammo[0]==11 and actor.kills==4,"Stand-in preserves same actor, health, ammo and score")
 # Exercise the actual substitute AI path for a tick, with others frozen.
 actor.set_physics_process(true);await physics_frame;actor.set_physics_process(false)
 check(actor.remote_peer==0 and not actor.local_player,"Temporary substitute uses existing authoritative bot simulation")
 var saved_health=actor.health;var saved_ammo=actor.ammo.duplicate();var saved_pos=actor.global_position
 mark("bot-confirmed")
 if stalled_rejoin:
  check(await wait_for(func():return mm.rejoin_deadlines.size()==1),"Reserved player reconnects but deliberately never acknowledges loading")
  check(actor.remote_peer==0 and mm.slots[slot].bot,"Unready reconnect cannot take control from substitute bot")
  var pending_peer=int(mm.rejoin_deadlines.keys()[0]);mm.rejoin_deadlines[pending_peer]=mm.clock()-1
  check(await wait_for(func():return int(mm.slots[slot].peer)==0 and not mm.peers.has(pending_peer)),"Stalled reconnect is removed after its loading deadline")
  check(game.running and mm.phase=="playing" and game.actors.size()==6 and actor.get_instance_id()==instance and actor.remote_peer==0 and mm.slots[slot].bot,"Other players keep playing and same bot actor remains available for a future rejoin")
  mark("done");await create_timer(1).timeout;return
 check(await wait_for(func():return actor.remote_peer>1 and actor.remote_peer!=old_peer),"Same human reconnects under new transport ID")
 check(actor.get_instance_id()==instance and game.actors.size()==6 and not mm.slots[slot].bot,"Rejoin reclaims original slot without duplicating actor")
 check(actor.health==saved_health and actor.ammo==saved_ammo and actor.global_position==saved_pos and actor.kills==4 and actor.deaths==2,"Rejoin preserves current authoritative state and statistics")
 check(game.actor_for_peer(actor.remote_peer)==actor and game.actor_for_peer(old_peer)==null,"Input authorization maps only current peer to stable slot")
 mark("rejoin-checked")
 check(await wait_for(func():return marked("rejoin-client-ready")),"Rejoining client confirms restored local view and health")
 check(await wait_for(func():return not actor.cmd_queue.is_empty()),"Rejoining movement commands reach the original actor")
 actor.set_physics_process(true)
 check(await wait_for(func():return actor.cmd_last_seq>2),"Rejoined actor resumes authoritative movement simulation")
 actor.set_physics_process(false)
 # End through the real authoritative scoring/rating completion path.
 game.scores.assign([int(game.tuning.score_limit) if actor.faction==0 else 0,int(game.tuning.score_limit) if actor.faction==1 else 0]);game.finish_match();await process_frame
 check(game.finished and mm.phase=="results","Authoritative match completion enters results")
 check(mm.slots.keys().all(func(id):return mm.slots[id].rating.human==game.actor_by_id(id).rank_human),"Queue retains new authoritative ratings for the next team assignment")
 if results_rejoin:
  mm.post_until=mm.clock()+60;mark("results-started")
  check(await wait_for(func():return marked("results-left") and actor.remote_peer==0),"Results screen disconnect preserves reserved actor")
  mark("results-rejoin-now")
  check(await wait_for(func():return marked("results-restored")),"Reconnect during results restores finished state rather than gameplay")
  check(mm.phase=="results" and actor.remote_peer>1 and not mm.slots[slot].bot,"Server remains in results after ownership is restored")
 mm.post_until=mm.clock();await process_frame
 check(await wait_for(func():return mm.phase=="voting"),"Completed six-human match returns to a new voting lobby")
 check(not game.running and mm.votes.is_empty() and game.actors.is_empty(),"New match clears old actors and ballots")
 mark("disconnect-vote")
 check(await wait_for(func():return mm.phase=="queue" and mm.connected_count()==5),"Human leaving voting cancels lobby instead of adding a bot")
 check(not game.running and mm.votes.is_empty() and mm.loaded.is_empty(),"Cancelled lobby cannot launch with stale votes or acknowledgements")
 mark("done");await create_timer(2).timeout
func client():
 game.prefs.values.username="Human"+str(index)
 check(mm.search("127.0.0.1",17957)==OK,"Real ENet client connects to queue")
 check(await wait_for(func():return mm.phase=="voting"),"Receives six-human voting lobby")
 check(mm.local_slot>0 and mm.ticket.length()==64,"Receives private per-slot rejoin secret")
 check(mm.public_state.connected==6 and mm.public_state.members.size()==6,"Lobby contains six connected humans")
 # Invalid ballots are rejected; then submit the intended selection.
 mm.cast_vote.rpc_id(1,mm.epoch-1,1,99);await create_timer(.2).timeout
 mm.vote(voted_mode if index<4 else (4 if voted_mode!=4 else 2),voted_map if index<4 else 1-voted_map)
 if voted_mode!=0:
  check(await wait_for(func():return mm.public_state.get("vote_stage","")=="life"),"Receives life-type voting stage")
  mm.vote(voted_mode,voted_map,2)
 if timeout_case:
  check(await wait_for(func():return marked("timeout-done")),"Server cancels loading when sixth client never becomes ready")
  check(not game.running or mm.blocks_simulation(),"Missing ready client never reaches unlocked gameplay")
  return
 if index==5:
  check(await wait_for(func():return marked("release-load")),"Server confirms sixth loading acknowledgement is still required")
  mm.loaded_world.rpc_id(1,mm.epoch)
 check(await wait_for(func():return game.running and mm.phase=="playing"),"Enters selected map after all client loading gates")
 check(game.mode==voted_mode and game.game_type.map_selection==voted_map and game.player!=null,"Selected map and mode match vote outcome")
 check(game.actors.size()==6 and game.actors.filter(func(a):return a.local_player).size()==1,"Exactly one local human avatar, no duplicate")
 check(await wait_for(func():return game.snapshot_received>=0 and game.match_session>0),"Live server session and snapshots synchronize before combat")
 check(not game.ranked.token.is_empty(),"Server rating session token reaches initial clients")
 var slot=mm.local_slot;var old_ticket=mm.ticket
 if index==0:
  check(await wait_for(func():return marked("combat-ready")),"Dedicated server prepares six-player combat check")
  var combat_ready=await wait_for(func():return game.player.weapons.size()==1 and game.player.weapons[0].kind=="rifle" and game.player.global_position.distance_to(Vector3(400,50,410))<1 and game.actors.any(func(a):return a.faction!=game.player.faction and a.global_position.distance_to(Vector3(400,50,400))<2))
  check(combat_ready,"Authoritative weapon and both test positions reach the shooter")
  if not combat_ready:return
  await create_timer(.1).timeout
  var target=game.actors.filter(func(a):return a.faction!=game.player.faction and a.global_position.distance_to(Vector3(400,50,400))<2)[0]
  game.player.reset_aim() # Artificial test teleport must also reset the top-level view camera.
  var offset=target.hitboxes[1].global_position-game.player.eye.global_position
  game.player.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());game.player.rotation.y=atan2(-offset.x,-offset.z);game.player.apply_aim_rotation()
  print("COMBAT BEFORE pos=",game.player.global_position," eye=",game.player.eye.global_position," camera=",game.player.camera.global_position," kind=",game.player.weapons[0].kind," ammo=",game.player.ammo)
  check(game.player.fire_trigger(),"Local firing responds during a dedicated six-player match")
  check(await wait_for(func():return marked("combat-checked")),"Server confirms damage and ammunition use")
  await create_timer(.3).timeout
  print("COMBAT AFTER ammo=",game.player.ammo," pending=",game.player.pending_shots," accepted=",game.player.accepted_shots," snapshots=",game.snapshot_received)
  check(await wait_for(func():return game.player.pending_shots.is_empty() and game.player.ammo[0]==29),"Authoritative shot acknowledgement clears predicted round without duplicate spending")
  mark("combat-client-confirmed")
  check(await wait_for(func():return marked("leave-now")),"Server requests controlled disconnect")
  mm.leave()
  check(game.last_cache_cleanup_count>=2,"Disconnect retires the exact native RPC-cache hooks")
  check(await wait_for(func():return marked("bot-confirmed")),"Server verifies bot substitution")
  if stalled_rejoin:
   var secret=mm.ticket;var endpoint=mm.endpoint;var port=mm.port
   var bridge=mm.hybrid;mm.set_script(load("res://tests/matchmaking_hold_ack.gd"));mm.game=game;mm.hybrid=bridge;mm.ticket=secret;mm.endpoint=endpoint;mm.port=port
  check(mm.search("127.0.0.1",17957)==OK,"Reconnect uses saved ticket")
  if stalled_rejoin:
   check(await wait_for(func():return marked("done")),"Server times out a reconnect without affecting five active humans")
   check(not game.running or mm.blocks_simulation(),"Unacknowledged reconnect never unlocks local controls")
   return
  check(await wait_for(func():return game.running and mm.phase=="playing" and game.player!=null),"Rejoin restores local control")
  check(mm.local_slot==slot and mm.ticket==old_ticket and game.player.net_id==slot,"Stable identity survives new ENet peer ID")
  check(game.player.health==73 and game.player.kills==4 and game.player.deaths==2,"Reliable resume snapshot restores health and score before input")
  mark("rejoin-client-ready")
  if results_rejoin:
   check(await wait_for(func():return marked("results-started")),"Waits for real match completion")
   mm.leave();mark("results-left")
   check(await wait_for(func():return marked("results-rejoin-now")),"Server retains results reservation")
   check(mm.search("127.0.0.1",17957)==OK,"Reconnect starts during results")
   check(await wait_for(func():return game.running and game.finished and mm.phase=="results"),"Reliable result snapshot preserves finished state on reconnect")
   check(game.context=="results" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Results reconnect leaves menu controls available")
   check(game.ranked.profile.data.human.games==1,"Results reconnect cannot duplicate the completed rating")
   check(not game.ranked.profile.last_result.is_empty(),"Reconnected results retain the confirmed rating summary")
   mark("results-restored")
 if stalled_rejoin:
  check(await wait_for(func():return marked("done")),"Existing human remains connected through stalled teammate rejoin")
  check(game.running and mm.phase=="playing","Active client stays in the running match")
  return
 check(await wait_for(func():return marked("disconnect-vote"),90),"Second voting lobby reached")
 if index==5:mm.leave()
 check(await wait_for(func():return marked("done")),"Interrupted voting safely returns remaining humans to queue")
 await create_timer(index*.15).timeout

func intruder():
 mm.ticket="not-a-valid-ticket"
 check(mm.search("127.0.0.1",17957)==OK,"Seventh real connection reaches server")
 check(await wait_for(func():return mm.phase=="error"),"No newcomer may fill an occupied or reserved match seat")
 check(not game.running and mm.local_slot==0,"Invalid ticket never creates a playable actor")
 mark("intruder-done")

func registration():
 if role=="server":
  mm.set_script(load("res://tests/matchmaking_ignore_registration.gd"));mm.game=game
  check(mm.start_server(17957,"127.0.0.1")==OK,"Unresponsive registration test server opens transport")
  mark("server-ready")
  check(await wait_for(func():return marked("registration-done")),"Client exits unresponsive registration safely")
  await create_timer(.3).timeout
 else:
  check(mm.search("127.0.0.1",17957)==OK,"Registration probe connects via real ENet")
  check(await wait_for(func():return mm.status.begins_with("Connected")),"Transport connects before application registration")
  check(mm.connect_until>mm.clock(),"Registration retains a bounded response deadline")
  mm.connect_until=mm.clock()-.01
  check(await wait_for(func():return mm.phase=="error"),"Missing application response returns to an actionable error screen")
  check(not game.network_active and not game.running and mm.local_slot==0,"Timed-out registration leaves no connection or playable slot")
  mark("registration-done")
