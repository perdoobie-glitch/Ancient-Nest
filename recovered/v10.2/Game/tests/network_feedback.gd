extends SceneTree
class Gate:
	extends Node
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(phase: String): marks[phase]=multiplayer.get_remote_sender_id()
var game
var gate: Gate
var role=""
var checks=0
var failures=0
var blasts_seen=0
func _initialize(): call_deferred("run")
func check(ok: bool, description: String):
	checks+=1
	if ok: print("PASS "+role+": "+description)
	else: failures+=1; push_error("FAIL "+role+": "+description)
func wait_mark(phase: String, peer: int) -> bool:
	var until=Time.get_ticks_msec()+12000
	while gate.marks.get(phase,0)!=peer and Time.get_ticks_msec()<until: await process_frame
	return gate.marks.get(phase,0)==peer
func wait_state(predicate: Callable) -> bool:
	var until=Time.get_ticks_msec()+4000
	while not predicate.call() and Time.get_ticks_msec()<until and game.network_active: await process_frame
	return predicate.call()
func run():
	role="host" if "host" in OS.get_cmdline_user_args() else "client"
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.team_size=1; game.mode=0
	gate=Gate.new(); gate.name="FeedbackGate"; game.add_child(gate)
	var error=game.host_direct(17881,"FeedbackHost",0) if role=="host" else game.join_direct("127.0.0.1",17881,"FeedbackClient",1)
	check(error==OK,"Direct feedback test session opens")
	var until=Time.get_ticks_msec()+20000
	while game.lobby_members.size()!=2 and Time.get_ticks_msec()<until: await process_frame
	check(game.lobby_members.size()==2,"Both feedback peers connect")
	if game.lobby_members.size()==2:
		if role=="host": await host_run()
		else: await client_run()
	print("NETWORK FEEDBACK "+role+": %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(.3).timeout; quit(1 if failures else 0)
func host_run():
	game.start_game(); game.context="pause"
	var remote: NestActor
	for actor in game.actors:
		actor.global_position=Vector3(-13 if actor.local_player else 13,7.05,-17); actor.reset_physics_interpolation()
		if not actor.local_player: remote=actor
	var peer=remote.remote_peer
	if not await wait_mark("ready",peer): check(false,"Client is ready for feedback"); return
	game.player.flash_until=game.now+.15
	game.player.take_damage(12,"torso","bullet",false,remote,81001)
	gate.mark.rpc_id(peer,"hit")
	if not await wait_mark("hit_seen",peer): check(false,"Client acknowledges energy impact"); return
	game.player.take_damage(100,"torso","bullet",false,null,81002)
	game.player.take_damage(5,"torso","bullet",false,null,81003)
	game.objective_blast.rpc(0,game.match_session,game.round_number)
	gate.mark.rpc_id(peer,"break")
	if not await wait_mark("break_seen",peer): check(false,"Client acknowledges break"); return
	remote.overshield=10; remote.over_deadline=game.now+10
	remote.take_damage(10,"torso","bullet",false,null,81004)
	game.site_states[0].stage="drilling"
	gate.mark.rpc_id(peer,"over")
	if not await wait_mark("over_seen",peer): check(false,"Client acknowledges its own bonus shield"); return
	game.player.respawn()
	gate.mark.rpc_id(peer,"respawn")
	if not await wait_mark("reload",peer): check(false,"Client reload begins"); return
	await create_timer(.15).timeout
	check(remote.action_state=="reloading","Host sees remote reload state")
	check(remote.flash_until>0,"Host records remote shooting flash")
	check(remote.weapons[0].kind=="ak47" and remote.ammo[0]==remote.weapons[0].magazine-1,"Remote AK-47 shooting spends exactly one authoritative round")
	gate.mark.rpc_id(peer,"reload_seen")
	if not await wait_mark("correction_ready",peer): check(false,"Client starts correction measurement"); return
	remote.global_position.x+=.5
	gate.mark.rpc_id(peer,"correction")
	if not await wait_mark("done",peer): check(false,"Client completes movement measurement"); return
	check(game.player.damage_fx_seq==0,"New life resets authoritative visual event sequence")
	gate.mark.rpc_id(peer,"finished")
	await create_timer(.3).timeout
func client_run():
	var until=Time.get_ticks_msec()+20000
	while not game.running and Time.get_ticks_msec()<until: await process_frame
	check(game.running,"Client receives the match")
	if not game.running: return
	await create_timer(.5).timeout
	var host=game.actor_by_id(1)
	var initial_life=host.life_id
	game.effects.child_entered_tree.connect(func(node):
		if node is NestBlastFX: blasts_seen+=1
	)
	# v0.11: the host drops this actor onto a ledge. With prediction the owner
	# lands before the host does, so compare eyes only once both are at rest.
	await wait_state(func(): return game.player.is_on_floor() and game.player.velocity.length()<.01)
	await create_timer(.4).timeout
	gate.mark.rpc_id(1,"ready")
	await wait_mark("hit",1); await wait_state(func(): return host.damage_fx_seq==1)
	check(host.damage_fx_seq==1 and host.shield_flash_strength>0 and host.shield_flash_at>0,"Remote energy hit arrives through snapshots")
	check(host.directional_hits.size()==1 and Vector3(host.directional_hits[0].x,host.directional_hits[0].y,host.directional_hits[0].z).distance_to(game.player.eye.global_position)<.1,"Snapshots preserve the actual incoming damage direction")
	check(host.flash_until>0,"Remote muzzle flash timestamp arrives through snapshots")
	var timestamp=host.shield_flash_at
	await create_timer(.2).timeout
	check(host.shield_flash_at==timestamp,"Repeated snapshots do not restart hit shimmer")
	gate.mark.rpc_id(1,"hit_seen")
	await wait_mark("break",1); await wait_state(func(): return host.damage_fx_seq==3 and blasts_seen>0)
	check(host.damage_fx_seq==3 and host.shield==0 and host.shield_break_at>0 and host.health_flash_at>0,"Coalesced snapshots preserve shield break and subsequent health hit")
	check(blasts_seen==1,"Reliable objective detonation reaches the client")
	gate.mark.rpc_id(1,"break_seen")
	await wait_mark("over",1); await wait_state(func(): return game.player.shield_flash_over and game.arena.deposits[0].get_node("Opened/DrillAnimation").active)
	check(game.player.shield_flash_over and game.player.shield_break_at>0,"Owner receives actual overshield-break feedback")
	check(game.arena.deposits[0].get_node("Opened/DrillAnimation").active,"Working drill state reaches the client and activates its animation")
	gate.mark.rpc_id(1,"over_seen")
	await wait_mark("respawn",1); await wait_state(func(): return host.life_id>initial_life)
	check(host.damage_fx_seq==0 and host.shield_flash_at<0 and host.shield_break_at<0,"Remote respawn clears prior-life effects")
	game.player.rotation.y=0; game.player.eye.rotation.x=0; game.player.fire_trigger(); game.player.reload_weapon()
	gate.mark.rpc_id(1,"reload")
	await wait_mark("reload_seen",1)
	await wait_state(func(): return game.player.action_state=="reloading" and game.player.presentation.reload_progress()>0)
	check(game.player.action_state=="reloading" and game.player.presentation.reload_progress()>0,"Owner reload animation follows the authoritative timer")
	var start=game.player.global_position; var largest=0.0
	# v0.11: reconciliation moves the simulated body exactly and the camera
	# absorbs the shift, so the view the player sees is what must not snap.
	var positions: Array[Vector3]=[game.player.camera.global_position]
	var sample=func(): positions.append(game.player.camera.global_position)
	process_frame.connect(sample)
	gate.mark.rpc_id(1,"correction_ready")
	await wait_mark("correction",1)
	for i in range(60):
		await physics_frame
	process_frame.disconnect(sample)
	for i in range(1,positions.size()): largest=maxf(largest,positions[i].distance_to(positions[i-1]))
	check(game.player.global_position.x-start.x>.35,"Gradual owner correction converges to host position")
	check(largest<.15,"Small network corrections do not snap the owner view")
	gate.mark.rpc_id(1,"done"); await wait_mark("finished",1)
