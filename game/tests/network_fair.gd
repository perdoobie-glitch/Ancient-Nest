extends SceneTree
class Gate:
	extends Node
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(key: String): marks[key]=true
var game
var gate: Gate
var role: String
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS "+role+": "+message)
	else: failures+=1; push_error("FAIL "+role+": "+message)
func phase(key: String) -> bool:
	var until=Time.get_ticks_msec()+15000
	while not gate.marks.has(key) and Time.get_ticks_msec()<until: await process_frame
	return gate.marks.has(key)
func ready_wait(predicate: Callable) -> bool:
	var until=Time.get_ticks_msec()+10000
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func place_players():
	for actor in game.actors:
		actor.set_physics_process(false); actor.global_position=Vector3(80,25,70 if actor.net_id==1 else 80); actor.velocity=Vector3.ZERO; actor.controlled=Vector3.ZERO; actor.external=Vector3.ZERO; actor.reset_physics_interpolation(); actor.update_visual(.016)
func run():
	role="host" if "host" in OS.get_cmdline_user_args() else "client"
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.team_size=1; game.mode=2
	gate=Gate.new(); gate.name="FairGate"; game.add_child(gate)
	var error=game.host_direct(17884,"FairHost",0) if role=="host" else game.join_direct("127.0.0.1",17884,"FairClient",1)
	check(error==OK,"Direct session opens")
	check(await ready_wait(func(): return game.lobby_members.size()==2),"Both peers join")
	if game.lobby_members.size()==2:
		if role=="host": await host_run()
		else: await client_run()
	print("NETWORK FAIR "+role+": %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(.75).timeout; quit(1 if failures else 0)
func host_run():
	game.bot_difficulty="hard"; game.fair_playing_field=true; game.fair_health_type="naki"; game.starting_primary="battle_rifle_scoped"; game.starting_secondary="ak47"; game.start_game(); game.context="pause"; place_players()
	var remote=game.actors.filter(func(actor):return actor.remote_peer>1)[0]
	remote.weapons[0]=remote.weapons[0].duplicate();remote.weapons[0].spread_degrees=0 # Isolate faction damage from random spread on the authority.
	var remote_id=remote.remote_peer
	check(remote.damage_model()=="naki" and game.player.damage_model()=="naki","Host gives both factions Naki shields")
	check(remote.weapons[0].kind=="burst_scoped" and remote.weapons[1].kind=="ak47","Host owns the requested starting loadout")
	if not await phase("ready_naki"): check(false,"Client acknowledges Naki config"); return
	if not await phase("burst_sent"): check(false,"Client sends four-round burst"); return
	print("FAIR BURST HOST ammo=",remote.ammo," shield=",game.player.shield," health=",game.player.health," clocks=",game.remote_shot_clocks)
	check(remote.ammo[0]==32,"Four scoped burst rounds consume authoritative ammo")
	check(game.player.shield==120 and game.player.health==100,"Remote scoped burst strips exactly eighty shield at close range")
	game.player.take_damage(120,"torso","bullet",false,null,game.next_event())
	check(game.player.body_phase and game.player.shield==0,"Authority enters body phase on shield break")
	gate.mark.rpc_id(remote.remote_peer,"broken")
	if not await phase("break_received"): check(false,"Client receives shield break state and audio"); return
	game.stop_game(); gate.mark.rpc_id(remote.remote_peer,"stopped")
	if not await phase("restart_ready"): check(false,"Client ready to restart"); return
	game.fair_health_type="annu"; game.starting_primary="none"; game.starting_secondary="magnum"; game.start_game(); game.context="pause"; place_players()
	check(game.actors.all(func(actor): return actor.damage_model()=="annu" and actor.shield==0 and actor.armor==100),"Restart applies Annu health/armor to both factions")
	if not await phase("annu_received"): check(false,"Client receives Annu restart"); return
	var new_remote=game.actor_by_id(remote_id)
	game.pad_stock[0]=1; game.take_pickup(new_remote,0)
	gate.mark.rpc_id(remote_id,"sniper_ready")
	if not await phase("sniper_sent"): check(false,"Client sends sniper headshot"); return
	check(not game.player.alive and game.player.health==0,"Remote sniper headshot kills through full Annu armor and helmet")
	check(new_remote.ammo[new_remote.slot]==3,"Authority owns the sniper's spent round")
	gate.mark.rpc_id(remote_id,"finished"); await create_timer(.3).timeout
func client_run():
	check(await ready_wait(func():return game.running),"Client receives match")
	if not game.running: return
	check(await ready_wait(func():return game.player.global_position.distance_to(Vector3(80,25,80))<1),"Client receives the prepared arena positions")
	game.player.set_physics_process(false); game.context="playing"
	check(game.bot_difficulty=="hard" and game.fair_playing_field and game.fair_health_type=="naki" and game.actors.all(func(actor):return actor.damage_model()=="naki"),"Shared Naki setting is replicated to client")
	check(game.player.weapons[0].kind=="burst_scoped" and game.player.weapons[1].kind=="ak47","Starting weapons are replicated to client")
	var target=game.actor_by_id(1); var actor=game.player
	check(await ready_wait(func(): return target.global_position.distance_to(Vector3(80,25,70))<.1),"Remote target interpolation reaches the prepared pose")
	target.set_physics_process(false); target.global_position=target.net_target_pos; target.reset_physics_interpolation(); target.update_visual(.016)
	actor.weapons[0]=actor.weapons[0].duplicate();actor.weapons[0].spread_degrees=0
	actor.set_process(false); actor.camera.global_position=actor.eye.global_position
	gate.mark.rpc_id(1,"ready_naki")
	for index in range(4):
		actor.accuracy_penalty=-float(NestWeaponCatalog.definition("battle_rifle").spread_base_deg); actor.aim_punch=Vector2.ZERO
		var offset=target.hitboxes[0].global_position-actor.camera.global_position
		actor.rotation.y=atan2(-offset.x,-offset.z); actor.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length()); actor.apply_aim_rotation()
		if index==0: actor.fire_trigger()
		else:
			actor.shoot_round(); actor.burst_left-=1
		await create_timer(.12).timeout
		print("FAIR BURST CLIENT round=",index," ammo=",actor.ammo," action=",actor.action_state," now=",game.now)
	gate.mark.rpc_id(1,"burst_sent")
	var break_cues=0
	game.audio.sound_started.connect(func(id,_file,_voice):
		if id=="naki_shield_break": gate.marks["break_audio"]=true)
	if not await phase("broken"): check(false,"Host confirms body phase"); return
	check(await ready_wait(func():return target.body_phase and target.shield==0),"Body phase is replicated in snapshots")
	target.update_visual(.016)
	check(not gate.marks.has("break_audio") and target.presentation.hit_electricity.pulse_count>0,"Distant shield break has electrical feedback without contact noise")
	gate.mark.rpc_id(1,"break_received")
	await phase("stopped"); check(await ready_wait(func():return not game.running),"Client closes old match before restarting")
	gate.mark.rpc_id(1,"restart_ready")
	check(await ready_wait(func():return game.running and game.fair_health_type=="annu"),"Client receives new shared Annu config")
	check(game.actors.all(func(item):return item.damage_model()=="annu" and item.shield==0 and item.armor==100),"All client actors use Annu protection after restart")
	check(game.player.weapons.size()==1 and game.player.weapons[0].kind=="sidearm","None primary leaves only the configured Magnum secondary")
	check(await ready_wait(func(): return game.protection_bars.size()==2 and game.hud_protection.text.contains("HEALTH")),"Client HUD follows the shared Annu health type")
	gate.mark.rpc_id(1,"annu_received"); await phase("sniper_ready")
	check(await ready_wait(func():return game.player.weapons.size()==2 and game.player.weapons[game.player.slot].kind=="sniper"),"Client receives the authoritative sniper pickup")
	actor=game.player; target=game.actor_by_id(1)
	await ready_wait(func():return target.global_position.distance_to(Vector3(80,25,70))<.1)
	target.set_physics_process(false); target.global_position=target.net_target_pos; target.update_visual(.016)
	actor.set_physics_process(false); actor.set_process(false); actor.camera.global_position=actor.eye.global_position; actor.accuracy_penalty=-.05; actor.aim_punch=Vector2.ZERO
	var offset=target.hitboxes[0].global_position-actor.camera.global_position
	actor.rotation.y=atan2(-offset.x,-offset.z); actor.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length()); actor.apply_aim_rotation(); actor.fire_trigger()
	check(await ready_wait(func():return not target.alive and actor.ammo[actor.slot]==3),"Client sees sniper headshot elimination and correct ammo")
	gate.mark.rpc_id(1,"sniper_sent"); await phase("finished")
