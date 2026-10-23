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
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+15000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for actor in game.actors:
  actor.set_physics_process(false);actor.set_process(false);actor.global_position=Vector3(100,30,90 if actor.net_id==1 else 100);actor.rotation.y=0;actor.eye.rotation.x=0;actor.reset_aim();actor.update_visual(.016)
  var weapon=actor.weapons[0].duplicate();weapon.spread_degrees=0;actor.weapons[0]=weapon
func run():
 role="client" if "client" in OS.get_cmdline_user_args() else "host"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false)
 gate=Gate.new();gate.name="TraitsGate";game.add_child(gate);await process_frame
 game.bot_fill=false;game.team_size=1
 if role=="host":
  var rules=game.game_type.duplicate_settings();rules.mode=1;rules.matchup=1;rules.bots_fill_empty_slots=false;rules.max_players_per_team=1;rules.spread_percent=0;rules.recoil_percent=0
  rules.character_traits={"naki":{"max_health_percent":80,"shield_strength_percent":150,"movement_speed_percent":140,"damage_resistance_percent":200},"annu":{"max_health_percent":150,"movement_speed_percent":60,"damage_dealt_percent":200,"starting_primary":"assault_rifle"}}
  check(game.apply_game_type_settings(rules),"Host applies the saved character trait table")
  check(game.host_direct(17944,"TraitsHost",0)==OK,"Host opens the local session")
 else:check(game.join_direct("127.0.0.1",17944,"TraitsClient",1)==OK,"Client joins")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers receive the full lobby")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  check(await phase("chosen"),"Client character and ready choice were acknowledged")
  check(game.lobby_members[peer].character==1 and game.lobby_members[peer].ready and game.lobby_members[1].character==-1,"A client can change only its own lobby slot")
  check(await phase("attack_sent"),"Client attempts invalid character and unauthorized rule changes")
  await create_timer(.3).timeout
  check(game.lobby_members[peer].character==1 and game.lobby_members[1].name=="TraitsHost" and game.game_type.character_traits.naki.max_health_percent==80,"Invalid requests and unauthorized authority RPCs do not alter host state")
  var updated=game.game_type.duplicate_settings();updated.character_traits.naki.max_health_percent=90;game.apply_game_type_settings(updated);game.apply_personal_lobby(1,0,true)
  check(await phase("updated"),"Changed host traits reach the client")
  game.start_game();place();gate.mark.rpc_id(peer,"place")
  check(game.player.character==0 and game.player.health==90 and game.player.shield==150,"Host spawns with its selected Naki traits")
  var shooter=game.actor_by_id(peer)
  check(shooter.character==1 and shooter.health==150 and shooter.traits.movement_speed_percent==60,"Server spawns the client's chosen Annu with authoritative traits")
  check(await phase("shot"),"Client predicts a shot")
  check(await wait_for(func():return game.player.shield==138),"Server combines outgoing character damage and target resistance exactly once")
  gate.mark.rpc_id(peer,"confirmed");check(await phase("client_done"),"Client reconciles authoritative character damage")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.game_type.character_traits.has("annu")),"Joining client receives every character's trait table")
  check(game.lobby_character!=null and not game.lobby_character.disabled,"Non-host character selector is usable")
  game.lobby_character.select(2);game.lobby_character.item_selected.emit(2)
  check(await wait_for(func():return game.selected_character==1),"Character choice is acknowledged by the host")
  game.screen.find_child("LobbyReady",true,false).button_pressed=true
  check(await wait_for(func():return game.lobby_ready),"Ready state is acknowledged")
  gate.mark.rpc_id(1,"chosen")
  var rogue=game.game_type.duplicate_settings();rogue.character_traits.naki.max_health_percent=999
  check(not game.apply_game_type_settings(rogue),"Non-host cannot apply trait edits")
  game.request_personal_lobby.rpc_id(1,9999,true)
  # This is deliberately a forbidden RPC. Godot must reject its sender authority.
  game.update_lobby.rpc_id(1,{1:{"name":"Spoofed","faction":1}}, {"game_type":rogue.to_network_dict()})
  gate.mark.rpc_id(1,"attack_sent")
  check(await wait_for(func():return game.game_type.character_traits.naki.max_health_percent==90),"Host health changes synchronize to the client")
  game.open_game_type_settings();await process_frame;var editor=game.game_type_editor
  editor.character_selector.select(1);editor.character_selector.item_selected.emit(1)
  check(not editor.controls.max_health_percent.editable and editor.controls.max_health_percent.value==90 and editor.apply_button.disabled and editor.reset_character.disabled,"Client can inspect character traits but edit/apply/reset controls are locked")
  editor.close_editor();gate.mark.rpc_id(1,"updated")
  check(await wait_for(func():return game.running and game.player!=null),"Configured match starts")
  check(await phase("place"),"Shared combat fixture is ready");place();await physics_frame
  var p=game.player;var target=game.actor_by_id(1)
  check(p.character==1 and p.health==150 and target.character==0 and target.health==90 and target.shield==150,"Client mirrors selected characters and server protection values")
  check(p.traits.movement_speed_percent==60 and target.traits.movement_speed_percent==140 and not p.traits.show_low_health_vignette,"Client prediction and HUD resolve the same character traits")
  var offset=target.hitboxes[1].global_position-p.eye.global_position;p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.apply_aim_rotation();p.cooldown=0;game.command_sequence=0
  check(p.fire_trigger() and target.shield==150,"Local feedback appears without inventing predicted damage")
  gate.mark.rpc_id(1,"shot");check(await phase("confirmed"),"Host confirms the hit")
  check(await wait_for(func():return target.shield==138),"Confirmed per-character damage reaches the client")
  check(p.accepted_shots==1,"Authoritative feedback does not duplicate the predicted shot")
  gate.mark.rpc_id(1,"client_done");check(await phase("done"),"Host completes session")
 game.stop_game();game.close_connection();game.lobby_network.shutting_down=true;game.queue_free();await create_timer(.3).timeout
 print("NETWORK CHARACTER TRAITS "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
