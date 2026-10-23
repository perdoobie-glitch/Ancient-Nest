extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 assert("--light-mode" in OS.get_cmdline_user_args())
 assert(game.prefs.values.graphics_quality==0 and not game.prefs.values.shadows)
 assert(game.prefs.values.antialiasing==1 and is_equal_approx(game.prefs.values.render_scale,1.0))
 assert(Engine.physics_ticks_per_second==60)
 assert(is_equal_approx(root.scaling_3d_scale,1.0) or game.prefs.values.fullscreen)
 print("PASS: Light launch applies Low/full-resolution/AA off/shadows off; physics remains 60 Hz")
 game.queue_free();for i in range(5):await process_frame
 quit()
