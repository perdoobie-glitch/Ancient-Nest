extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.start_game(); game.context="playing"
	game.player.global_position=Vector3(-29,0.06,11); game.player.rotation.y=0; game.player.controlled=Vector3.ZERO
	for i in range(8): await physics_frame
	Input.action_press("forward")
	for i in range(400):
		await physics_frame
		if i%30==0: print("RAMP ",i," ",game.player.global_position," ",game.player.velocity," floor ",game.player.is_on_floor())
	quit()
