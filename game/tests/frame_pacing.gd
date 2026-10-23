extends SceneTree
# Run native for frame/render timings, headless for the 10-actor CPU workload.
var game
var times: Array[float] = []
var physics: Array[float] = []
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(960,600)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.team_size=5; game.bot_fill=true; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true
	game.player.global_position=Vector3(-13,7.1,0); game.player.rotation.y=-PI/2
	game.context="pause"; Engine.max_fps=0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in range(180): await process_frame
	var previous=Time.get_ticks_usec()
	var until=previous+12000000
	while Time.get_ticks_usec()<until:
		await process_frame
		var current=Time.get_ticks_usec()
		times.append((current-previous)/1000.0); previous=current
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	times.sort(); physics.sort()
	print("FRAME_PACING ",JSON.stringify({"frames":times.size(),"frame_median_ms":times[int(times.size()*.5)],"frame_p95_ms":times[int(times.size()*.95)],"frame_p99_ms":times[int(times.size()*.99)],"physics_median_ms":physics[int(physics.size()*.5)],"physics_p95_ms":physics[int(physics.size()*.95)],"actors":game.actors.size(),"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	game.stop_game(); await process_frame; quit()
