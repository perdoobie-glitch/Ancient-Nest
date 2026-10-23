extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func ticks(count):
	for i in range(count): await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.mode=2; game.starting_primary="default"; game.starting_secondary="default"; game.start_game(); await ticks(5)
	var a=game.arena; var player=game.player; player.set_physics_process(false)
	check(a.scale.is_equal_approx(Vector3.ONE*.85) and a.bounds.is_equal_approx(Vector2(42.5,28.05)),"Entire arena and collision are uniformly 15% smaller")
	check(a.floor_surfaces.size()>=58 and a.floor_cover.size()>=34,"Added supported walkways and substantially more room walls")
	check(a.level_at(0)==0 and a.level_at(5.95)==1 and a.level_at(11.9)==2,"Floor classification follows compacted heights")
	var destinations=[a.sites[0],a.sites[1],a.ship_position,Vector3(6,14,8)*.85]
	for faction in a.spawns:
		for pos in a.spawns[faction]:
			var reachable=true
			for target in destinations:
				if a.route(pos,target).is_empty(): reachable=false
			check(reachable,"Spawn %s retains routes to both objectives, ship and top"%pos)
			var q=PhysicsShapeQueryParameters3D.new(); var capsule=CapsuleShape3D.new(); capsule.height=1.85; capsule.radius=.32; q.shape=capsule; q.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.95);q.collision_mask=1
			check(game.get_world_3d().direct_space_state.intersect_shape(q).is_empty() and not game.trace(pos+Vector3.UP*.1,pos-Vector3.UP*.5,1).is_empty(),"Spawn %s remains clear with floor support"%pos)
	# Tall bearing wall must block real rays on both lower levels.
	for base in [0,7]:
		check(not game.trace(Vector3(7,base+1.2,3)*.85,Vector3(13,base+1.2,3)*.85,1).is_empty(),"Room wall blocks long sightline on level "+str(base))
	var pads=a.find_children("*","NestManCannon",true,false)
	# Script classes may not be registered as native type filters.
	if pads.is_empty():
		for child in a.get_children():
			if child is NestManCannon: pads.append(child)
	check(pads.size()==3,"Three optional man cannon routes including direct bottom-to-top")
	for cannon in pads:
		player.respawn(); player.global_position=cannon.global_position+Vector3.UP*.08; player.controlled=Vector3.ZERO;player.external=Vector3.ZERO;player.velocity=Vector3.ZERO;player.set_physics_process(true);player.reset_physics_interpolation(); game.clear_held_input()
		await ticks(12)
		check(player.velocity.y>3,"Cannon launches player upward: "+str(cannon.name))
		await ticks(300);player.set_physics_process(false)
		var target=a.to_global(cannon.destination)
		print("LAND ",cannon.name," ",player.global_position," target ",target)
		check(player.alive and player.is_on_floor() and absf(player.global_position.y-target.y)<.35 and Vector2(player.global_position.x-target.x,player.global_position.z-target.z).length()<4,"Cannon lands on intended supported deck: "+str(cannon.name))
	# Traverse every named walking ascent with the actual player capsule.
	game.context="playing"; player.set_physics_process(true)
	for path in a.up_routes:
		if not (path.name.begins_with("U") or path.name.begins_with("J1") or path.name.begins_with("EAST OUTER")): continue
		player.respawn(); player.global_position=path.start+Vector3.UP*.09; player.controlled=Vector3.ZERO; player.external=Vector3.ZERO;player.velocity=Vector3.ZERO;player.cannon_takeoff=false
		var direction=path.end-path.start; player.rotation.y=atan2(-direction.x,-direction.z);player.reset_physics_interpolation();await ticks(4)
		Input.action_press("forward")
		var flat=Vector2(direction.x,direction.z)
		for i in range(600):
			await ticks(1)
			var progress=Vector2(player.global_position.x-path.start.x,player.global_position.z-path.start.z).dot(flat.normalized())
			if progress>=flat.length()+.1 and absf(player.global_position.y-path.end.y)<.35:break
		Input.action_release("forward")
		print("RAMP ",path.name," ",player.global_position," target ",path.end)
		check(player.alive and absf(player.global_position.y-path.end.y)<.35,"Walking ascent remains open: "+path.name)
	game.context="pause";var lift=a.get_node("U2Lift");lift.clock=0;await ticks(5)
	player.respawn();player.global_position=Vector3(39,0,0)*.85+Vector3.UP*.07;player.controlled=Vector3.ZERO;player.external=Vector3.ZERO;player.velocity=Vector3.ZERO;player.reset_physics_interpolation();await ticks(500)
	check(player.is_on_floor() and player.global_position.y>11.5 and absf(lift.global_position.x-33.15)<.01,"Scaled moving lift carries the capsule to the top in its resized shaft")
	print("COMPACT MAP: %d checks, %d failures"%[checks,failures]); game.stop_game();game.queue_free();await create_timer(.3).timeout;quit(1 if failures else 0)
