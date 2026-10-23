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
 gate=Gate.new();gate.name="HudGate";game.add_child(gate)
 check((game.host_direct(17928,"HudHost",0) if role=="host" else game.join_direct("127.0.0.1",17928,"HudClient",1))==OK,"Real ENet peer opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Host and separate client join")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id>1)[0]
  game.start_game();freeze();game.context="pause"
  gate.mark.rpc_id(peer,"ready");check(await phase("client_ready"),"Client ready")
  var client=game.actor_by_id(peer)
  client.last_damage_weapon="battle_rifle";client.last_damage_region="torso"
  client.damage_received[game.player.combat_key()]={"normalized":100,"hits":6,"shots":4,"head_hits":2,"body_hits":4}
  client.damage_given[game.player.combat_key()]={"normalized":43,"hits":3,"shots":2,"head_hits":1,"body_hits":2}
  client.die(game.player,"bullet")
  check(game.local_kill_notice=="HudClient","Host gets own confirmed kill notice")
  gate.mark.rpc_id(peer,"dead");check(await phase("death_seen"),"Client receives authoritative killer recap")
  client.respawn();freeze();game.player.last_damage_weapon="sniper";game.player.last_damage_region="head";game.player.die(client,"headshot")
  gate.mark.rpc_id(peer,"kill");check(await phase("kill_seen"),"Client receives its own reliable kill notice")
  check(game.player.death_recap.killer=="HudClient","Host death identifies remote killer")
  game.receive_kill_notice.rpc_id(peer,"HudHost",game.player.net_id,game.player.life_id,game.match_session,game.round_number)
  gate.mark.rpc_id(peer,"duplicate");check(await phase("duplicate_seen"),"Duplicate notice checked on separate client")
  gate.mark.rpc_id(peer,"done");await create_timer(.25).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client starts match")
  freeze();game.context="pause";check(await phase("ready"),"Host fixture ready");gate.mark.rpc_id(1,"client_ready")
  check(await phase("dead") and await wait_for(func():return not game.player.alive and game.player.death_recap.get("killer","")=="HudHost"),"Client death receives host killer name")
  check(game.player.death_recap.get("final_kind","")=="battle_rifle" and game.player.death_recap.get("final_hit","")=="body","Client receives authoritative finishing weapon and body hit")
  check(game.player.death_recap.taken.shots==4 and game.player.death_recap.taken.hits==6 and game.player.death_recap.given.shots==2,"Shot and hit counts survive reliable recap delivery")
  check(game.player.death_recap.taken.head_hits==2 and game.player.death_recap.taken.body_hits==4 and game.player.death_recap.given.head_hits==1 and game.player.death_recap.given.body_hits==2,"Head/body breakdown preserves both directions across peers")
  check(game.player.death_recap.taken.normalized==100 and game.player.death_recap.given.normalized==43,"Damage directions remain correct across peers")
  check(game.local_kill_notice.is_empty(),"Victim does not get the attacker's personal kill notice")
  gate.mark.rpc_id(1,"death_seen")
  check(await phase("kill") and await wait_for(func():return game.local_kill_notice=="HudHost"),"Client killer receives victim name without waiting for kill-feed rendering")
  var expires=game.local_kill_notice_until;gate.mark.rpc_id(1,"kill_seen")
  check(await phase("duplicate"),"Duplicate reliable notice arrives");await create_timer(.15).timeout
  check(game.local_kill_notice_until==expires,"Repeated delivery does not extend notice")
  gate.mark.rpc_id(1,"duplicate_seen");check(await phase("done"),"Host acknowledges finished checks")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("COMBAT HUD NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
