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
 var end=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<end:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for a in game.actors:
  a.set_physics_process(false);a.set_process(false);a.position=Vector3(900,100,880 if a.net_id==1 else 900);a.rotation.y=0;a.eye.rotation.x=0;a.reset_physics_interpolation();a.reset_aim();a.update_visual(0)
func rockets():return game.effects.get_children().filter(func(n):return n.get_script()==load("res://scripts/bullet.gd") and n.profile.kind=="rocket")
func run():
 role=OS.get_cmdline_user_args()[0]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;rules.starting_primary=NestWeaponCatalog.for_kind("rocket").id;rules.starting_secondary="none";game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="RocketGate";game.add_child(gate)
 check((game.host_direct(17944,"RocketHost",0) if role=="host" else game.join_direct("127.0.0.1",17944,"RocketClient",1))==OK,"Real ENet peer opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Host/client lobby connects")
 if role=="host":
  game.start_game();place();game.context="pause"
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  gate.mark.rpc_id(peer,"ready");check(await phase("placed"),"Client installs matching placement")
  gate.mark.rpc_id(peer,"fire");check(await wait_for(func():return not rockets().is_empty()),"Server launches authorized physical rocket")
  if not rockets().is_empty():check(is_equal_approx(rockets()[0].profile.speed,32.8125) and not rockets()[0].cosmetic,"Host uses authoritative faster speed")
  await create_timer(.10).timeout;check(game.player.alive and game.player.shield==100,"No instant hitscan damage before rocket arrives")
  check(await wait_for(func():return not game.player.alive),"Server projectile contact resolves direct/explosion damage")
  check(game.actor_by_id(peer).ammo[0]==1,"One authorized rocket consumes one round")
  gate.mark.rpc_id(peer,"hit");check(await phase("seen"),"Client sees confirmed damage")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters rocket match")
  check(await phase("ready"),"Host confirms placement");place();gate.mark.rpc_id(1,"placed")
  check(game.player.weapons[0].kind=="rocket" and is_equal_approx(game.player.weapons[0].speed,32.8125),"Client receives same rocket profile")
  check(await phase("fire"),"Host permits shot");check(game.player.fire_trigger(),"Local rocket feedback starts immediately")
  check(not rockets().is_empty() and rockets()[0].get_node_or_null("RocketProjectile")!=null,"Predicted rocket has larger shaped visual")
  check(await phase("hit") and await wait_for(func():return not game.actor_by_id(1).alive),"Confirmed explosion reaches client")
  gate.mark.rpc_id(1,"seen");check(await phase("done"),"Host acknowledges result")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("NETWORK ROCKET "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
