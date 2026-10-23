extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func ticks(count):
	for i in range(count): await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.mode=2; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true; game.context="playing"
	await ticks(10)
	var player=game.player; var arena=game.arena
	check(arena.floor_surfaces.size()>45,"Map has three detailed floor layouts")
	var signatures=[]
	for level in range(3):
		var layout=[]
		for floor in arena.floor_surfaces:
			if arena.level_at(floor.pos.y)==level: layout.append([floor.pos.x,floor.pos.z,floor.size])
		signatures.append(str(layout)); check(layout.size()>=8,"Floor %d has its own platforms"%level)
	check(signatures[0]!=signatures[1] and signatures[1]!=signatures[2] and signatures[0]!=signatures[2],"Bottom, middle and top layouts are distinct")
	var destinations=[arena.sites[0],arena.sites[1],arena.ship_position,Vector3(6,14,8)*.85]
	for faction in range(2):
		for pos in arena.spawns[faction]:
			var all_reachable=true
			for dest in destinations:
				if arena.route(pos,dest).is_empty(): all_reachable=false; print("UNREACHABLE ",pos," -> ",dest)
			check(all_reachable,"Spawn %s has graph routes to both deposits, ship and top"%pos)
			var query=PhysicsShapeQueryParameters3D.new(); var shape=CapsuleShape3D.new(); shape.height=1.85; shape.radius=.32
			query.shape=shape; query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.95); query.collision_mask=1
			var overlaps=game.get_world_3d().direct_space_state.intersect_shape(query)
			check(overlaps.is_empty() and not game.trace(pos+Vector3.UP*.1,pos-Vector3.UP*.5,1).is_empty(),"Spawn %s has standing clearance and floor support"%pos)
	check(ResourceLoader.exists(game.audio.manifest.sounds.naki_death.files[0]),"Sampled death cue is imported")
	check(game.audio.manifest.sounds.ak47_reload_magin.files.size()>0,"Reload uses sampled stage cues")
	check(InputMap.has_action("zoom") and game.prefs.key_label("zoom")=="Z","Zoom is an explicit rebindable keyboard control")
	player.weapons[0]=load("res://resources/sniper.tres"); player.update_weapon_art()
	game.context="playing"; game.capture_mouse()
	check(InputMap.action_get_events("zoom")[0].physical_keycode==KEY_Z,"Zoom control maps to the expected physical key")
	player.reset_aim(); player.weapons[0]=load("res://resources/rifle.tres")
	player.set_physics_process(false); game.set_physics_process(false)
	player.global_position=Vector3(80,25,80); player.rotation=Vector3.ZERO; player.eye.rotation=Vector3.ZERO; player.reset_physics_interpolation()
	var enemy=NestActor.new(); enemy.game=game; enemy.faction=1; game.add_child(enemy); game.actors.append(enemy); enemy.set_physics_process(false)
	enemy.global_position=Vector3(80.3,25,70)
	var origin=player.eye.global_position; var direction=Vector3(0,-.04,-1).normalized()
	var target=(enemy.global_position+Vector3(0,1.25,0)-origin).normalized()
	var assisted=player.magnetized_direction(origin,direction,100)
	check(assisted.is_equal_approx(direction),"No bullet magnetism changes the player's shot direction")
	check(player.camera.global_basis.is_equal_approx(player.eye.global_basis),"Aim-assist compatibility path never moves the aiming camera")
	enemy.cloak_deadline=0
	enemy.faction=0; enemy.shield=100; enemy.update_visual(.016)
	check(enemy.presentation.shield_aura.visible,"Healthy Naki has a subtle persistent shield glow")
	var healthy_color=enemy.presentation.aura_material.get_shader_parameter("energy_color")
	enemy.shield=18; enemy.update_visual(.016)
	check(enemy.presentation.shield_aura.visible and enemy.presentation.aura_material.get_shader_parameter("energy_color")!=healthy_color,"Low shields retain a distinct visible warning glow between hits")
	check(enemy.presentation.aura_material.get_shader_parameter("strength")<.3,"Low-shield warning glow reflects diminished shield energy")
	enemy.cloak_deadline=game.now+10; enemy.update_visual(.016)
	check(not enemy.presentation.shield_aura.visible,"Shield glow respects cloaking")
	enemy.cloak_deadline=0; enemy.faction=1; enemy.overshield=0; enemy.update_visual(.016)
	check(not enemy.presentation.shield_aura.visible,"Annu has no fake base-shield glow")
	player.health=25; player.shield=player.tuning.shield_capacity; player.reset_damage_visual(); game.hurt_overlay._process(.016)
	check(game.hurt_overlay.visible and is_equal_approx(game.hurt_overlay.effect.get_shader_parameter("health_ratio"),.25),"Persistent blood feedback follows low actual health at full shields")
	player.health=75; game.hurt_overlay._process(.016)
	check(is_equal_approx(game.hurt_overlay.effect.get_shader_parameter("health_ratio"),.75),"Higher health reduces the persistent blood-stain severity")
	player.health=100; game.hurt_overlay._process(.016)
	check(not game.hurt_overlay.visible,"Full health clears persistent blood stains")
	for side in [-1,1]:
		player.directional_hits.clear(); game.now+=.1
		player.take_damage(1,"torso","bullet",false,null,92000+side,origin+Vector3(side*5,0,0))
		game.hurt_overlay._process(.016)
		var edges: Vector4=game.hurt_overlay.effect.get_shader_parameter("damage_edges")
		check((edges.x>.8 and edges.y<.01) if side<0 else (edges.y>.8 and edges.x<.01),"Damage lights the correct %s edge"%("left" if side<0 else "right"))
	game.now+=2; game.hurt_overlay._process(.016)
	check(not game.hurt_overlay.visible or game.hurt_overlay.effect.get_shader_parameter("damage_edges").length()<.01,"Directional red lights fade")
	player.directional_hits.clear(); player.action_state="ready"; player.velocity=Vector3(3,0,0); player.update_visual(.1)
	var bone=player.skeleton.find_bone("thigh_r"); var rest=player.skeleton.get_bone_global_rest(bone).basis
	var before=player.skeleton.get_bone_global_pose(bone).basis; player.update_visual(.2)
	check(not before.is_equal_approx(player.skeleton.get_bone_global_pose(bone).basis),"Sideways strafe animates lateral leg motion")
	check(player.rotation==Vector3.ZERO and player.eye.rotation==Vector3.ZERO,"Strafing preserves forward facing and camera aim")
	game.impact(Vector3(80,25,70),Vector3.UP,true)
	var blasts=game.effects.find_children("BombExplosionFX*","Node3D",true,false)
	check(blasts.size()==1,"Bomb explosion creates fire, shockwave, smoke and debris")
	if not blasts.is_empty():
		var blast=blasts[0]; blast.set_process(false); blast._process(.2)
		check(blast.core.scale.x>1 and blast.fragments.size()==10,"Explosion expands and moves fragments")
		blast._process(1.7); await process_frame
		check(not is_instance_valid(blast),"Explosion removes its nodes after the effect")
	arena.deposits[0].visible=true; arena.set_site_visual(0,"drilling",game.now)
	var drill=arena.deposits[0].get_node("Opened/DrillAnimation"); drill.set_process(false); drill._process(.1)
	check(drill.active and drill.sparks.visible and absf(drill.head.rotation.y)>1,"Working drill rotates, feeds and emits sparks")
	arena.set_site_visual(0,"off",game.now); drill._process(.1)
	check(not drill.active and not drill.sparks.visible,"Switching drill off stops its effect")
	enemy.queue_free(); game.actors.erase(enemy)
	player.velocity=Vector3.ZERO; player.set_physics_process(true); game.set_physics_process(true); player.reset_aim()
	for path in arena.up_routes:
		if path.name=="BASE APPROACH": continue
		Input.action_release("forward"); game.clear_held_input()
		var horizontal=Vector3(path.end.x-path.start.x,0,path.end.z-path.start.z).normalized()
		player.global_position=path.start+Vector3.UP*.20-horizontal*.25; player.rotation.y=atan2(-horizontal.x,-horizontal.z)
		player.controlled=Vector3.ZERO; player.external=Vector3.ZERO; player.velocity=Vector3.ZERO; player.reset_physics_interpolation()
		await ticks(5); Input.action_press("forward")
		var success=false; var limit=ceili(path.start.distance_to(path.end)/game.tuning.ground_speed*120)+100
		for i in range(limit):
			await physics_frame
			if player.global_position.y>path.end.y-.12 and Vector2(player.global_position.x-path.end.x,player.global_position.z-path.end.z).length()<1.5: success=true; break
		Input.action_release("forward"); await ticks(5)
		print("ROUTE END ",path.name," ",player.global_position)
		check(success and player.alive,path.name+" physically reaches its upper landing")
	game.context="pause"; player.global_position=Vector3(39,.05,0); player.controlled=Vector3.ZERO; player.velocity=Vector3.ZERO; player.external=Vector3.ZERO; player.reset_physics_interpolation()
	var lift=arena.get_node("U2Lift"); lift.clock=0; lift.position.y=-.2
	var apex=player.global_position.y
	for i in range(630): await physics_frame; apex=maxf(apex,player.global_position.y)
	check(apex>13.8,"U2 moving lift physically returns a player to the top floor")
	print("EXPANSION: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await create_timer(.3).timeout; quit(1 if failures else 0)
