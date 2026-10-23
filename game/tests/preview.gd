extends SceneTree
var game
func _initialize(): call_deferred("run")
func snap(name):
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/work/"+name+".png")
func run():
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await snap("menu")
	game.show_lobby(); await snap("lobby")
	game.show_character(0); await snap("naki_model")
	game.show_character(1); await snap("annu_model")
	game.open_settings("main"); game.settings_tab="HUD"; game.show_settings(); await snap("settings")
	game.bot_fill=false; game.start_game(); game.create_hud(); game.clear_screen(); game.hud.visible=true; game.context="playing"
	game.player.global_position=Vector3(-13,7.1,0); game.player.rotation.y=-PI/2; game.player.eye.rotation.x=0
	await snap("gameplay")
	game.player.global_position=Vector3(-13,0.1,0)
	await snap("lower")
	quit()
