extends SceneTree
var game
func _initialize(): call_deferred("run")
func frames(count=5):
	for i in range(count): await process_frame
func snap(name):
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/work/v04_"+name+".png")
func run():
	root.size=Vector2i(1440,900); game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await frames()
	game.show_lobby()
	var diagram=game.screen.find_children("*","Control",true,false).filter(func(n):return n is NestMapPreview)[0]
	for level in range(3): diagram.level=level; diagram.queue_redraw(); await snap("layout_"+str(level))
	game.bot_fill=false; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true; game.context="playing"
	await frames(); game.set_physics_process(false); var player=game.player; player.set_physics_process(false)
	for item in [["bottom",Vector3(-29,.08,9),-PI/2],["middle",Vector3(-13,7.08,-17),-PI/2],["top",Vector3(-5,14.08,8),-PI/2]]:
		player.global_position=item[1]; player.rotation.y=item[2]; player.eye.rotation.x=-.06; player.reset_physics_interpolation(); player.update_visual(.016); await snap(item[0])
	player.global_position=Vector3(10,7.08,-3); player.rotation.y=atan2(-6,-3); player.eye.rotation.x=-.1; player.reset_physics_interpolation(); player.update_visual(.016)
	game.impact(game.arena.sites[0]+Vector3.UP,Vector3.UP,true)
	for blast in game.effects.find_children("BombExplosionFX*","Node3D",true,false): blast.set_process(false); blast._process(.22)
	await snap("bomb")
	game.clear_effects(); game.arena.set_site_visual(0,"drilling",game.now); await frames(10); await snap("drill")
	player.shield=100; player.reset_damage_visual(); player.take_damage(12,"torso","bullet",false,null,93101,player.camera.global_position+player.camera.global_basis.x*5); await snap("damage_right")
	player.reset_damage_visual(); player.take_damage(12,"torso","bullet",false,null,93102,player.camera.global_position-player.camera.global_basis.x*5); await snap("damage_left")
	player.reset_damage_visual(); player.global_position=Vector3(-13,7.04,-17); player.rotation.y=-PI/2; player.eye.rotation.x=-.08; player.reset_physics_interpolation(); player.update_visual(.016)
	var target=NestActor.new(); target.game=game; target.faction=0; game.add_child(target); game.actors.append(target); target.set_physics_process(false)
	target.global_position=Vector3(-9,7.02,-17); target.rotation.y=PI/2; target.reset_physics_interpolation()
	for amount in [100,50,18]:
		target.shield=amount; target.update_visual(.016); await snap("shield_"+str(amount))
	player.reset_damage_visual(); player.shield=100
	for amount in [100,75,25]:
		player.health=amount; await snap("health_"+str(amount))
	game.stop_game(); await frames(3); game.selected_faction=1; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true
	var annu=game.player; annu.set_physics_process(false); annu.global_position=Vector3(-13,7.08,-17); annu.rotation.y=-PI/2; annu.eye.rotation.x=-.06; annu.reset_physics_interpolation(); annu.update_visual(.016); await snap("ak47")
	annu.ammo[0]=12; annu.reload_weapon(); game.now=annu.action_until-annu.weapons[0].reload_seconds*.55; annu.update_visual(.016); await snap("ak47_reload")
	game.stop_game(); game.queue_free(); await frames(2)
	# Allow the audio mixer to release the interrupted reload before engine exit.
	await create_timer(.75).timeout
	print("EXPANSION PREVIEW COMPLETE"); quit()
