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
var sounds=[]
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
 for a in game.actors:a.set_physics_process(false);a.global_position=game.arena.sites[0]+Vector3(0,0,1 if a.remote_peer>1 else -1);a.rotation.y=0;a.eye.rotation.x=0;a.reset_physics_interpolation();a.reset_aim();a.update_visual(.016)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.team_size=1;game.mode=0;game.starting_primary="plasma_auto";game.starting_secondary="plasma_br";game.tuning.bomb_fuse=40
 game.audio.sound_started.connect(func(id,_file,_voice):sounds.append(id))
 gate=Gate.new();gate.name="UpdateGate";game.add_child(gate)
 check((game.host_direct(17920,"V20Host",0) if role=="host" else game.join_direct("127.0.0.1",17920,"V20Client",1))==OK,"Real ENet peer opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join update protocol")
 if role=="host":
  game.start_game();game.context="pause";place();var remote=game.actors.filter(func(a):return a.remote_peer>1)[0];var peer=remote.remote_peer
  remote.ammo[0]=1;remote.reserve[0]=10
  gate.mark.rpc_id(peer,"auto_ready")
  check(await wait_for(func():return remote.ammo[0]==0),"Server accepts the final magazine round")
  check(await wait_for(func():remote.advance_weapon_timers();return remote.action_state=="reloading"),"Server automatically reloads an empty remote weapon")
  check(await wait_for(func():remote.advance_weapon_timers();return remote.ammo[0]==10 and remote.action_state=="ready"),"Server completes one automatic reload from reserve")
  check(remote.reserve[0]==0,"Authoritative automatic reload consumes reserve exactly once")
  gate.mark.rpc_id(peer,"ready")
  check(await wait_for(func():return remote.action_state=="throwing"),"Client throw-begin arrives")
  check(remote.throw_kind==1 and remote.throw_started>0,"Server records throw animation kind and simulation timestamp")
  remote.presentation.pose_upper_body();check(remote.presentation.remote_grenade.visible,"Host sees held sticky before release")
  check(await wait_for(func():return remote.grenades[1]==1),"Server accepts exactly one client grenade release")
  var amount=game.effects.get_children().filter(func(n):return n is RigidBody3D).size();check(amount==1,"One server grenade exists; prediction cannot duplicate it")
  gate.mark.rpc_id(peer,"released");check(await phase("client_grenade_ok"),"Client confirms single predicted grenade")
  remote.action_state="ready";remote.action_until=0;game.player.carrying=false
  var choice=game.interaction_for(game.player);check(choice.key=="plant:0" and game.complete_interaction(game.player,choice),"Host plants authoritative bomb")
  check(sounds.count("bomb_planted_alert")==1,"Host hears one planted cue")
  gate.mark.rpc_id(peer,"planted")
  check(await wait_for(func():return remote.cmd_queue.size()>0),"Client use input reaches sequenced command queue")
  remote.process_remote_commands(1.0/60);remote.global_position=game.arena.sites[0]+Vector3(0,0,1);remote.net_last_command=game.now
  check(remote.net_interact,"Server processes actual client use command")
  game.update_remote_interaction(remote,.1);check(sounds.count("bomb_defuse_start")==1,"Host hears defuse-start once")
  var ammo=remote.ammo[remote.slot];gate.mark.rpc_id(peer,"defusing")
  check(await phase("attack_attempt"),"Forged fire attempt arrives during defuse")
  await create_timer(.2).timeout
  check(remote.ammo[remote.slot]==ammo and game.net_stats.get("shots_rejected_state",0)>0,"Server rejects shot while defusing without spending ammo")
  game.remote_interactions[peer].time=0.0;remote.net_last_command=game.now;game.update_remote_interaction(remote,5.99);check(game.break_until==0,"Defuse has not completed before six seconds of use")
  remote.net_last_command=game.now;game.update_remote_interaction(remote,.02);check(game.break_until>game.now,"Defuse completes after six seconds")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters match");place();game.context="pause";var p=game.player
  check(await phase("auto_ready") and await wait_for(func():return p.ammo[0]==1),"Client receives last-round ammunition state")
  check(p.fire_trigger(),"Client fires the last round promptly")
  check(await wait_for(func():p.advance_weapon_timers();return p.action_state=="reloading"),"Client shows automatic reload")
  check(await wait_for(func():return p.ammo[0]==10 and p.action_state=="ready"),"Reloaded ammunition reaches client")
  check(await phase("ready"),"Host is ready")
  p.grenade_kind=1;p.throw_grenade();p.presentation.update_view_weapon(0);check(p.presentation.view_grenade.visible,"Local throw has immediate visible grenade")
  check(await wait_for(func():return game.now>=p.throw_release),"Client reaches simulation-time release boundary");p.advance_weapon_timers()
  check(p.grenades[1]==1,"Local release consumes one grenade")
  check(await phase("released"),"Host confirms grenade")
  check(game.effects.get_children().filter(func(n):return n is RigidBody3D).size()==1,"Server echo does not create second local grenade")
  gate.mark.rpc_id(1,"client_grenade_ok")
  check(await phase("planted") and await wait_for(func():return game.site_states[0].stage=="planted"),"Planted state reaches client")
  check(sounds.count("bomb_planted_alert")==1,"Client hears one global planted cue")
  p.record_client_command(Vector2.ZERO,false,-1,true,0)
  check(await phase("defusing") and await wait_for(func():return sounds.count("bomb_defuse_start")==1),"Client hears global defuse-start cue")
  var id=game.next_event()*16;game.authorize_shot.rpc_id(1,id,p.life_id,game.round_number,p.weapons[p.slot].kind,p.eye.global_position,Vector3.FORWARD,game.match_session,0)
  gate.mark.rpc_id(1,"attack_attempt")
  check(await phase("done"),"Host validates complete defuse scenario")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout;print("V20 UPDATE NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
