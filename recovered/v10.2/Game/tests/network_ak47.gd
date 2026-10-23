extends SceneTree
class Gate:
	extends Node
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(phase: String): marks[phase]=true
var game
var gate: Gate
var role=""
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS "+role+": "+message)
	else: failures+=1; push_error("FAIL "+role+": "+message)
func phase(name: String) -> bool:
	var until=Time.get_ticks_msec()+12000
	while not gate.marks.has(name) and Time.get_ticks_msec()<until: await process_frame
	return gate.marks.has(name)
func run():
	role="host" if "host" in OS.get_cmdline_user_args() else "client"
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.lobby_network.set_process(false);game.lobby_network=null; await process_frame
	game.bot_fill=false; game.team_size=1; game.mode=2
	gate=Gate.new(); gate.name="AKGate"; game.add_child(gate)
	var error=game.host_direct(17882,"AKTarget",0) if role=="host" else game.join_direct("127.0.0.1",17882,"AKShooter",1)
	check(error==OK,"AK direct session opens")
	var until=Time.get_ticks_msec()+15000
	while game.lobby_members.size()!=2 and Time.get_ticks_msec()<until: await process_frame
	check(game.lobby_members.size()==2,"AK peers join")
	if game.lobby_members.size()==2:
		if role=="host": await host_run()
		else: await client_run()
	print("NETWORK AK47 "+role+": %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(.3).timeout; quit(1 if failures else 0)
func host_run():
	game.start_game(); game.context="pause"
	var remote
	for actor in game.actors:
		actor.global_position=Vector3(80,25,70 if actor.local_player else 80); actor.reset_physics_interpolation(); actor.set_physics_process(false); actor.update_visual(.016)
		if not actor.local_player: remote=actor
	if not await phase("ready"): check(false,"Client ready for AK shots"); return
	for shot in range(1,4):
		if not await phase("shot"+str(shot)): check(false,"Client reports shot"); return
		check((game.player.shield==50 and game.player.alive) if shot==1 else (game.player.shield==0 and game.player.alive) if shot==2 else not game.player.alive,"Authoritative AK headshot %d has the correct Naki outcome"%shot)
		gate.mark.rpc_id(remote.remote_peer,"checked"+str(shot))
	check(remote.weapons[0].kind=="ak47" and remote.ammo[0]==27,"Host owns the starting AK and three spent rounds")
	await phase("done"); gate.mark.rpc_id(remote.remote_peer,"finished"); await create_timer(.3).timeout
func client_run():
	var until=Time.get_ticks_msec()+15000
	while not game.running and Time.get_ticks_msec()<until: await process_frame
	check(game.running,"Client receives the AK match")
	if not game.running: return
	await create_timer(.5).timeout
	var shooter=game.player; var target=game.actor_by_id(1); shooter.set_physics_process(false); game.context="playing"
	check(shooter.weapons[0].kind=="ak47" and shooter.ammo[0]==30,"Client starts with the authoritative AK loadout")
	gate.mark.rpc_id(1,"ready")
	for shot in range(1,4):
		shooter.aim_punch=Vector2.ZERO; shooter.reset_physics_interpolation()
		var difference=target.hitboxes[0].global_position-shooter.camera.global_position
		shooter.rotation.y=atan2(-difference.x,-difference.z); shooter.eye.rotation.x=atan2(difference.y,Vector2(difference.x,difference.z).length()); shooter.apply_aim_rotation()
		shooter.fire_trigger(); await create_timer(.22).timeout
		gate.mark.rpc_id(1,"shot"+str(shot)); await phase("checked"+str(shot))
	check(not target.alive and target.health==0 and shooter.ammo[0]==27,"Owner-view AK reports produce the third-headshot kill and correct ammo")
	gate.mark.rpc_id(1,"done"); await phase("finished")
