extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func ticks(n):
	for i in range(n):await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.bot_fill=false;game.mode=2;game.fair_playing_field=false;game.start_game();game.player.set_physics_process(false);game.player.global_position=Vector3(80,25,80)
	var bot=NestActor.new();bot.game=game;bot.faction=1;game.add_child(bot);game.actors.append(bot);bot.respawn();bot.bot_movement=NestBotMovement.new(bot)
	check(game.arena.nav_graph.get_point_count()==game.arena.nav_points.size(),"Bots use a cached weighted navigation graph")
	for path in game.arena.up_routes:
		if path!=game.arena.up_routes[0]:continue
		bot.global_position=path.start+Vector3.UP*.08;bot.controlled=Vector3.ZERO;bot.external=Vector3.ZERO;bot.velocity=Vector3.ZERO;bot.target=null;bot.bot_destination=path.end;bot.bot_route=game.arena.route(bot.global_position,path.end);bot.bot_repath=INF
		if bot.bot_movement!=null:bot.bot_movement.reset()
		var reached=false;var deadline=game.now+8;var wall_deadline=Time.get_ticks_msec()+10000
		while game.now<deadline and Time.get_ticks_msec()<wall_deadline:
			await physics_frame
			if absf(bot.global_position.y-path.end.y)<.4 and Vector2(bot.global_position.x-path.end.x,bot.global_position.z-path.end.z).length()<1.6:reached=true;break
		print("BOT ROUTE ",path.name," ",bot.global_position," goal ",path.end)
		check(reached and bot.alive,"Bot traverses actual ascending ramp: "+path.name)
	bot.set_physics_process(false);bot.global_position=Vector3(-5,0,2)*.85+Vector3.UP*.08;bot.target=null;bot.bot_movement.reset();await ticks(4)
	var wall=StaticBody3D.new();wall.collision_layer=1;var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.3,3,3);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=bot.global_position+Vector3.LEFT*2+Vector3.UP
	await ticks(3)
	check(not bot.bot_movement.clear_direction(Vector3.LEFT,6),"Wide body probes reject a verified wall fixture")
	check(not game.arena.has_walk_support(Vector3(80,0,80)),"Bot ledge avoidance rejects unsupported destinations")
	print("BOT MOVEMENT: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await create_timer(.3).timeout;quit(1 if failures else 0)
