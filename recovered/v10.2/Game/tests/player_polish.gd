extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func ticks(n=3):
	for i in range(n):await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.bot_fill=false;game.mode=1;game.selected_faction=0;game.starting_primary="default";game.starting_secondary="default";game.fair_playing_field=false;game.start_game();game.set_physics_process(false);game.player.set_physics_process(false)
	var player=game.player;player.global_position=Vector3(80,25,80)
	var enemy=NestActor.new();enemy.game=game;enemy.username="RecapEnemy";enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.respawn();enemy.set_physics_process(false);enemy.global_position=Vector3(80,25,75)
	check(player.shield==200 and game.tuning.shield_capacity==200,"Naki spawn has doubled 200-point shields")
	game.fair_playing_field=true;game.fair_health_type="naki";enemy.respawn();enemy.set_physics_process(false);enemy.global_position=Vector3(80,25,75)
	check(enemy.shield==200,"Shared Naki protection also starts at 200")
	enemy.take_damage(1,"torso","bullet",false,player,game.next_event(),Vector3.INF,"burst",0)
	player.take_damage(1,"torso","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	for i in range(3):player.take_damage(1,"torso","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	player.take_damage(1,"head","bullet",false,enemy,game.next_event(),Vector3.INF,"ak47",0)
	check(not player.alive and player.death_recap.killer=="RecapEnemy","Death records the actual killer")
	check(player.death_recap.taken.damage==300 and player.death_recap.taken.hits==5,"Recap includes actual shield and health loss, not overkill")
	check(player.death_recap.given.damage==20 and player.death_recap.given.hits==1,"Recap includes damage dealt to this killer life")
	check(game.messages.back().contains("Damage taken: 100/100") and player.death_recap_text().contains("Damage given: 7/100"),"Death recap is readable text and a private local message")
	var messages=game.messages.size();game.display_death_recap(player);check(game.messages.size()==messages,"Repeated delivery cannot duplicate the recap message")
	player.respawn();check(player.death_recap.is_empty() and player.damage_received.is_empty() and player.damage_given.is_empty(),"Respawn resets this-life damage tracking")
	game.audio.sound_started.connect(func(id,_file,_voice):game.set_meta("heard",id))
	player.global_position=Vector3(80,25,80);player.camera.current=true
	game.set_meta("heard","");game.audio.play_sound("bullet_impact_metal",player.camera.global_position+Vector3.RIGHT*5)
	check(game.get_meta("heard")=="","Bullet contact audio beyond 15 feet is suppressed")
	game.audio.play_sound("bullet_impact_metal",player.camera.global_position+Vector3.RIGHT*4)
	check(game.get_meta("heard")=="bullet_impact_metal","Nearby contact still makes a subtle sound")
	check(game.audio.manifest.sounds.jump.volume_db<=-31 and game.audio.manifest.sounds.footstep_concrete_land_soft.volume_db<=-33,"Jump and land effects are substantially quieter")
	check(game.arena.pads.size()==12 and game.pad_stock[6]==1,"Six additional weapon placements stock at round start")
	var index=6;player.global_position=game.arena.pads[index]+Vector3.UP*.05;var before=player.weapons.size()
	game._physics_process(.01);check(player.weapons.size()==before and game.pad_stock[index]==1,"Walking over a weapon cannot collect it")
	var choice=game.interaction_for(player);check(choice.get("key","")=="pickup:6" and choice.text.contains("Press E"),"Nearby weapon exposes the Use-action prompt")
	check(game.complete_interaction(player,choice) and game.pad_stock[index]==0,"Use action consumes exactly one weapon pad")
	check(not game.complete_interaction(player,choice),"Repeated pickup completion cannot duplicate a weapon")
	game.now=149.9;game._physics_process(.01);check(game.pad_stock[index]==0,"Taken weapon stays unavailable before 150 seconds")
	game.now=150;player.global_position=Vector3(80,25,80);game._physics_process(.01);check(game.pad_stock[index]==1,"Weapon respawns at two minutes thirty seconds")
	game.now=180;game.reset_round();check(game.pad_stock[index]==1 and game.pad_next==330,"Next round immediately stocks weapons and restarts their schedule")
	check(absf(2*game.tuning.jump_speed/game.tuning.gravity-1.33)<.01,"Jump airtime is five percent shorter with the same two-metre apex")
	check(absf(game.tuning.jump_speed*game.tuning.jump_speed/(2*game.tuning.gravity)-2)<.01,"Shorter airtime preserves jump height")
	for difficulty in ["easy","normal","hard"]:
		game.bot_difficulty=difficulty;game.save_custom_preset();game.bot_difficulty="normal";game.load_custom_preset();check(game.bot_difficulty==difficulty,"Bot difficulty persists: "+difficulty)
	var easy=game.bot_difficulty_rules.easy;var hard=game.bot_difficulty_rules.hard
	check(easy.reaction_seconds>hard.reaction_seconds and easy.aim_error_m>hard.aim_error_m,"Difficulty changes reaction and accuracy without changing protection")
	check(game.arena.solid_art_bodies.size()>8,"Visible ore, shuttle and foundation geometry has solid collision")
	for i in range(2):
		game.arena.deposits[i].visible=true;game.arena.set_site_visual(i,"sealed",game.now);check(game.arena.sealed_bodies[i].all(func(b):return b.collision_layer==1),"Sealed ore has solid hulls")
		game.arena.set_site_visual(i,"off",game.now);check(game.arena.sealed_bodies[i].all(func(b):return b.collision_layer==0),"Invisible sealed ore cannot leave a phantom collider")
	print("PLAYER POLISH: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await create_timer(.3).timeout;quit(1 if failures else 0)
