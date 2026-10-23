extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String,data: Variant=true):marks[key]=data
var game
var gate
var role="host"
var checks=0
var failures=0
var events=[]
var bullets=[]
var shots=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var until=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<until:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for actor in game.actors:
  actor.set_physics_process(false);actor.set_process(false);actor.global_position=Vector3(500,50,490 if actor.net_id==1 else 500);actor.rotation.y=0;actor.eye.rotation.x=0;actor.reset_physics_interpolation();actor.reset_aim();actor.update_visual(.016)
func equip(actor,kind):
 actor.weapons.assign([NestWeaponCatalog.profile(kind)]);actor.ammo.assign([30]);actor.reserve.assign([100]);actor.slot=0;actor.action_state="ready";actor.burst_left=0;actor.cooldown=0;actor.reset_aim()
func aim(actor,target):
 var offset=target-actor.eye.global_position;actor.rotation.y=atan2(-offset.x,-offset.z);actor.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());actor.apply_aim_rotation()
func run():
 role="client" if "client" in OS.get_cmdline_user_args() else "host"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.team_size=1;game.mode=1;game.starting_primary="assault_rifle";game.starting_secondary="none"
 gate=Gate.new();gate.name="AnatomyGate";game.add_child(gate)
 game.audio.playback_enabled=true;game.audio.sound_started.connect(func(id,_file,_voice):events.append(id))
 check((game.host_direct(17966,"AnatomyHost",0) if role=="host" else game.join_direct("127.0.0.1",17966,"AnatomyClient",1))==OK,"ENet loopback session opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both separate processes join")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  game.start_game();place();game.player.shield=100
  var shooter=game.actor_by_id(peer);equip(shooter,"rifle")
  game.effects.child_entered_tree.connect(func(node):
   if node.get_script()!=null and node.get_script().resource_path=="res://scripts/bullet.gd":bullets.append(node.direction))
  gate.mark.rpc_id(peer,"placed")
  check(await phase("rifle"),"Client sends a predicted fixed-spread shot")
  check(await wait_for(func():return game.player.shield==88),"Host ray applies one authoritative rifle hit")
  var shot:Dictionary=gate.marks.rifle
  check(bullets.size()==1 and bullets[0].distance_to(shot.direction)<.00001,"Server rolled spread and client predicted direction match for the same shot ID")
  gate.mark.rpc_id(peer,"rifle_ok")
  check(await phase("replay"),"Duplicate shot arrives")
  await create_timer(.05).timeout
  check(shooter.ammo[0]==29 and game.player.shield==88 and shooter.accepted_shots==1,"Duplicate shot ID cannot consume ammunition or repeat damage")
  for i in range(5):
   game.player.respawn();place();game.player.shield=0;equip(shooter,"ak47");await create_timer(.15).timeout;await physics_frame
   gate.mark.rpc_id(peer,"ready"+str(i))
   check(await phase("shot"+str(i)),"Client submits headshot %d"%(i+1))
   check(await wait_for(func():return not game.player.alive),"Curved helmet accepts server-confirmed finishing headshot %d"%(i+1))
   gate.mark.rpc_id(peer,"dead"+str(i))
  check(await phase("client_spree"),"Remote player receives its own streak voice")
  check(int(game.announcer.streaks.get(shooter.net_id,0))==5 and events.count("announcer_killing_spree")==0,"Server counts five client kills; host hears no remote spree")
  # Confirmed host kills of a simulated bot exercise the host-private route too.
  var bot=NestActor.new();bot.game=game;bot.faction=1;bot.net_id=-1;game.add_child(bot);bot.set_physics_process(false);bot.set_process(false)
  for i in range(5):
   game.announcer.current="";game.announcer.queue.clear();game.audio.stop_all();game.announcer.clock+=5;bot.respawn();bot.die(game.player,"headshot")
  check(events.count("announcer_killing_spree")==1,"Host hears its own five-kill spree once")
  bot.queue_free();gate.mark.rpc_id(peer,"host_spree")
  check(await phase("done"),"Client verifies private routing")
  gate.mark.rpc_id(peer,"finish");await create_timer(.2).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters the match")
  check(await phase("placed"),"Host establishes identical fixture");place();await physics_frame
  var p=game.player;var target=game.actor_by_id(1);equip(p,"rifle");aim(p,target.hitboxes[1].global_position)
  p.shot_fired.connect(func(id,_time,origin,directions):shots.append({"id":id,"origin":origin,"direction":directions[0],"raw":p.aim_direction()}))
  check(p.hitboxes.size()==17 and target.hitboxes.size()==17,"Both peers load the same anatomical hit regions")
  check(p.fire_trigger() and target.shield==100,"Client predicts feedback without inventing damage")
  gate.mark.rpc_id(1,"rifle",shots[0]);check(await phase("rifle_ok"),"Host confirms the spread ray")
  game.authorize_shot.rpc_id(1,shots[0].id,p.life_id,game.round_number,"rifle",shots[0].origin,shots[0].raw,game.match_session,0)
  gate.mark.rpc_id(1,"replay")
  events.clear()
  for i in range(5):
   check(await phase("ready"+str(i)),"Host prepares unshielded target %d"%(i+1));place();equip(p,"ak47");aim(p,target.hitboxes[0].global_position);await physics_frame
   check(p.fire_trigger(),"Client immediately fires headshot %d"%(i+1));gate.mark.rpc_id(1,"shot"+str(i))
   check(await phase("dead"+str(i)),"Server confirms target death %d"%(i+1))
  check(await wait_for(func():return events.count("announcer_killing_spree")==1),"Five own kills play the supplied voice once on the client")
  gate.mark.rpc_id(1,"client_spree");check(await phase("host_spree"),"Host earns a separate spree")
  await create_timer(.2).timeout
  check(events.count("announcer_killing_spree")==1,"Host spree does not play on the other player's client")
  gate.mark.rpc_id(1,"done");check(await phase("finish"),"Both processes finish")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.3).timeout
 print("NETWORK ANATOMY "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
