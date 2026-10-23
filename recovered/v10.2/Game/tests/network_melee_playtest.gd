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
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for actor in game.actors:
  actor.position=Vector3(600,80.04,598.3 if actor.net_id==1 else 600);actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.rotation.y=0;actor.eye.rotation.x=0;actor.reset_physics_interpolation();actor.reset_aim();actor.update_visual(0)
func run():
 var args=OS.get_cmdline_user_args();role=args[0];var host_port=int(args[1]);var connect_port=int(args[2]);var output=args[3]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.team_size=1;game.mode=1
 gate=Gate.new();gate.name="MeleeGate";game.add_child(gate)
 var floor=StaticBody3D.new();var c=CollisionShape3D.new();var b=BoxShape3D.new();b.size=Vector3(30,1,30);c.shape=b;floor.add_child(c);game.add_child(floor);floor.position=Vector3(600,79.5,600)
 check((game.host_direct(host_port,"MeleeHost",0) if role=="host" else game.join_direct("127.0.0.1",connect_port,"MeleeClient",1))==OK,"Separate ENet process connects")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers complete lobby handshake")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0];game.start_game();game.context="pause";place();await create_timer(.4).timeout
  gate.mark.rpc_id(peer,"ready");check(await phase("attacked"),"Client sends one predicted melee command")
  var request:Dictionary=gate.marks.attacked;var shooter=game.actor_by_id(peer);var key=str(peer)+":"+str(request.id)
  check(await wait_for(func():return game.player.shield==0),"Server computes contact without a client-reported hit")
  var auth=game.shot_authorizations.get(key,{})
  check(not auth.is_empty() and auth.get("authoritative",false),"Melee authorization is server authoritative")
  if not auth.is_empty():check(game.player.last_damage>=float(auth.expires)-1+float(game.damage_rules.melee_windup_seconds)-.001,"Contact cannot occur before simulation windup")
  check(game.player.health==100 and game.player.alive,"Exactly one melee drains shields without duplicate body damage")
  gate.mark.rpc_id(peer,"hit");check(await phase("replayed"),"Client replays the same melee ID after authorization expiry")
  await create_timer(.5).timeout
  check(shooter.remote_melee_id==request.id and game.player.alive and game.player.health==100,"Late duplicate ID cannot start a second strike or damage again")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client starts predicted simulation")
  check(await phase("ready"),"Host places a supported close target");await create_timer(.2).timeout
  var p=game.player;var target=game.actor_by_id(1);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim();var before=game.event_sequence;p.melee();var id=game.event_sequence*16
  check(game.event_sequence==before+1 and p.action_state=="melee" and p.lunge_ticks>0,"Local animation/lunge starts immediately")
  check(target.shield==100,"Client does not invent local melee damage")
  # A forged early contact packet must not bypass host timing or geometry.
  game.report_hit.rpc_id(1,id,target.net_id,target.life_id,"head",1.,game.match_session,0.,game.now)
  gate.mark.rpc_id(1,"attacked",{"id":id})
  check(await phase("hit"),"Host confirms contact")
  check(await wait_for(func():return target.shield==0),"Authoritative shield change reaches shooter")
  await create_timer(1.15).timeout
  game.authorize_melee.rpc_id(1,id,p.life_id,game.round_number,game.match_session,game.command_sequence,Vector3.ZERO)
  gate.mark.rpc_id(1,"replayed");check(await phase("done"),"Host rejects the expired-authorization replay")
 var r={"role":role,"checks":checks,"failures":failures,"stats":game.net_stats};FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(r,"  "));print("NETWORK MELEE ",JSON.stringify(r));game.stop_game();game.close_connection();game.queue_free();await process_frame;quit(1 if failures else 0)
