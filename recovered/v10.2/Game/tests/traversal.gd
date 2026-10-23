extends SceneTree
func _initialize(): call_deferred("run")
func ticks(count):
	for i in range(count): await physics_frame
func run():
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.start_game(); game.context="playing"
	game.player.global_position=Vector3(0,0.05,-18.5); game.player.rotation.y=0
	await ticks(8); Input.action_press("backward"); await ticks(12)
	for i in range(5):
		Input.action_press("jump"); await ticks(1); Input.action_release("jump"); await ticks(92)
		print("J1 LEDGE ",i+1," position ",game.player.global_position)
	Input.action_release("backward")
	var jump_ok=game.player.alive and game.player.global_position.y>=6.9
	print("PASS" if jump_ok else "FAIL",": J1 physically reaches upper Temple")
	game.stop_game(); await ticks(2)
	game.bot_fill=true; game.team_size=2; game.tuning.bag_stock=1; game.start_game(); game.context="pause"
	var bot
	for actor in game.actors:
		actor.bot_fire=INF
		if not actor.local_player and actor.faction==0: bot=actor
		elif not actor.local_player: actor.set_physics_process(false)
	if "lower" in OS.get_cmdline_user_args(): bot.global_position=Vector3(-32,0.05,-7); bot.bot_route.clear(); bot.bot_repath=0
	for i in range(9600):
		await physics_frame
		if i%1200==0: print("BOT OBJECTIVE ",i," pos ",bot.global_position," stage ",game.site_states," delivered ",bot.delivered," route ",bot.bot_route," velocity ",bot.velocity," active ",bot.is_physics_processing())
		if bot.delivered>0: break
	var bot_ok=bot.delivered>0 and game.scores[0]>=2
	print("PASS" if bot_ok else "FAIL",": Bot completes plant / bomb / drill / load / return / delivery")
	game.stop_game(); game.queue_free(); await create_timer(0.3).timeout; quit(0 if jump_ok and bot_ok else 1)
