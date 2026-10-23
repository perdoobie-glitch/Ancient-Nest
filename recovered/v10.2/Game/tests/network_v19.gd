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
var last_shot={}
var fire_sounds=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+12000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(name):return await wait_for(func():return gate.marks.has(name))
func place():
 for a in game.actors:
  a.set_physics_process(false);a.global_position=Vector3(200,30,190 if a.net_id==1 else 200);a.rotation.y=0;a.eye.rotation.x=0;a.reset_physics_interpolation();a.reset_aim();a.update_visual(.016)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.team_size=1;game.mode=1;game.fair_playing_field=true;game.fair_health_type="naki";game.starting_primary="plasma_auto";game.starting_secondary="plasma_br"
 gate=Gate.new();gate.name="V19Gate";game.add_child(gate)
 check((game.host_direct(17919,"V19Host",0) if role=="host" else game.join_direct("127.0.0.1",17919,"V19Client",1))==OK,"Direct ENet session opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both real peer processes join")
 if role=="host":
  game.start_game();game.context="pause";place()
  var shooter=game.actors.filter(func(a):return a.remote_peer>1)[0];var peer=shooter.remote_peer;var target=game.player
  for kind in ["plasma_auto","plasma_br"]:
   var before=target.shield;var ammo=shooter.ammo[shooter.slot]
   gate.mark.rpc_id(peer,kind+"_ready")
   check(await phase(kind+"_sent"),kind+" arrives from client")
   var damage=float(NestWeaponCatalog.for_kind(kind).damage_shield)/1.7
   check(await wait_for(func():return target.shield<before),kind+" server projectile reaches target")
   check(absf(before-target.shield-damage)<.01 and shooter.ammo[shooter.slot]==ammo-1,kind+" applies one authoritative hit and consumes one round")
   gate.mark.rpc_id(peer,kind+"_hit")
   check(await phase(kind+"_replayed"),kind+" replay test arrives")
   check(absf(before-target.shield-damage)<.01 and shooter.ammo[shooter.slot]==ammo-1,kind+" duplicate shot ID cannot add damage or spend ammunition")
   if kind=="plasma_auto":
    shooter.slot=1;shooter.action_state="ready";shooter.action_until=0;shooter.cooldown=0;shooter.burst_left=0;game.remote_shot_clocks.erase(peer)
  gate.mark.rpc_id(peer,"done");await create_timer(.4).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters v19 map")
  place();var p=game.player;var target=game.actor_by_id(1)
  p.shot_fired.connect(func(id,_t,origin,directions):last_shot={"id":id,"origin":origin,"direction":directions[0]})
  game.audio.sound_started.connect(func(id,_file,_voice):
   if String(id).begins_with("weapon_profile_") and not String(id).ends_with("_distant"):fire_sounds+=1)
  for kind in ["plasma_auto","plasma_br"]:
   check(await phase(kind+"_ready") and await wait_for(func():return p.weapons[p.slot].kind==kind),kind+" loadout state reaches client")
   var offset=target.hitboxes[1].global_position-p.eye.global_position;p.rotation.y=atan2(-offset.x,-offset.z);p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.reset_aim();p.cooldown=0;p.action_state="ready";p.burst_left=0
   var before=target.shield;var sounds=fire_sounds
   check(p.fire_trigger(),kind+" gives immediate predicted feedback")
   p.burst_left=0 # This fixture measures one bolt; burst timing has its own check.
   check(target.shield==before,kind+" prediction cannot apply client damage")
   gate.mark.rpc_id(1,kind+"_sent");check(await phase(kind+"_hit"),kind+" host confirms contact")
   check(await wait_for(func():return target.shield<before),kind+" authoritative damage reaches client")
   check(fire_sounds==sounds+1,kind+" authority echo does not duplicate firing sound")
   game.authorize_shot.rpc_id(1,last_shot.id,p.life_id,game.round_number,kind,last_shot.origin,last_shot.direction,game.match_session,0)
   await create_timer(.25).timeout;gate.mark.rpc_id(1,kind+"_replayed")
  check(await phase("done"),"Host finishes both plasma cases")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("V19 NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
