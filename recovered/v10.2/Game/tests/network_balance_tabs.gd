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
 var end=Time.get_ticks_msec()+14000
 while not test.call() and Time.get_ticks_msec()<end:await process_frame
 return test.call()
func phase(label):return await wait_for(func():return gate.marks.has(label))
func freeze():
 for a in game.actors:a.set_physics_process(false);a.global_position=Vector3(200+a.faction*10,100,200);a.reset_physics_interpolation()
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;rules.max_players_per_team=1;game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="RoundGate";game.add_child(gate)
 check((game.host_direct(17925,"RoundHost",0) if role=="host" else game.join_direct("127.0.0.1",17925,"RoundClient",1))==OK,"Real ENet process opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both real peers join balance5 protocol")
 if role=="host":
  game.start_game();game.context="pause";freeze();game.scores.assign([3,2]);game.round_number=2;var session=game.match_session
  var remote=game.actors.filter(func(a):return a.remote_peer>1)[0];var peer=remote.remote_peer;var life=remote.life_id
  gate.mark.rpc_id(peer,"ready");check(await phase("client_ready"),"Client receives original match")
  var next=game.game_type.duplicate_settings();next.gravity_percent=70;next.starting_primary="plasma_auto";next.health_type=2;next.annu_body_health=180;next.annu_head_health=160;next.annu_body_armor=225;next.annu_head_armor=65;next.naki_body_shield_strength=2.7;next.naki_head_shield_strength=2.1;next.weapon_damage_percent.plasma_auto=50
  check(game.apply_game_type_settings(next) and game.game_type.gravity_percent==100,"Host queues traits without replacing active rules")
  gate.mark.rpc_id(peer,"pending");check(await phase("pending_seen"),"Client sees pending rules")
  remote.respawn();remote.set_physics_process(false);freeze()
  check(remote.life_id==life+1 and remote.traits.gravity_percent==70 and remote.weapons[0].kind=="plasma_auto","Server respawn applies queued traits and loadout")
  check(remote.health==180 and remote.armor==225 and remote.helmet_hp==65 and game.game_type.weapon_damage_scale("plasma_auto")==1,"Server respawn applies faction capacities while gun damage stays pending")
  check(game.player.traits.gravity_percent==100,"Other living player retains original traits")
  gate.mark.rpc_id(peer,"respawned");check(await phase("respawn_seen"),"Client confirms respawn traits and protection system")
  next=next.duplicate_settings();next.mode=4;next.matchup=3;next.max_players_per_team=2;next.bots_fill_empty_slots=true;game.apply_game_type_settings(next)
  gate.mark.rpc_id(peer,"restart_soon");check(await phase("old_saved"),"Client stores old session for stale-packet checks")
  check(game.restart_round_in_match(),"Host restarts current match with queued full rules");freeze();game.context="pause"
  check(game.mode==4 and game.actors.size()==4 and game.scores==[3,2] and game.round_number==2,"Host restart applies mode and bot roster while preserving score/round")
  check(game.match_session!=session and game.pending_game_type==null,"Host creates fresh packet session and clears draft")
  gate.mark.rpc_id(peer,"restarted");check(await phase("restart_seen"),"Client receives reliable round reset")
  remote=game.actor_by_id(peer)
  check(game.game_type.weapon_damage_scale("plasma_auto")==.5 and is_equal_approx(game.game_type.naki_body_shield_strength,2.7),"Round reset commits per-gun damage and Naki regional rules")
  remote.take_damage(100,"torso","bullet",false,game.player,game.next_event()*16,Vector3.ZERO,"plasma_auto")
  check(is_equal_approx(remote.health,178.725),"Server applies half plasma-auto damage against configured Annu body armour")
  gate.mark.rpc_id(peer,"balance_hit");check(await phase("balance_seen"),"Client sees server-authoritative custom damage result")
  check(await phase("stale_sent"),"Client sends delayed request from old round session")
  await create_timer(.15).timeout
  remote=game.actor_by_id(peer)
  check(remote.ammo[remote.slot]==remote.weapons[remote.slot].magazine,"Old-session shot request cannot spend new-round ammunition")
  gate.mark.rpc_id(peer,"new_fire");check(await wait_for(func():return remote.ammo[remote.slot]<remote.weapons[remote.slot].magazine),"Fresh-session client shot still works after restart")
  gate.mark.rpc_id(peer,"finish");check(await phase("client_done"),"Client confirms reset input and shot state");gate.mark.rpc_id(peer,"acknowledged");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters match");freeze();game.context="pause"
  check(await phase("ready"),"Host signals ready");gate.mark.rpc_id(1,"client_ready")
  check(await phase("pending") and await wait_for(func():return game.pending_game_type!=null),"Pending rules replicate through reliable RPC")
  check(game.player.traits.gravity_percent==100 and game.mode==2,"Pending edit leaves client’s live traits and mode unchanged")
  gate.mark.rpc_id(1,"pending_seen");var old_life=game.player.life_id
  check(await phase("respawned") and await wait_for(func():return game.player.life_id>old_life),"Respawn life transition reaches client")
  check(await wait_for(func():return game.player.traits.gravity_percent==70 and game.player.weapons[0].kind=="plasma_auto"),"Client installs matching traits and loadout on respawn")
  check(game.player.damage_model()=="annu" and game.player.shield==0,"Queued Annu health reaches client on death/respawn boundary")
  check(is_equal_approx(game.player.health,180) and game.player.armor==225 and game.player.helmet_hp==65,"Client receives configured Annu capacities on respawn")
  game.open_game_type_settings();await process_frame
  check(not game.game_type_editor.controls.annu_head_health.editable and not game.game_type_editor.weapon_controls.plasma_auto.editable,"Connected client views balance controls read-only")
  game.game_type_editor.hide();game.game_type_editor.queue_free();game.game_type_editor=null
  gate.mark.rpc_id(1,"respawn_seen")
  check(await phase("restart_soon"),"Host announces restart fixture");var previous=game.match_session;var old_round=game.round_number;var old_id=game.player.life_id
  gate.mark.rpc_id(1,"old_saved")
  check(await phase("restarted") and await wait_for(func():return game.match_session!=previous),"Round reset RPC creates client’s fresh session")
  freeze();game.context="pause"
  check(game.running and not game.finished and game.mode==4 and game.actors.size()==4,"Client stays in match with new mode and roster")
  check(game.round_number==2 and game.scores==[3,2] and game.pending_game_type==null,"Client preserves round number/score and clears pending settings")
  check(game.player.traits.gravity_percent==70 and game.team_characters==[1,0],"Restarted client has new movement and matchup")
  check(not game.restart_round_in_match(),"Client cannot restart a server round")
  check(game.game_type.weapon_damage_scale("plasma_auto")==.5 and is_equal_approx(game.game_type.naki_head_shield_strength,2.1),"Client installs identical weapon and regional shield settings on reset")
  gate.mark.rpc_id(1,"restart_seen")
  check(await phase("balance_hit") and await wait_for(func():return game.player.health<180),"Custom authoritative damage replicates to separate client")
  check(is_equal_approx(game.player.health,178.725),"Client health matches server damage calculation exactly")
  gate.mark.rpc_id(1,"balance_seen")
  game.authorize_shot.rpc_id(1,game.next_event()*16,old_id,old_round,game.player.weapons[0].kind,game.player.eye.global_position,Vector3.FORWARD,previous,0)
  gate.mark.rpc_id(1,"stale_sent")
  check(await phase("new_fire"),"Host rejects stale request and permits new one")
  check(game.player.fire_trigger(),"Client can fire immediately with reset local inputs")
  check(await phase("finish"),"Host accepted fresh-session shot")
  gate.mark.rpc_id(1,"client_done");check(await phase("acknowledged"),"Host acknowledges final client result before disconnect")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("BALANCE NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
