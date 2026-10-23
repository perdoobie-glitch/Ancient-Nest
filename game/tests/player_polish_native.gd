extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func frames(n=4):
	for i in range(n):await process_frame
func capture(name):
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/v07-"+name+".png")
func run():
	root.size=Vector2i(1440,900);game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(12)
	check(game.menu_music!=null and game.menu_music.playing,"Original menu music plays in main menu")
	game.open_settings("main");await frames();check(not game.menu_music.playing,"Music stops in settings")
	game.bot_fill=false;game.mode=2;game.fair_playing_field=false;game.selected_faction=0;game.starting_primary="default";game.starting_secondary="default";game.show_lobby();await frames()
	var difficulty=game.screen.find_child("BotDifficulty",true,false);check(difficulty!=null and difficulty.item_count==3,"Lobby shows Easy / Normal / Hard difficulty")
	difficulty.select(2);difficulty.item_selected.emit(2);check(game.bot_difficulty=="hard","Difficulty selector applies the actual host setting")
	check(game.menu_music.playing,"Music plays in Custom Lobby");await capture("lobby")
	game.begin_match();await frames(8);check(not game.menu_music.playing,"Menu music stops on match start")
	check(game.protection_bars[0].max_value==200 and game.protection_bars[0].value==200,"Shield HUD correctly displays the full 200-point capacity")
	game.set_physics_process(false);var player=game.player;player.set_physics_process(false);player.global_position=Vector3(80,25,80);player.rotation=Vector3.ZERO;player.eye.rotation=Vector3.ZERO;player.reset_physics_interpolation();player.apply_aim_rotation()
	var ally=NestActor.new();ally.game=game;ally.faction=0;ally.username="Ally";game.add_child(ally);game.actors.append(ally);ally.set_physics_process(false);ally.global_position=Vector3(80,25,70);ally.kills=7;ally.deaths=2;ally.assists=3
	var wall=Node3D.new();game.add_child(wall);game.arena.kit.box(wall,Vector3(80,26.6,75),Vector3(4,4,.4),game.arena.kit.stone,true);await frames()
	check(not game.trace(player.camera.global_position,ally.global_position+Vector3.UP*1.4,1).is_empty() and game.teammate_markers.marker_positions().size()==1,"Teammate arrow remains visible through a real occluding wall")
	game.mode=1;check(game.teammate_markers.marker_positions().is_empty(),"Slayer has no false teammate markers");game.mode=2
	ally.alive=false;check(game.teammate_markers.marker_positions().is_empty(),"Dead allies lose their arrow");ally.alive=true;wall.queue_free();await frames()
	Input.action_press("scoreboard");game.scoreboard.visible=true;game.scoreboard.refresh(true);await frames();check(game.scoreboard.stats_for(ally)==[7,2,3,7],"Scoreboard places the actual kills, deaths, assists and mode points")
	check(game.scoreboard.role_for(ally)=="BOT" and game.scoreboard.role_for(player)=="YOU","Scoreboard labels local player and bots correctly")
	check(game.scoreboard.find_children("*","HBoxContainer",true,false).size()>=4,"Scoreboard uses aligned columns, not padded proportional text");await capture("scoreboard");Input.action_release("scoreboard");game.scoreboard.visible=false
	ally.faction=1;ally.armor=100;ally.health=100;game.now+=1;ally.take_damage(20,"torso","bullet",false,player,game.next_event());ally.update_visual(.016);await frames()
	check(ally.presentation.hit_electricity.visible and ally.presentation.hit_electricity.pulse_count>0,"Shooter can see localized electrical target contact")
	check(ally.presentation.hit_electricity.mesh.get_surface_count()==1 and ally.model.find_children("EnergyShieldShell","MeshInstance3D",true,false).is_empty(),"Electrical lines replace the full shield envelope")
	await capture("electrical-hit")
	game.fair_playing_field=true;game.fair_health_type="naki";ally.shield=20;ally.update_visual(.016);check(ally.presentation.hit_electricity.low_shield,"Low Naki shields retain the small amber warning")
	player.shield=0;player.body_phase=true;player.take_damage(500,"head","bullet",false,ally,game.next_event());await frames();check(game.hud_death_recap.text.contains("Killed by Ally") and game.hud_death_recap.text.contains("You took:"),"Death recap appears in the real HUD independently of chat")
	await capture("death-recap")
	game.stop_game();game.show_main();await frames();check(game.menu_music.playing,"Returning to main menu restores music")
	print("PLAYER POLISH NATIVE: %d checks, %d failures"%[checks,failures]);game.queue_free();await create_timer(.3).timeout;quit(1 if failures else 0)
