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
var fire_audio=0
var last_shot={}
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+10000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(name):return await wait_for(func():return gate.marks.has(name))
func place():
 for a in game.actors:
  a.set_physics_process(false);a.global_position=Vector3(100,30,90 if a.net_id==1 else 100);a.rotation.y=0;a.eye.rotation.x=0;a.reset_physics_interpolation();a.reset_aim();a.update_visual(.016)
func invalid_shot(pos,id=-1):
 var p=game.player
 game.authorize_shot.rpc_id(1,game.next_event()*16 if id<0 else id,p.life_id,game.round_number,"rifle",pos,Vector3.FORWARD,game.match_session,0)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.team_size=1;game.mode=1;game.fair_playing_field=false;game.starting_primary="assault_rifle";game.starting_secondary="none"
 gate=Gate.new();gate.name="CombatAuthorityGate";game.add_child(gate)
 check((game.host_direct(17893,"TargetHost",0) if role=="host" else game.join_direct("127.0.0.1",17893,"ShooterClient",1))==OK,"Direct combat session opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join")
 if role=="host":
  game.start_game();game.context="pause";place()
  var shooter=game.actors.filter(func(a):return a.remote_peer>1)[0];var peer=shooter.remote_peer;var target=game.player
  check(await phase("first"),"Client sends first predicted shot")
  check(await wait_for(func():return target.shield==188),"Server ray applies exactly one rifle shield hit")
  check(shooter.ammo[0]==29,"Server consumes one round")
  gate.mark.rpc_id(peer,"first_ok")
  check(await phase("invalid"),"Replay and forged reports arrive")
  check(target.shield==188 and shooter.ammo[0]==29 and shooter.accepted_shots==1,"Replays, forged head contact, rapid fire and remote origin cannot apply extra damage or spend ammo")
  var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,3,.08);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=Vector3(100,31,99.7);await physics_frame
  gate.mark.rpc_id(peer,"wall_ready")
  check(await phase("wall"),"Client fires with barrel behind nearby cover")
  check(target.shield==188 and shooter.ammo[0]==28,"Host muzzle obstruction blocks damage while consuming valid ammunition")
  shooter.ammo[0]=0;gate.mark.rpc_id(peer,"empty_ready")
  check(await phase("empty"),"Empty fire attempt arrives")
  check(shooter.ammo[0]==0 and target.shield==188,"Server refuses empty-ammunition shots")
  gate.mark.rpc_id(peer,"reload_ready")
  check(await phase("reloading"),"Client requests reload and early fire")
  check(shooter.action_state=="reloading" and shooter.ammo[0]==0 and target.shield==188,"Server reload state rejects premature firing")
  wall.queue_free();await physics_frame;gate.mark.rpc_id(peer,"reload_wait")
  check(await phase("reloaded"),"Client reaches reload completion and fires")
  check(await wait_for(func():return target.shield==176),"Server confirms the post-reload hit")
  check(shooter.ammo[0]==29 and shooter.reserve[0]==130,"Reload transfers the correct magazine and reserve counts")
  check(game.shot_authorizations.values().map(func(a):return a.id).size()==3 and game.shot_authorizations.values().map(func(a):return a.id).all(func(id):return id>0 and id%16==0),"Accepted shots use canonical host damage IDs")
  gate.mark.rpc_id(peer,"done");await create_timer(.4).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters the match")
  place();await create_timer(.2).timeout
  var p=game.player;var target=game.actor_by_id(1);var offset=target.hitboxes[1].global_position-p.eye.global_position
  p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.apply_aim_rotation();p.cooldown=0
  p.shot_fired.connect(func(id,_t,origin,directions):last_shot={"id":id,"origin":origin,"direction":directions[0]})
  game.audio.sound_started.connect(func(id,_file,_voice):
   if id=="assault_rifle_fire_crack":fire_audio+=1)
  check(p.fire_trigger() and p.ammo[0]==29 and p.aim_punch.y>0,"Client fires and recoils without waiting for an acknowledgement")
  check(target.shield==200 and game.hit_until==0,"Predicted feedback cannot change target protection or confirm damage")
  gate.mark.rpc_id(1,"first");check(await phase("first_ok"),"Authority confirms first shot")
  check(await wait_for(func():return target.shield==188 and game.hit_until>0),"Confirmed damage and hit response reach the shooter")
  check(fire_audio==1,"Authoritative cosmetic echo does not replay predicted firing sound")
  invalid_shot(last_shot.origin,last_shot.id)
  game.report_hit.rpc_id(1,last_shot.id,target.net_id,target.life_id,"head",1.0,game.match_session,1.0)
  invalid_shot(Vector3(500,30,100));invalid_shot(Vector3(500,30,100))
  await create_timer(.2).timeout;gate.mark.rpc_id(1,"invalid")
  check(await phase("wall_ready"),"Host prepares a nearby muzzle wall")
  invalid_shot(Vector3(100.24,31.47,99.45));await create_timer(.2).timeout;gate.mark.rpc_id(1,"wall")
  check(await phase("empty_ready") and await wait_for(func():return p.ammo[0]==0),"Empty authoritative ammo state reaches client")
  invalid_shot(p.eye.global_position);await create_timer(.1).timeout;gate.mark.rpc_id(1,"empty")
  check(await phase("reload_ready"),"Host is ready for reload validation")
  p.reload_weapon();invalid_shot(p.eye.global_position);await create_timer(.1).timeout;gate.mark.rpc_id(1,"reloading")
  check(await phase("reload_wait"),"Server maintains the reload deadline")
  check(await wait_for(func():return game.now>=p.action_until),"Simulation reaches reload completion")
  p.advance_weapon_timers();p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.apply_aim_rotation();p.cooldown=0;p.fire_trigger();gate.mark.rpc_id(1,"reloaded")
  check(await phase("done"),"Host completes its damage and ammunition checks")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("COMBAT AUTHORITY "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
