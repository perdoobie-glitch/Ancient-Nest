extends SceneTree
var game
func _initialize(): call_deferred("run")
func snap(name):
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/work/"+name+".png")
func run():
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true; game.context="playing"
	for i in range(12): await physics_frame
	game.set_physics_process(false); var player=game.player; player.set_physics_process(false)
	player.global_position=Vector3(-13,7.06,-17); player.rotation.y=-PI/2; player.eye.rotation.x=-.10; player.reset_physics_interpolation()
	var target=NestActor.new(); target.game=game; target.faction=0; game.add_child(target); game.actors.append(target)
	target.set_physics_process(false); target.global_position=Vector3(-9,7.06,-17); target.rotation.y=PI/2; target.reset_physics_interpolation()
	player.update_visual(.016); target.update_visual(.016); await snap("feedback_hold")
	player.ammo[0]=4; player.reload_weapon(); target.ammo[0]=4; target.reload_weapon()
	game.now=player.action_until-player.weapons[0].reload_seconds*.55
	player.update_visual(.016); target.update_visual(.016); await snap("feedback_reload")
	player.action_state="ready"; target.action_state="ready"; player.flash_until=game.now+.15; target.flash_until=game.now+.15
	player.update_visual(.016); target.update_visual(.016); await snap("feedback_fire")
	player.flash_until=-100; target.flash_until=-100; game.now+=.1
	player.take_damage(45,"torso","bullet",false,null,80001); target.take_damage(45,"torso","bullet",false,null,80002)
	player.update_visual(.016); target.update_visual(.016); await snap("feedback_shield_hit")
	game.now+=.25; player.take_damage(60,"torso","bullet",false,null,80003); target.take_damage(60,"torso","bullet",false,null,80004)
	player.update_visual(.016); target.update_visual(.016); await snap("feedback_shield_break")
	print("FEEDBACK PREVIEW COMPLETE"); game.stop_game(); game.queue_free(); await process_frame; quit()
