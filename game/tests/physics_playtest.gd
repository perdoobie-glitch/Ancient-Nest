extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func box(position: Vector3,size: Vector3):
	var body=StaticBody3D.new();var shape=CollisionShape3D.new();var cube=BoxShape3D.new()
	cube.size=size;shape.shape=cube;body.add_child(shape);game.add_child(body);body.global_position=position
func traverse(duck: bool) -> bool:
	var p=game.player;p.reset_crouch();p.global_position=Vector3(150,20.05,150)
	for i in range(8):
		p.velocity=Vector3(0,-1,0);p.move_and_slide();await physics_frame
	p.controlled=Vector3(3.5,game.tuning.jump_speed,0)
	for i in range(100):
		if duck and i==20:
			var head=p.eye.global_position.y;p.set_crouch(true)
			check(absf(p.eye.global_position.y-head)<.001,"Air crouch preserves eye/head height")
			check(p.air_duck and p.capsule.position.y-p.capsule.shape.height*.5>.6,"Air crouch raises the capsule feet")
		p.controlled.y-=game.tuning.gravity/60.0;p.velocity=p.controlled
		p.update_crouch_shape();p.move_and_slide();p.update_crouch_shape()
		if p.is_on_floor():p.controlled.y=0
		await physics_frame
		if p.global_position.x>153.1 and p.is_on_floor():return true
	return false
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
	game.bot_fill=false;game.mode=1;game.selected_faction=0;game.fair_playing_field=false;game.start_game();game.create_hud();game.set_physics_process(false);game.player.set_physics_process(false)
	box(Vector3(150,19.5,150),Vector3(20,1,8));box(Vector3(154,21.175,150),Vector3(3,2.35,8))
	check(not await traverse(false),"Standing jump cannot clear a 2.35-metre ledge")
	check(await traverse(true),"Crouch jump clears and lands on the higher ledge")
	var p=game.player;p.reset_crouch();p.global_position=Vector3(150,25,150);p.shield=0;p.body_phase=true;p.last_damage=game.now
	game.context="playing";game.hurt_overlay._process(.016);check(game.hurt_overlay.visible,"Red edge remains visible with empty shields")
	p.shield=1;game.hurt_overlay._process(.016);check(not game.hurt_overlay.visible,"Red edge clears when shields return")
	p.shield=0;p.controlled=Vector3.ZERO;game.now=p.last_damage+4.99;p._physics_process(.01)
	check(p.shield==0,"Broken shields wait the full five seconds")
	game.now=p.last_damage+5;p._physics_process(1.0/60)
	check(p.shield>0 and not p.body_phase,"Broken shields begin recharging at five seconds")
	for i in range(179):p._physics_process(1.0/60)
	check(absf(p.shield-game.tuning.shield_capacity)<.001,"Empty shields fully replenish in three seconds")
	var voice=p.combat_audio.cue("footstep_concrete_walk","test",false)
	if not voice.is_empty() and voice[0] is AudioStreamPlayer:
		var gain=voice[0].volume_db;game.audio.stop_group(p.combat_audio.group("test"))
		p.local_player=false;voice=p.combat_audio.cue("footstep_concrete_walk","test",false)
		check(not voice.is_empty() and absf(voice[0].volume_db-gain-13.9794)<.01,"Only own footsteps are reduced to 20% volume")
	elif DisplayServer.get_name()=="headless":print("SKIP: native audio gain measurement unavailable headless (covered by native run)")
	else:check(false,"Native audio voice available for gain verification")
	var enemy=NestActor.new();enemy.game=game;enemy.username="ReportEnemy";enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.respawn();enemy.set_physics_process(false)
	enemy.global_position=Vector3(160,30,150);enemy.update_visual(.016);await physics_frame
	var head=enemy.hitboxes[0].global_position
	var central=game.trace(head+Vector3(0,0,1),head-Vector3(0,0,1),4)
	check(not central.is_empty() and central.collider==enemy.hitboxes[0],"Current convex head centre registers")
	check(enemy.hitbox_shapes.all(func(shape):return shape is ConvexPolygonShape3D),"All damage regions use current convex contours")
	p.local_player=true;p.respawn();p.set_physics_process(false)
	for i in range(2):p.take_damage(1,"torso","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	check(p.shield==0 and p.alive,"Two AK rounds still drain standard Naki shields")
	p.take_damage(1,"head","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	check(not p.alive and p.death_recap.taken.damage==200,"Exposed AK headshot still kills; raw accounting remains intact")
	check(absf(p.death_recap.taken.normalized-100)<.001 and p.death_recap_text().contains("Damage taken: 100/100"),"Death report normalizes shield and health loss to 100")
	enemy.respawn();p.respawn();p.take_damage(1,"torso","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	check(absf(p.damage_received[enemy.combat_key()].normalized-100.0/4)<.001,"Partial damage reports proportional progress")
	# Test actual standing dimensions at every spawn, not a smaller legacy capsule.
	for positions in game.arena.spawns.values():
		for spawn in positions:
			var query=PhysicsShapeQueryParameters3D.new();var cap=CapsuleShape3D.new();cap.height=NestActor.STAND_HEIGHT;cap.radius=NestActor.BODY_RADIUS;query.shape=cap;query.transform=Transform3D(Basis.IDENTITY,spawn+Vector3.UP*NestActor.STAND_CENTER);query.collision_mask=1
			check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Full-size player capsule is clear at spawn "+str(spawn))
	# Bounded falling velocity with the same movement solver used by client prediction.
	p.position=Vector3(500,3000,500);p.reset_crouch();p.controlled=Vector3.ZERO;p.external=Vector3.ZERO
	for i in range(600):p.movement_step(Vector2.ZERO,false,0,0,1.0/60)
	check(p.controlled.y>=-35.001 and p.controlled.y<=-34.999,"Gravity reaches, but never exceeds, the 35m/s terminal speed")
	print("PHYSICS PLAYTEST: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
