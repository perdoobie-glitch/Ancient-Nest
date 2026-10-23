extends SceneTree
func _initialize():
	var noise=FastNoiseLite.new(); noise.seed=17391; noise.frequency=.035
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var tile=noise.get_seamless_image(256,256)
	tile.save_png("res://assets/stone_noise.png")
	quit()
