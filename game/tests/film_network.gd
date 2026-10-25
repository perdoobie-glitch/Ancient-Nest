extends SceneTree
class Gate extends Node:
	var marks={}
	@rpc("any_peer","call_remote","reliable")
	func mark(key: String):marks[key]=true
var game
var role=""
var failures=0
func check(ok: bool,message: String):
	print(("PASS " if ok else "FAIL ")+role+": "+message)
	if not ok:failures+=1
func wait_for(test: Callable,seconds: int=60):
	var until=Time.get_ticks_msec()+seconds*1000
	while not test.call() and Time.get_ticks_msec()<until:await process_frame
	return test.call()
func _initialize():call_deferred("run")
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	var rules=GameTypeSettings.new();rules.mode=1;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules)
	var gate=Gate.new();gate.name="FilmGate";game.add_child(gate)
	check((game.host_direct(17958,"Film Host",0) if role=="host" else game.join_direct("127.0.0.1",17958,"Film Client",1))==OK,"Transport opens")
	check(await wait_for(func():return game.lobby_members.size()==2),"Both participants admitted")
	if role=="host":game.start_game()
	check(await wait_for(func():return game.running and game.film_recorder.active),"Timestamped recording begins")
	game.context="pause"
	await create_timer(2.2).timeout
	check(game.film_recorder.views.size()>0 or game.film_recorder.metrics.samples>40,"Local camera/presentation track sampled")
	check(game.film_recorder.transfer.metrics.upload_bytes==0,"No perspective upload during live gameplay")
	if role=="host":game.finished=true
	check(await wait_for(func():return game.finished),"Match completion reaches peer")
	check(await wait_for(func():return game.film_recorder.ended),"Recording closes before transfer")
	game.film_recorder.transfer.rate_limit=4096
	game.matchmaking.hybrid.handle_control({"type":"return_queue"})
	check(game.film_retaining_transport and game.network_active and not game.running,"Post-match transport retained without gameplay")
	game.begin_network_match({"session":1},{})
	check(not game.running,"Gameplay RPC is rejected during film collection")
	var expected=game.film_recorder.peer_identity(game.multiplayer.get_peers()[0])
	check(await wait_for(func():return game.film_recorder.transfer.completed.has(expected)),"Authenticated remote perspective received")
	check(await wait_for(func():return game.film_recorder.queue.is_empty() and game.film_recorder.received_queue.is_empty() and game.film_recorder.worker==null),"Merged film commits asynchronously")
	var loaded=NestFilmArchive.read(NestFilmArchive.path(game.film_recorder.id))
	check(not loaded.has("error") and loaded.tracks.size()==2,"Saved film includes both local perspectives")
	gate.mark.rpc("done")
	check(await wait_for(func():return gate.marks.has("done")),"Both peers finish transfer")
	check(await wait_for(func():return game.film_recorder.transfer.outgoing.is_empty()),"All perspective uploads finish")
	var metrics=game.film_recorder.metrics.duplicate();metrics.merge(game.film_recorder.transfer.metrics)
	print("FILM_METRICS "+role+" "+JSON.stringify(metrics))
	await create_timer(.25).timeout
	game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
	print("FILM NETWORK "+role+" failures="+str(failures));quit(1 if failures else 0)
