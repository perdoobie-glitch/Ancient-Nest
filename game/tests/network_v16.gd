extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String):marks[key]=true
var game
var gate
var role="host"
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable) -> bool:
 var limit=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func run():
 role="client" if "client" in OS.get_cmdline_user_args() else "host"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);gate=Gate.new();gate.name="V16Gate";game.add_child(gate);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.matchup=1;rules.bots_fill_empty_slots=false;rules.max_players_per_team=1;game.apply_game_type_settings(rules)
 if role=="host":check(game.host_direct(19980,"V16Host",0)==OK,"Host opens direct lobby")
 else:check(game.join_direct("127.0.0.1",19980,"V16Client",1)==OK,"Separate client connects")
 check(await wait_for(func():return game.lobby_members.size()==2),"Accepted roster reaches both peers")
 if role=="host":
  check(await wait_for(func():return game.join_notice_rows.size()==1),"Host gets one join notification")
  check(game.join_notice_rows[0].node.get_child(0).text=="V16Client joined the lobby","Notification uses accepted username")
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  check(await wait_for(func():return gate.marks.has("ready")),"Client verified own join handling")
  game.start_game();game.create_hud();game.set_physics_process(false)
  for actor in game.actors:actor.set_physics_process(false);actor.health=50;actor.shield=25
  gate.mark.rpc_id(peer,"started")
  check(await wait_for(func():return gate.marks.has("playing")),"Client has entered the match")
  var next=game.game_type.duplicate_settings();next.gravity_percent=80;next.movement_speed_percent=120;next.max_health_percent=150;next.shield_strength_percent=200
  check(game.apply_game_type_settings(next),"Host applies live traits without restarting")
  check(game.player.health==50 and game.player.shield==25,"Host capacity edit preserves current damage")
  check(await wait_for(func():return gate.marks.has("updated")),"Reliable live rules reach client")
  check(game.game_type.gravity_percent==80,"Client cannot replace authoritative live rules")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  await create_timer(.2).timeout
  check(game.join_notice_rows.is_empty(),"Joining player gets no self/initial-roster notification")
  # Repeated registration must not duplicate acceptance or a host notification.
  game.register_member.rpc_id(1,"V16Client",1,NestMatch.NETWORK_VERSION);gate.mark.rpc_id(1,"ready")
  check(await wait_for(func():return game.running and gate.marks.has("started")),"Client enters host match")
  game.set_physics_process(false)
  for actor in game.actors:actor.set_physics_process(false);actor.health=50;actor.shield=25
  gate.mark.rpc_id(1,"playing")
  check(await wait_for(func():return game.game_type.gravity_percent==80),"Client receives changed gravity")
  check(game.player.traits.movement_speed_percent==120 and game.player.tuning.health_capacity==150 and game.player.tuning.shield_capacity==200,"Client refreshes live movement and capacities")
  check(game.player.health==50 and game.player.shield==25,"Client capacity edit preserves current damage")
  var rogue=game.game_type.duplicate_settings();rogue.gravity_percent=10
  check(not game.apply_game_type_settings(rogue),"Client cannot apply live rule changes")
  game.show_pause();game.open_game_type_settings();await process_frame
  check(game.game_type_editor!=null and not game.game_type_editor.editable,"Client pause editor is read-only")
  gate.mark.rpc_id(1,"updated");check(await wait_for(func():return gate.marks.has("done")),"Host confirms authority checks")
 print("V16 NETWORK ",role,": ",checks," checks, ",failures," failures")
 game.stop_game();game.close_connection();game.queue_free();await process_frame;quit(1 if failures else 0)
