extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String):marks[key]=true
var game
var gate
var role
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+role+": "+message)
 if not ok:failures+=1
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 game.context="pause"
 for a in game.actors:
  a.set_physics_process(false);a.set_process(false)
  a.global_position=Vector3(100,30,90 if a.net_id==1 else 100)
  a.rotation.y=0;a.eye.rotation.x=0;a.reset_aim();a.reset_physics_interpolation();a.update_visual(0)
func aim_at(target):
 var p=game.player
 var offset=target.hitboxes[0].global_position-p.camera.global_position
 p.rotation.y=atan2(-offset.x,-offset.z)
 p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length())
 p.reset_aim();p.cooldown=game.now
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.sandbox_mode=true
 var rules=GameTypeSettings.new();rules.mode=1;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;rules.starting_primary="sniper_rifle";rules.starting_secondary="none"
 game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="BidirectionalGate";game.add_child(gate)
 check((game.host_direct(17955,"Host",0) if role=="host" else game.join_direct("127.0.0.1",17955,"Client",1))==OK,"ENet opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Two peers join")
 if role=="host":
  game.start_game();place();gate.mark.rpc("ready")
  check(await phase("placed"),"Client placed")
  var target=game.actors.filter(func(a):return a.remote_peer>1)[0]
  await physics_frame;aim_at(target)
  check(game.player.fire_trigger(),"Host fires")
  check(not target.alive,"Host shot kills remote actor")
  gate.mark.rpc("shot")
  check(await phase("seen"),"Client receives its own death")
  target.respawn();place();await create_timer(.2).timeout
  aim_at(target)
  check(game.player.fire_trigger(),"Host fires again at the respawned opponent")
  check(not target.alive,"Second sniper hit still damages the same opponent")
  gate.mark.rpc("second_shot")
  check(await phase("seen_second"),"Client receives repeated host damage")
  target.respawn();place();await create_timer(.2).timeout
  gate.mark.rpc("return_fire")
  check(await wait_for(func():return not game.player.alive),"Client shot kills host")
  gate.mark.rpc("done");check(await phase("ack"),"Client sees host death")
  await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters")
  check(await phase("ready"),"Host ready");place();await physics_frame;gate.mark.rpc_id(1,"placed")
  check(await phase("shot") and await wait_for(func():return not game.player.alive),"Host damage reaches local client")
  gate.mark.rpc_id(1,"seen")
  check(await phase("second_shot") and await wait_for(func():return not game.player.alive),"Repeated host damage reaches client after respawn")
  gate.mark.rpc_id(1,"seen_second")
  check(await phase("return_fire") and await wait_for(func():return game.player.alive),"Client respawns")
  place();await physics_frame;aim_at(game.actor_by_id(1))
  check(game.player.fire_trigger(),"Client fires back")
  check(await phase("done") and await wait_for(func():return not game.actor_by_id(1).alive),"Client observes host death")
  gate.mark.rpc_id(1,"ack");await create_timer(.1).timeout
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("BIDIRECTIONAL "+role+": failures="+str(failures));quit(1 if failures else 0)
