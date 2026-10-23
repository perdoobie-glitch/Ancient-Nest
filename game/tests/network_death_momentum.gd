extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key:String,value:Variant=true):marks[key]=value
var game
var gate
var role="host"
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test:Callable):
 var end=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<end:await process_frame
 return test.call()
func run():
 var args=OS.get_cmdline_user_args();role=args[0];var host_port=int(args[1]);var connect_port=int(args[2]);var output=args[3]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.team_size=1;game.mode=1
 gate=Gate.new();gate.name="DeathGate";game.add_child(gate)
 var floor=StaticBody3D.new();var c=CollisionShape3D.new();var b=BoxShape3D.new();b.size=Vector3(30,1,30);c.shape=b;floor.add_child(c);game.add_child(floor);floor.position=Vector3(600,79.5,600)
 check((game.host_direct(host_port,"DeathHost",0) if role=="host" else game.join_direct("127.0.0.1",connect_port,"DeathClient",1))==OK,"Separate ENet process connects")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers complete version handshake")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0];game.start_game();game.context="pause"
  for actor in game.actors:actor.position=Vector3(600,80.02,600 if actor.net_id==peer else 605);actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.update_visual(0);actor.reset_physics_interpolation()
  check(await wait_for(func():return gate.marks.has("started")),"Separate client starts gameplay")
  var target=game.actor_by_id(peer);target.tuning.respawn_seconds=8
  target.take_damage(10000,"head","heavy",false,game.player,9900000,game.player.eye.global_position,"rocket",3,target.hitboxes[0].global_position)
  check(not target.alive and game.corpses.get_child_count()==1,"Server spawns exactly one body for a remote player's death")
  var body=game.corpses.get_child(0);var body_ref=weakref(body);body.freeze=true;body.set_physics_process(false)
  check(await wait_for(func():return gate.marks.has("body")),"Reliable death body reaches separate client")
  var point=body.hitboxes[0].global_position;var origin=point+Vector3(0,0,3);game.launch_bullet(game.player,NestWeaponCatalog.profile("ak47"),origin,Vector3.FORWARD,0,false,9900016)
  check(body.applied_impacts.has("shot:9900016"),"Authoritative bullet hits corpse without living damage")
  game.receive_body_impulse.rpc(body.body_key,point,Vector3.FORWARD*40,"shot:9900016",game.match_session,game.round_number)
  gate.mark.rpc_id(peer,"impulse_sent")
  check(await wait_for(func():return gate.marks.has("impulse")),"Corpse impulse reaches client once despite duplicate reliable effect")
  check(target.deaths==1 and game.player.kills==1,"Post-death shot never awards duplicate damage or kills")
  check(await wait_for(func():return body_ref.get_ref()==null),"Host body expires after three seconds")
  gate.mark.rpc_id(peer,"expired");check(await wait_for(func():return gate.marks.has("done")),"Client finishes three-second lifetime verification");await create_timer(.2).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client starts predicted simulation");game.context="pause";gate.mark.rpc_id(1,"started")
  check(await wait_for(func():return game.corpses.get_child_count()==1),"Client receives actual character death body")
  var body=game.corpses.get_child(0);var body_ref=weakref(body)
  check(body.hitboxes.size()==17 and body.collision_layer==0,"Replicated corpse cannot become a living hit target or player obstruction")
  check(await wait_for(func():return not game.player.alive),"Server-confirmed dead state reaches local player")
  gate.mark.rpc_id(1,"body")
  check(await wait_for(func():return is_instance_valid(body) and body.applied_impacts.has("shot:9900016")),"Server-confirmed postmortem bullet impulse reaches local body")
  check(body.applied_impacts.size()==2,"Predicted cosmetic bullet and duplicate RPC never apply a second impulse")
  gate.mark.rpc_id(1,"impulse")
  check(await wait_for(func():return body_ref.get_ref()==null),"Client removes body after its three-second lifetime")
  check(game.death_body_keys.size()==1,"Expired body ID stays deduplicated until round cleanup")
  gate.mark.rpc_id(1,"done");await create_timer(.4).timeout
 var r={"role":role,"checks":checks,"failures":failures};FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(r,"  "));print("NETWORK DEATH ",JSON.stringify(r));game.stop_game();game.close_connection();game.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
