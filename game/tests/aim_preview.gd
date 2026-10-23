extends SceneTree
var game
func _initialize(): call_deferred("run")
func frames(count=12):
	for i in range(count): await process_frame
func snap(name):
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/work/"+name+".png")
func scope_press():
	var e=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_RIGHT; e.pressed=true; Input.parse_input_event(e)
	e=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_RIGHT; e.pressed=false; Input.parse_input_event(e)
func run():
	root.size=Vector2i(1440,900); root.grab_focus()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
	game.bot_fill=false; game.start_game(); game.clear_screen(); game.current_screen="playing";game.context="playing";game.create_hud();game.hud.visible=true
	game.player.global_position=Vector3(-13,7.1,0); game.player.rotation.y=-PI/2; game.player.eye.rotation.x=0
	var target=NestActor.new(); target.game=game;target.faction=1;target.username="Aim target";game.add_child(target); game.actors.append(target);target.global_position=Vector3(6,7.1,0);target.rotation.y=PI/2;target.set_physics_process(false)
	await frames(8)
	var difference=target.hitboxes[0].global_position-game.player.camera.global_position
	game.player.eye.rotation.x=atan2(difference.y,Vector2(difference.x,difference.z).length())
	game.capture_mouse();await snap("aim_hipfire")
	game.player.weapons.assign([load("res://resources/sniper.tres")]);game.player.ammo.assign([4]);game.player.reserve.assign([12]);game.player.slot=0;game.player.reset_aim()
	scope_press();await snap("aim_scope1")
	scope_press();await snap("aim_scope2")
	game.show_pause();await snap("aim_pause")
	print("AIM PREVIEW COMPLETE");quit()
