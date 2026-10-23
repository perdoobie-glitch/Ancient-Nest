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
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS "+role+": "+text)
 else:failures+=1;push_error("FAIL: "+text)
func wait_for(test: Callable):
 var end=Time.get_ticks_msec()+20000
 while not test.call() and Time.get_ticks_msec()<end:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 game.context="pause"
 for a in game.actors:
  a.set_physics_process(false);a.set_process(false);a.global_position=Vector3(100,30,90 if a.net_id==1 else 100);a.rotation.y=0;a.eye.rotation.x=0;a.reset_physics_interpolation();a.reset_aim();a.update_visual(0)
func wall(pos,size):
 var body=StaticBody3D.new();var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision);game.add_child(body);body.global_position=pos
func aim():
 var p=game.player;var delta=game.actor_by_id(1).hitboxes[0].global_position-p.eye.global_position
 p.rotation.y=atan2(-delta.x,-delta.z);p.eye.rotation.x=atan2(delta.y,Vector2(delta.x,delta.z).length());p.reset_aim()
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;rules.starting_primary="sniper_rifle";rules.starting_secondary="none";game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="CrosshairGate";game.add_child(gate)
 check((game.host_direct(17954,"AimHost",0) if role=="host" else game.join_direct("127.0.0.1",17954,"AimClient",1))==OK,"Real ENet connection opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Two real peers connect")
 if role=="host":
  game.start_game();place();wall(Vector3(100.3,game.actor_by_id(game.lobby_members.keys().filter(func(id):return id!=1)[0]).eye.global_position.y-.3,99.4),Vector3(.35,3,1.8))
  gate.mark.rpc("ready");check(await phase("placed"),"Client creates matching side cover")
  gate.mark.rpc("fire");check(await wait_for(func():return not game.player.alive),"Server confirms crosshair-clear shot past obstructed muzzle")
  var remote=game.actors.filter(func(a):return a.remote_peer>1)[0]
  check(remote.ammo[0]==remote.weapons[0].magazine-1,"Exactly one server-authorized round is consumed")
  check(await phase("hit_seen"),"Client receives confirmed kill")
  game.player.respawn();place();wall(Vector3(100,remote.eye.global_position.y,99.6),Vector3(2,3,.08));await create_timer(1.6).timeout
  gate.mark.rpc("front");check(await phase("front_fired"),"Client fires at wall under crosshair")
  check(await wait_for(func():return remote.ammo[0]==remote.weapons[0].magazine-2),"Server accepts second shot once cooldown expires")
  check(game.player.alive and game.player.shield==game.player.tuning.shield_capacity,"Server wall collision blocks damage to target behind it")
  gate.mark.rpc("done");check(await phase("finished"),"Client confirms wall-blocked result");gate.mark.rpc("ack");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters match")
  check(await phase("ready"),"Host has installed test placement");place();wall(Vector3(100.3,game.player.eye.global_position.y-.3,99.4),Vector3(.35,3,1.8));await physics_frame
  aim();check(not game.trace(game.player.eye.global_position,game.player.muzzle_position(),1,game.player.ray_exclusions()).is_empty(),"Client gun muzzle is blocked beside clear crosshair")
  gate.mark.rpc_id(1,"placed");check(await phase("fire") and game.player.fire_trigger(),"Client predicts immediate crosshair-origin shot")
  check(await wait_for(func():return not game.actor_by_id(1).alive),"Client observes server-confirmed target death");gate.mark.rpc_id(1,"hit_seen")
  check(await phase("front") and await wait_for(func():return game.actor_by_id(1).alive),"Host restores target for wall test")
  place();wall(Vector3(100,game.player.eye.global_position.y,99.6),Vector3(2,3,.08));await physics_frame;aim();game.player.cooldown=game.now
  check(game.player.fire_trigger(),"Client fires second actual shot toward blocking wall");gate.mark.rpc_id(1,"front_fired")
  check(await phase("done") and game.actor_by_id(1).alive,"Confirmed target survives behind wall");gate.mark.rpc_id(1,"finished");check(await phase("ack"),"Host acknowledges completion before disconnect")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("NETWORK CROSSHAIR "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
