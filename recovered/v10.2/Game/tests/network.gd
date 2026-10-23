extends SceneTree
var game
var role: String
var began: bool=false
var elapsed: float=0
var checks: int=0
var failures: int=0
func _initialize(): call_deferred("run")
func check(condition: bool, message: String):
	checks+=1
	if condition: print("PASS "+role+": "+message)
	else: failures+=1; push_error("FAIL "+role+": "+message)
func run():
	role="host" if "host" in OS.get_cmdline_user_args() else "client"
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.bot_fill=false; game.team_size=2;game.mode=2;game.matchup=1;game.game_type.matchup=1
	if role=="host":
		check(game.host_direct(17877,"HostTest",0)==OK,"ENet host opens UDP port")
	else: check(game.join_direct("127.0.0.1",17877,"ClientTest",1)==OK,"Client begins direct-IP join")
	var timeout=Time.get_ticks_msec()+20000
	while game.lobby_members.size()<2 and Time.get_ticks_msec()<timeout: await process_frame
	check(game.lobby_members.size()==2,"Both session names appear in lobby roster")
	if game.lobby_members.size()<2: quit(1); return
	if role=="host":
		game.start_game(); game.context="pause"
		for actor in game.actors:
			actor.global_position=Vector3(8 if actor.remote_peer==1 else -8,7.08,-17)
			actor.rotation.y= -PI/2 if actor.remote_peer!=1 else PI/2
			actor.eye.rotation.x=0
	else:
		while not game.running and Time.get_ticks_msec()<timeout: await process_frame
		check(game.running and game.player.remote_peer==multiplayer_peer_id(),"Host start creates the correct local client actor")
		await create_timer(0.5).timeout
		game.player.rotation.y=-PI/2; game.player.eye.rotation.x=0
		var before=game.player.global_position.x
		Input.action_press("forward"); await create_timer(0.9).timeout; Input.action_release("forward")
		check(game.player.global_position.x>before+2,"Client predicts movement while sending server input")
		await create_timer(0.5).timeout
		game.player.rotation.y=-PI/2; game.player.eye.rotation.x=0
		game.player.switch_weapon()
		await create_timer(0.6).timeout
		game.player.fire_trigger()
		await create_timer(0.8).timeout
		var host=game.actor_by_id(1)
		check(host!=null and host.shield<100,"Owner-view shot report damages server-controlled protection")
		check(game.player.ammo[1]<36,"Shot spends server-owned ammunition")
		game.send_chat("Network test message")
		await create_timer(0.5).timeout
		check("ClientTest: Network test message" in game.messages,"Same-match chat returns via host relay")
		game.player.throw_grenade()
		await create_timer(0.5).timeout
		check(game.player.grenades[0]==1,"Grenade release spends one host-owned inventory item")
		game.context="pause"
		await create_timer(2.0).timeout
		game.close_connection()
		print("RESULT "+role+": %d checks, %d failures"%[checks,failures]); game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
	if role=="host":
		await create_timer(5.0).timeout
		var remote: NestActor
		for actor in game.actors:
			if actor.remote_peer>1: remote=actor
		check(remote!=null and remote.global_position.x> -5,"Host simulates the client's movement input")
		check(game.player.shield<100,"Host accepts legal owner-view hit without positional reraycast")
		check("ClientTest: Network test message" in game.messages,"Host receives relayed client chat")
		check(game.shot_authorizations.size()>0,"Remote shots require authorization")
		await create_timer(3).timeout
		check(game.lobby_members.size()==1,"Client disconnect cleans up session membership")
		print("RESULT "+role+": %d checks, %d failures"%[checks,failures]); game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(0.3).timeout; quit(1 if failures else 0)
func multiplayer_peer_id(): return game.multiplayer.get_unique_id()
