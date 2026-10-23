extends SceneTree
var game
func _initialize(): call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var host="host" in args
	# Optional (v0.11): host|client <host_port> <connect_port> <out.json> <seconds>
	var host_port=int(args[1]) if args.size()>1 else 17878
	var connect_port=int(args[2]) if args.size()>2 else 17878
	var out_path=args[3] if args.size()>3 else ""
	var seconds=float(args[4]) if args.size()>4 else 4.0
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.lobby_network.set_process(false);game.lobby_network=null; await process_frame
	game.game_type=NestMatchPresets.create(2,0,1,false)
	game.game_type.bots_fill_empty_slots=true
	game.game_type.bots_team_0=-1;game.game_type.bots_team_1=-1
	game.sync_game_type_to_legacy()
	if host: game.host_direct(host_port,"LoadHost",0)
	else: game.join_direct("127.0.0.1",connect_port,"LoadClient",1)
	var limit=Time.get_ticks_msec()+20000
	while game.lobby_members.size()<2 and Time.get_ticks_msec()<limit: await process_frame
	if game.lobby_members.size()<2: push_error("Load test connection timeout"); quit(1); return
	if host: game.start_game(); game.context="pause"
	else:
		while not game.running and Time.get_ticks_msec()<limit: await process_frame
		game.context="pause"
	var received0=float(game.net_stats.get("snapshots_completed",0.0))
	await create_timer(seconds).timeout
	var valid=game.actors.size()==10
	for actor in game.actors: valid=valid and actor.global_position.is_finite() and actor.health>=0 and actor.shield>=0
	if not host: valid=valid and game.snapshot_received>=40
	if not out_path.is_empty():
		var report={"role":"host" if host else "client","seconds":seconds,"actors":game.actors.size(),"valid":valid,"stats":game.net_stats.duplicate()}
		if not host: report["snapshots_completed"]=int(float(game.net_stats.get("snapshots_completed",0.0))-received0); report["snapshots_expected"]=int(seconds*20)
		else:
			report["snapshots_sent"]=game.snapshot_sequence
			var samples=[];var sizes=[]
			for sample in range(20):
				var began=Time.get_ticks_usec()
				var payload=var_to_bytes(game.snapshot_state()).compress(FileAccess.COMPRESSION_DEFLATE)
				samples.append((Time.get_ticks_usec()-began)/1000.0);sizes.append(payload.size())
			report["serialization_ms"]=samples;report["compressed_snapshot_bytes"]=sizes
		var f=FileAccess.open(out_path,FileAccess.WRITE); f.store_string(JSON.stringify(report)); f.close()
	print("PASS" if valid else "FAIL",": ten-actor ","host" if host else "client"," snapshot load test")
	await create_timer(1.5 if host else 4.0).timeout
	game.stop_game(); game.close_connection(); game.queue_free(); await create_timer(0.3).timeout
	quit(0 if valid else 1)
