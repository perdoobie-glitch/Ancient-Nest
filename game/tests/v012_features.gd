extends SceneTree
# v0.12 feature checks (offline): matchups, 3-round character/side swap,
# shields 100 + HUD, shotgun +60%, 20% bigger players, melee lunge,
# shield animations, faint tracers and Capture the Flag rules.
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func ticks(count: int):
	for i in range(count): await physics_frame
func new_game(mode: int, matchup: int=0):
	if game!=null: game.stop_game(); game.queue_free(); await process_frame
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.team_size=1; game.mode=mode; game.matchup=matchup; game.fair_playing_field=false
	game.starting_primary="default"; game.starting_secondary="default"; game.selected_faction=0
	game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true; game.context="playing"
	await physics_frame
func add_enemy() -> NestActor:
	var enemy=NestActor.new(); enemy.game=game; enemy.faction=1; enemy.username="Enemy"; game.add_child(enemy); game.actors.append(enemy)
	await physics_frame
	return enemy
func visual_name(actor: NestActor) -> String:
	return actor.model.get_child(0).scene_file_path
func run():
	# ---- Matchups -------------------------------------------------------
	for matchup in [0,1,2]:
		await new_game(2,matchup)
		var enemy=await add_enemy()
		var expect=[["naki","annu"],["naki","naki"],["annu","annu"]][matchup]
		check(game.player.damage_model()==expect[0] and enemy.damage_model()==expect[1],"Matchup %s gives teams %s / %s protection"%[["Naki vs Annu","Naki vs Naki","Annu vs Annu"][matchup],expect[0],expect[1]])
		check(visual_name(enemy).contains("Naki" if expect[1]=="naki" else "Annu"),"Matchup %d builds the matching enemy model"%matchup)
	check(game.team_name(0)=="ANNU A" and game.team_name(1)=="ANNU B","Mirror matchups label the teams A and B")
	# ---- Shields, HUD, size ---------------------------------------------
	await new_game(2,1)
	var p: NestActor=game.player
	check(p.shield==100 and game.tuning.shield_capacity==100,"Naki shields are halved to 100")
	game._process(.016)
	check(game.hud_protection.text.begins_with("SHIELD") and not game.hud_protection.text.contains("100"),"Shield HUD shows the bar label without a number")
	check(game.protection_bars.size()==1 and game.protection_bars[0].value==100,"Shield bar remains")
	check(is_equal_approx(p.capsule.shape.height,1.9*1.2) and is_equal_approx(p.capsule.shape.radius,.35*1.2),"Player collision is 20% bigger")
	check(is_equal_approx(p.eye.position.y,1.65*1.2),"Camera / eye sits at the 20% higher head height")
	check(is_equal_approx(p.model.scale.y,1.2),"Character model and hitboxes are scaled 20%")
	p.set_crouch(true)
	check(is_equal_approx(p.capsule.shape.height,1.25*1.2) and is_equal_approx(p.eye.position.y,1.05*1.2),"Crouch shapes scale with the body")
	p.set_crouch(false)
	var head: Area3D=p.hitboxes[0]
	p.update_visual(.016)
	check(head.global_position.y-p.global_position.y>1.755*1.15,"Head hitbox follows the bigger model")
	# ---- Shotgun ----------------------------------------------------------
	var shotgun=NestWeaponCatalog.definition("shotgun")
	check(is_equal_approx(float(shotgun.damage_body),24) and is_equal_approx(float(shotgun.damage_shield),14.4) and NestWeaponCatalog.profile("shotgun").damage==24,"Shotgun pellet damage retains the v18 balance")
	var enemy=await add_enemy()
	for a in [p,enemy]: a.set_physics_process(false)
	enemy.global_position=Vector3(0,0,-3); enemy.health=100; enemy.shield=0; enemy.body_phase=true
	enemy.take_damage(1,"torso","bullet",false,p,7001,p.eye.global_position,"shotgun",2.0)
	check(is_equal_approx(enemy.health,100-16.0/3.0),"Shotgun body pellet on an unshielded Naki uses the new damage")
	# ---- Shield animations --------------------------------------------------
	enemy.shield=100; enemy.body_phase=false
	var fx: NestShieldFX=enemy.shield_fx
	check(fx!=null and fx.overlay!=null,"Naki actors have the shield animation layer")
	var ripples=fx.ripple_count; var breaks=fx.break_count
	enemy.take_damage(1,"torso","bullet",false,p,7002,p.eye.global_position,"rifle",5)
	await process_frame; await process_frame
	check(fx.ripple_count==ripples+1 and fx.break_count==breaks,"Shield damage plays the ripple animation")
	enemy.shield=5
	enemy.take_damage(1,"torso","bullet",false,p,7003,p.eye.global_position,"rifle",5)
	await process_frame; await process_frame
	check(fx.break_count==breaks+1 and fx.shards.emitting,"Shield depletion plays the break animation and shards")
	# ---- Tracer -------------------------------------------------------------
	var tracer=MeshInstance3D.new(); tracer.set_script(load("res://scripts/tracer.gd")); tracer.game=game; game.effects.add_child(tracer)
	tracer.setup(Vector3.ZERO,Vector3(0,0,-20))
	check(tracer.material.albedo_color.a<=.35,"Bullet traces are faint")
	# ---- Melee ---------------------------------------------------------------
	enemy.queue_free(); game.actors.erase(enemy); await physics_frame
	enemy=await add_enemy()
	enemy.set_physics_process(false)
	p.set_physics_process(true)
	p.global_position=Vector3(0,.05,0); p.rotation.y=0; p.eye.rotation.x=0; p.reset_aim(); p.cooldown=0; p.action_state="ready"
	enemy.global_position=Vector3(.6,.05,-2.75); enemy.shield=100; enemy.health=100; enemy.update_visual(.016)
	await ticks(3)
	var start=p.global_position
	check(p.melee_targets(float(game.damage_rules.melee_range_m),float(game.damage_rules.melee_cone_deg))==enemy,"Bigger melee finds a target 2.8 m away and off-centre")
	p.melee()
	check(p.lunge_ticks==NestActor.LUNGE_TICKS,"Melee starts a lunge")
	var peak_speed=0.0
	for i in range(20):
		await physics_frame; peak_speed=maxf(peak_speed,Vector2(p.velocity.x,p.velocity.z).length())
	var moved=Vector2(p.global_position.x-start.x,p.global_position.z-start.z).length()
	check(moved>.5 and moved<.75,"Lunge carries the player about two feet (%.2f m)"%moved)
	check(peak_speed>2.0,"Lunging raises movement speed briefly (%.1f m/s)"%peak_speed)
	await create_timer(.2).timeout
	check(enemy.shield<100,"Melee connects after the lunge")
	# ---- 3-round character and side swap (Extraction) -------------------------
	await new_game(0,0)
	p=game.player
	enemy=await add_enemy()
	game.scores=[2,1]
	var attacker_before=game.attacking_faction
	for round in range(3):
		game.end_round("test"); game.break_until=game.now+.001
		await ticks(3)
	check(game.round_number==4,"Rounds advance to round 4")
	check(Array(game.team_characters)==[1,0],"After 3 rounds the teams exchange characters")
	check(p.damage_model()=="annu" and enemy.damage_model()=="naki" and visual_name(p).contains("Annu"),"Players switch to the other character's model and protection")
	check(game.attacking_faction!=attacker_before,"After 3 rounds the teams exchange starting sides")
	check(Array(game.scores)==[2,1],"Scores stay with the teams through the swap")
	game._process(.016)
	check(game.hud_top.text.begins_with("ANNU"),"HUD names the team by its new character")
	check(game.protection_bars.size()==2,"Local HUD switches to the health/armor layout")
	# ---- Capture the Flag ------------------------------------------------------
	await new_game(3,0)
	p=game.player
	enemy=await add_enemy()
	for a in [p,enemy]: a.set_physics_process(false)
	game.tuning.score_limit=2
	check(game.flags.size()==2 and game.flags[0].state=="home" and game.flags[1].state=="home","Both flags start at their bases")
	check(game.flag_nodes.size()==2 and game.flag_nodes[0].flag.visible,"Flag visuals appear in Capture the Flag")
	p.global_position=game.FLAG_BASES[1]+Vector3(.5,0,0); game.update_ctf()
	check(p.flag_carry==1 and game.flags[1].state=="carried","Touching the enemy flag picks it up")
	enemy.global_position=game.FLAG_BASES[0]+Vector3(.4,0,0); game.update_ctf()
	check(enemy.flag_carry==0,"The enemy can take your flag at the same time")
	p.global_position=game.FLAG_BASES[0]+Vector3(.3,0,0); game.update_ctf()
	check(game.scores[0]==0 and p.flag_carry==1,"No capture while your own flag is away")
	enemy.global_position=Vector3(-20,7.7,-0.4); enemy.die(p,"test")
	check(game.flags[0].state=="dropped" and enemy.flag_carry==-1,"A carrier's death drops the flag")
	p.global_position=game.flags[0].pos+Vector3(.3,0,0); game.update_ctf()
	check(game.flags[0].state=="home" and p.flag_returns==1,"Touching your dropped flag returns it")
	p.global_position=game.FLAG_BASES[0]+Vector3(.3,0,0); game.update_ctf()
	check(game.scores[0]==1 and p.captures==1 and p.flag_carry==-1 and game.flags[1].state=="home","Bringing the enemy flag home captures it")
	check(game.kill_feed.any(func(item): return item.text.contains("captured")),"Captures are announced in the feed")
	var kills_score=game.scores[0]
	game.register_kill(p,enemy,"test")
	check(game.scores[0]==kills_score,"Kills do not score in Capture the Flag")
	enemy.respawn(); enemy.set_physics_process(false)
	enemy.global_position=game.FLAG_BASES[0]+Vector3(.4,0,0); game.update_ctf()
	enemy.global_position=Vector3(-20,7.7,-0.4); enemy.die(p,"test2")
	game.now+=game.FLAG_RETURN_SECONDS+.1; game.update_ctf()
	check(game.flags[0].state=="home","A dropped flag returns to base after 20 seconds")
	enemy.respawn(); enemy.set_physics_process(false)
	p.global_position=game.FLAG_BASES[1]+Vector3(.5,0,0); game.update_ctf()
	var goal=game.ctf_bot_goal(p)
	check(goal.distance_to(game.FLAG_BASES[0])<.01,"A carrying bot heads for its own base")
	p.global_position=game.FLAG_BASES[0]; game.update_ctf()
	check(game.finished and game.scores[0]==2,"Reaching the capture limit ends the match")
	game._process(.016)
	print("V012 FEATURES: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await create_timer(.3).timeout
	quit(1 if failures else 0)
