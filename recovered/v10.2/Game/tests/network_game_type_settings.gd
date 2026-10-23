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
 var limit=Time.get_ticks_msec()+12000
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
 gate=Gate.new();gate.name="SettingsGate";game.add_child(gate);await process_frame
 game.bot_fill=false;game.team_size=1
 if role=="host":
  var rules=game.game_type.duplicate_settings();rules.mode=1;rules.bots_fill_empty_slots=false;rules.max_players_per_team=1;rules.max_health_percent=150;rules.shield_strength_percent=200;rules.gravity_percent=50;rules.movement_speed_percent=175;rules.damage_dealt_percent=200;rules.fire_rate_percent=200;rules.reload_speed_percent=150;rules.infinite_ammo=2;rules.recoil_percent=0;rules.spread_percent=0;rules.starting_primary="assault_rifle";rules.matchup=1;rules.bag_stock=7;rules.time_limit_seconds=0;rules.score_to_win=450
  check(game.apply_game_type_settings(rules),"Host can apply custom lobby rules")
  check(game.host_direct(17914,"SettingsHost",0)==OK,"Host opens the local session")
 else:check(game.join_direct("127.0.0.1",17914,"SettingsClient",1)==OK,"Client joins the local session")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  check(await phase("rules_seen"),"Client receives host rules")
  game.start_game();place();gate.mark.rpc_id(peer,"place")
  check(await phase("shot"),"Client predicts a shot using the configured rules")
  check(await wait_for(func():return game.player.shield==176),"Host applies 200% rifle damage to 200 shields exactly once")
  var shooter=game.actor_by_id(peer)
  check(shooter.ammo[0]==shooter.weapons[0].magazine and shooter.accepted_shots==1,"Host enforces bottomless ammo and accepts one unique shot")
  gate.mark.rpc_id(peer,"confirmed");check(await phase("client_done"),"Client reconciles configured damage and ammunition")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.game_type.gravity_percent==50),"Reliable lobby config carries the new rules")
  check(game.tuning.health_capacity==150 and game.tuning.shield_capacity==200 and game.game_type.movement_speed_percent==175 and game.game_type.fire_rate_percent==200,"Capacities, movement and weapon tuning match the host")
  check(game.matchup==1 and game.tuning.bag_stock==7 and game.game_type.matchup==1,"Consolidated matchup and extraction rules reach the client")
  var summary=game.screen.find_child("MatchSummary",true,false)
  check(summary!=null and summary.text.contains("No time limit") and summary.text.contains("450") and summary.text.contains("Naki vs Naki"),"Client lobby summary reflects authoritative rules without changing them")
  var rogue=GameTypeSettings.new();rogue.damage_dealt_percent=1000
  check(not game.apply_game_type_settings(rogue) and game.game_type.damage_dealt_percent==200,"Client cannot replace host rules")
  game.open_game_type_settings();await process_frame
  check(not game.game_type_editor.editable and game.game_type_editor.apply_button.disabled,"Client sees a read-only rules window")
  var editor=game.game_type_editor
  editor.open_save_prompt();editor.saved_name_input.text="Shared Host Rules";editor.save_named_preset()
  check(not editor.name_dialog.visible and NestGameTypeLibrary.list_saved().size()==1 and NestGameTypeLibrary.load_saved(String(editor.saved_types.get_selected_metadata())).matchup==1,"Client can save a local copy of the host game type")
  check(editor.load_button.disabled and game.game_type.damage_dealt_percent==200,"Saving a client copy cannot change authoritative rules")
  game.game_type_editor.close_editor();gate.mark.rpc_id(1,"rules_seen")
  check(await wait_for(func():return game.running and game.player!=null),"Configured match starts")
  check(await phase("place"),"Shared shot fixture is ready");place();await physics_frame
  var p=game.player;var target=game.actor_by_id(1);var offset=target.hitboxes[1].global_position-p.eye.global_position
  p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.apply_aim_rotation();p.cooldown=0;game.command_sequence=0
  var magazine=p.ammo[0]
  check(p.fire_trigger() and p.ammo[0]==magazine and target.shield==200,"Predicted bottomless shot responds before authoritative damage")
  gate.mark.rpc_id(1,"shot");check(await phase("confirmed"),"Host confirms the shot")
  check(await wait_for(func():return target.shield==176),"Authoritative configured damage reaches client")
  check(p.ammo[0]==magazine and p.aim_punch==Vector2.ZERO,"Snapshot reconciliation preserves bottomless ammo and zero recoil")
  gate.mark.rpc_id(1,"client_done");check(await phase("done"),"Host completes session")
 game.stop_game();game.close_connection();game.lobby_network.shutting_down=true;game.queue_free();await create_timer(.3).timeout
 print("NETWORK GAME TYPE "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
