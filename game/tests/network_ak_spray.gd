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
var actual={}
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
 gate=Gate.new();gate.name="SprayGate";game.add_child(gate)
 var floor=StaticBody3D.new();var cs=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(40,1,40);cs.shape=box;floor.add_child(cs);game.add_child(floor);floor.position=Vector3(600,99.5,600)
 check((game.host_direct(host_port,"SprayHost",0) if role=="host" else game.join_direct("127.0.0.1",connect_port,"SprayClient",1))==OK,"Separate ENet process connects")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers complete current version handshake")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0];game.start_game();game.context="pause"
  for actor in game.actors:
   actor.position=Vector3(600,100.02,605 if actor.net_id==1 else 600);actor.rotation=Vector3.ZERO;actor.eye.rotation=Vector3.ZERO;actor.set_physics_process(actor.net_id!=1);actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.reset_physics_interpolation();actor.update_visual(0)
  var remote=game.actor_by_id(peer)
  remote.shot_fired.connect(func(id,_time,_origin,dirs):actual[id]={"direction":dirs[0],"count":remote.ak_spray_count})
  gate.mark.rpc_id(peer,"ready");check(await wait_for(func():return gate.marks.has("sent")),"Client completes controlled spray, idle reset and reload")
  var expected:Dictionary=gate.marks.sent
  check(actual.size()==12 and remote.ammo[0]==29,"Server accepts twelve shots once and owns reload/ammunition")
  var maximum=0.;var matching=true
  for id in expected:
   if not actual.has(id):matching=false;continue
   maximum=maxf(maximum,actual[id].direction.distance_to(expected[id].direction))
   if actual[id].count!=expected[id].count:matching=false
  check(matching,"Server and client agree on every spray index and reset")
  check(maximum<.0001,"Authoritative and predicted shot directions agree (max delta %.8f)"%maximum)
  gate.mark.rpc_id(peer,"done");await create_timer(.4).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client starts gameplay")
  check(await wait_for(func():return gate.marks.has("ready")),"Host prepares static geometry fixture")
  await create_timer(.35).timeout;var p=game.player;p.set_process(false);p.reset_ak_spray();var predicted={}
  p.shot_fired.connect(func(id,_time,_origin,dirs):predicted[id]={"direction":dirs[0],"count":p.ak_spray_count})
  for i in range(10):
   p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.aim_punch=Vector2.ZERO;p.apply_aim_rotation();p.camera.global_position=p.eye.global_position;p.fire_trigger();await create_timer(.17).timeout
  check(predicted.size()==10 and p.ak_spray_count==10,"Client fires ten bullets with progressive spray")
  await create_timer(1.05).timeout;p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.aim_punch=Vector2.ZERO;p.apply_aim_rotation();p.camera.global_position=p.eye.global_position;p.fire_trigger();await create_timer(.2).timeout
  check(p.ak_spray_count==1,"One second idle resets the next shot locally")
  p.reload_weapon();await create_timer(2.65).timeout;check(p.ammo[0]==30 and p.ak_spray_count==0,"Authoritative reload clears spray and refills correctly")
  p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.aim_punch=Vector2.ZERO;p.apply_aim_rotation();p.camera.global_position=p.eye.global_position;p.fire_trigger();await create_timer(.25).timeout
  gate.mark.rpc_id(1,"sent",predicted);check(await wait_for(func():return gate.marks.has("done")),"Server validates matching directions and ammunition")
 var data={"role":role,"checks":checks,"failures":failures,"server_shots":actual.size(),"stats":game.net_stats};FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data,"  "));print("NETWORK SPRAY ",JSON.stringify(data));game.stop_game();game.close_connection();game.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
