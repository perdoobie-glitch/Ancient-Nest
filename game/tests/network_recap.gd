extends SceneTree
class Gate:
	extends Node
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(key: String):marks[key]=true
var game
var gate: Gate
var role: String
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS "+role+": "+message)
	else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(predicate: Callable) -> bool:
	var deadline=Time.get_ticks_msec()+9000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func run():
	role="host" if "host" in OS.get_cmdline_user_args() else "client";game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.bot_fill=false;game.mode=2;game.team_size=1;game.fair_playing_field=true;game.fair_health_type="naki";game.starting_primary="ak47";game.starting_secondary="burst";game.prefs.values.chat=false
	gate=Gate.new();gate.name="RecapGate";game.add_child(gate)
	check((game.host_direct(17887,"KillerHost",0) if role=="host" else game.join_direct("127.0.0.1",17887,"VictimClient",1))==OK,"Direct recap session opens")
	check(await wait_for(func():return game.lobby_members.size()==2),"Both peers join")
	if role=="host":
		game.start_game();game.context="pause"
		for actor in game.actors:actor.set_physics_process(false);actor.global_position=Vector3(80,25,80 if actor.local_player else 75)
		check(await wait_for(func():return gate.marks.has("ready")),"Client receives prepared match")
		var remote=game.actors.filter(func(a):return a.remote_peer>1)[0]
		game.player.take_damage(1,"torso","bullet",false,remote,game.next_event(),Vector3.INF,"burst",0)
		for i in range(4):remote.take_damage(1,"torso","bullet",false,game.player,game.next_event(),Vector3.INF,"ak47",0)
		remote.take_damage(1,"head","bullet",false,game.player,game.next_event(),Vector3.INF,"ak47",0)
		check(remote.death_recap.taken.damage==300 and remote.death_recap.given.damage==20,"Authority computes complete exchange totals")
		check(game.messages.is_empty(),"Victim recap is private, not broadcast to killer chat")
		check(await wait_for(func():return gate.marks.has("verified")),"Client confirms its recap and pickup")
	else:
		check(await wait_for(func():return game.running and game.player!=null),"Client enters match")
		game.player.set_physics_process(false);gate.mark.rpc_id(1,"ready")
		check(await wait_for(func():return not game.player.alive and not game.player.death_recap.is_empty()),"Reliable recap and elimination reach victim")
		check(game.player.death_recap.killer=="KillerHost" and game.player.death_recap.taken.damage==300 and game.player.death_recap.given.damage==20,"Victim receives correct killer and actual totals")
		await process_frame
		check(game.hud_death_recap.text.contains("You took: 100/100") and not game.hud_chat.visible,"Recap HUD works with chat disabled")
		var before=game.player.death_recap.duplicate(true);game.receive_death_recap(game.player.net_id,game.player.life_id,game.match_session+1,game.round_number,{"killer":"Stale"})
		check(game.player.death_recap==before,"Stale-session recap is rejected")
		gate.mark.rpc_id(1,"verified")
	print("NETWORK RECAP "+role+": %d checks, %d failures"%[checks,failures]);await create_timer(.2).timeout;game.stop_game();game.close_connection();game.queue_free();await create_timer(.3).timeout;quit(1 if failures else 0)
