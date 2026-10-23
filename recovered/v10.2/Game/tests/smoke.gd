extends SceneTree
var failures: int=0
var checks: int=0
var game
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1; push_error("FAILED: "+message)
	else: print("PASS: "+message)
func tick(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	check(not game.running and game.current_screen=="main","Startup stays in main menu")
	game.show_lobby(); check(game.current_screen=="lobby","Custom lobby opens")
	game.open_settings("main")
	for tab in ["Controls","Video","Audio","HUD"]: game.settings_tab=tab; game.show_settings(); await process_frame
	check(game.current_screen=="settings","All four settings tabs render")
	var old=game.prefs.values.sensitivity
	game.draft.sensitivity=0.22; game.apply_draft()
	var loaded=NestPreferences.new(); loaded.load_saved()
	check(is_equal_approx(loaded.values.sensitivity,0.22),"Applied preferences persist")
	game.prefs.values.sensitivity=old; game.prefs.save()
	game.show_main(); game.bot_fill=false; game.start_game(); game.create_hud(); game.hud.visible=true
	game.context="pause"; game.current_screen="pause"
	check(game.actors.size()==1,"Bot fill Off spawns no bots")
	var player: NestActor=game.player
	await tick(10)
	check(player.global_position.y> -0.2,"Player spawn has a supported floor")
	var cfg: NestTuning=game.tuning
	check(is_equal_approx(cfg.round_seconds,180.0),"Extraction uses the latest 180-second default")
	check(is_equal_approx(cfg.drill_seconds,45.0) and is_equal_approx(cfg.load_seconds,10.0),"Confirmed drilling and loading durations")
	# Pure air solver tests: no-input conservation, curve and cap.
	var velocity=Vector3(6,0,0)
	check(NestActor.air_move(velocity,Vector3.ZERO,cfg,1.0/60).is_equal_approx(velocity),"No input preserves air momentum")
	var curved=NestActor.air_move(velocity,Vector3(0,0,-1),cfg,1.0/60)
	check(curved.z<0 and is_equal_approx(curved.x,6),"Air acceleration preserves existing tangent momentum")
	for i in range(300):
		var wish=Vector3(cos(i*0.06),0,sin(i*0.06)); velocity=NestActor.air_move(velocity,wish,cfg,1.0/60)
	check(velocity.length()<=9.001,"Controlled air velocity respects 9 m/s ceiling")
	# Faction damage, deduplication and armor mitigation.
	player.shield=100; player.health=100
	var id=game.next_event()
	player.take_damage(120,"head","bullet",true,null,id)
	check(player.shield==0 and player.health==100,"Naki ordinary shield-break hit has no spillover/head bonus")
	player.take_damage(20,"torso","bullet",false,null,id)
	check(player.health==100,"Duplicate attack cannot apply damage twice")
	player.take_damage(20,"head","bullet",false,null,game.next_event())
	check(not player.alive and player.health==0,"Exposed Naki headshot kills immediately")
	player.respawn()
	player.faction=1; player.health=100; player.armor=100
	player.take_damage(20,"torso","bullet",false,null,game.next_event())
	check(is_equal_approx(player.health,90) and is_equal_approx(player.armor,90),"Annu armor prevents/spends 50% of torso damage")
	player.faction=0; player.health=100; player.shield=100
	# Validate physical drop holes and southern connection geometry by real rays.
	for x in [-21.0,21.0]:
		for z in ([-10.0,10.0] if x<0 else [-10.0]):
			var drop=game.trace(Vector3(x,10,z)*.85,Vector3(x,-2,z)*.85,1)
			check(not drop.is_empty() and absf(drop.position.y)<0.1,"Safe drop at (%d,%d) reaches lower dry floor"%[x,z])
	var south=game.trace(Vector3(12,10,16)*.85,Vector3(12,-2,16)*.85,1)
	check(not south.is_empty() and absf(south.position.y-5.95)<.1,"New southeast market supplies the middle southern route")
	# Direct accepted interactions are reached via same proximity/eligibility path.
	player.global_position=game.arena.sites[0]+Vector3(-2.5,0.05,0)
	var choice=game.interaction_for(player)
	check(choice.get("key","")=="plant:0","Attacker can plant at upper site")
	check(game.complete_interaction(player,choice),"Plant transitions exactly once")
	check(not game.complete_interaction(player,choice),"Repeated plant completion is rejected")
	game.site_states[0].bomb_at=game.now
	game.update_objectives(1.0/60)
	check(game.scores[0]==1 and game.site_states[0].stage=="off","Bomb explosion scores once and unlocks drill")
	game.complete_interaction(player,game.interaction_for(player))
	check(game.site_states[0].stage=="starting","Drill activation enters startup")
	game.update_objectives(1)
	check(game.site_states[0].work==0,"Startup does not advance drill work")
	game.site_states[0].start_at=game.now
	game.update_objectives(20)
	check(game.site_states[0].work==20,"Powered machine accumulates active work")
	player.faction=1
	game.complete_interaction(player,game.interaction_for(player))
	game.update_objectives(5)
	check(game.site_states[0].stage=="off" and game.site_states[0].work==20,"Defender shutdown retains work and earns zero points")
	player.faction=0
	game.complete_interaction(player,game.interaction_for(player)); game.site_states[0].start_at=game.now; game.update_objectives(25)
	check(game.site_states[0].stage=="complete","Restart finishes remaining drill work")
	game.complete_interaction(player,game.interaction_for(player))
	check(player.carrying and game.scores[0]==1,"Loading grants one bag and no score")
	game.drop_bag(player)
	check(not player.carrying and game.bags.size()==1,"Gold drops once and clears carry trait")
	game.complete_interaction(player,game.interaction_for(player))
	check(player.carrying and game.bags.is_empty(),"Dropped bag has one recovered owner")
	player.global_position=game.arena.ship_position+Vector3(0,0.05,0)
	var delivery=game.interaction_for(player)
	check(game.complete_interaction(player,delivery) and game.scores[0]==2,"Alive base-ship delivery scores one point")
	check(not game.complete_interaction(player,delivery) and game.scores[0]==2,"Duplicate delivery cannot score again")
	# Traverse the physical western return ramp; the upper deck has capsule clearance.
	player.global_position=Vector3(-29,0,12.5)*.85+Vector3.UP*.08; player.rotation.y=0; player.controlled=Vector3.ZERO; player.velocity=Vector3.ZERO; player.external=Vector3.ZERO; player.reset_physics_interpolation()
	await tick(8); game.context="playing"; Input.action_press("forward"); await tick(235); Input.action_release("forward"); game.context="pause"
	check(player.global_position.y>7.5,"U1 ramp physically returns a walking player to upper base")
	var lift=game.arena.get_node("U2Lift"); lift.clock=0
	await tick(5); player.global_position=Vector3(39,0,0)*.85+Vector3.UP*.06; player.controlled=Vector3.ZERO; player.velocity=Vector3.ZERO
	await tick(500)
	print("LIFT END ",player.global_position," platform ",lift.global_position)
	check(player.global_position.y>8.8,"U2 moving lift physically carries a player upstairs")
	# Blast occlusion is tested against three target sample rays.
	var victim=NestActor.new(); victim.game=game; victim.faction=1; game.add_child(victim); game.actors.append(victim); victim.global_position=Vector3(2,7.06,-17)
	victim.set_physics_process(false)
	var wall=Node3D.new(); game.add_child(wall); game.arena.kit.box(wall,Vector3(0,8.5,-17),Vector3(0.3,4,5),game.arena.kit.stone,true)
	await tick(2)
	game.explode(Vector3(-2,8.3,-17),player,game.next_event(),160)
	check(victim.health==100 and victim.armor==100,"Solid cover blocks explosion damage to all samples")
	game.actors.erase(victim); victim.queue_free(); wall.queue_free(); await tick(2)
	# Fixed pickup cadence never grants topups to a held weapon across the map.
	game.now=game.round_started+30; game._physics_process(0.01)
	check(game.pad_stock[4]>=1,"Power pickups become available at elapsed 30 seconds")
	game.take_pickup(player,0)
	var sniper_reserve=player.reserve.back()
	game.now=game.round_started+150; game._physics_process(0.01)
	check(game.pad_stock[0]==1 and player.reserve.back()==sniper_reserve,"Empty pad replenishes at 150 seconds without topping up held weapon")
	check(game.pad_stock[1]==1,"Occupied weapon pad does not accumulate duplicate weapons")
	game.reset_round()
	# Collision measured jump in an unobstructed area of north gallery.
	player.global_position=Vector3(-13,7,-17)*.85+Vector3.UP*.06; player.velocity=Vector3.ZERO; player.controlled=Vector3.ZERO
	await tick(8)
	game.context="playing"
	Input.action_press("jump")
	await tick(1)
	Input.action_release("jump")
	var start=player.global_position.y
	var apex=start
	var airborne=0
	for i in range(100):
		await tick(1); apex=maxf(apex,player.global_position.y)
		if not player.is_on_floor(): airborne+=1
	check(apex-start>1.8 and apex-start<2.1,"Measured jump apex is about 2 meters")
	check(airborne>=74 and airborne<=84,"Measured flight is about 1.4 seconds at 60 Hz")
	game.context="pause"
	player.die(null,"test")
	var life=player.life_id
	await tick(170)
	check(not player.alive,"Respawn does not happen before 3 seconds")
	await tick(15)
	check(player.alive and player.life_id==life+1,"Respawn creates one new life after 3 seconds")
	game.stop_game(); game.bot_fill=true; game.team_size=5; game.start_game(); game.context="pause"
	check(game.actors.size()==10,"Five-versus-five bot fill creates ten actors")
	# Simulate ten actors through two pickup cadence events and round expiry.
	for i in range(11400): await physics_frame
	check(game.round_number>=2,"Ten-actor runtime reaches the next round")
	check(game.scores[0]>=0 and game.scores[1]>=0,"Long match simulation preserves valid scores")
	game.stop_game(); game.queue_free()
	await create_timer(1.1).timeout
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
