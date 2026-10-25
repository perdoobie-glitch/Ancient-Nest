extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var mm = game.matchmaking
	var bridge = mm.hybrid
	mm.set_process(false)
	bridge.set_process(false)
	bridge.session.set_process(false)
	mm.active = true
	mm.party_mode = true
	mm.local_slot = 3
	mm.phase = "loading"
	bridge.enabled = true
	bridge.authority = true
	bridge.staged = true
	bridge.session.frozen = true
	mm.configure_rules(2, 0)
	var members = {
		2: {"name":"Remote", "faction":0, "character":-1, "peer":2},
		3: {"name":"Host", "faction":1, "character":-1, "peer":1}
	}
	game.begin_network_match(game.active_config(), members)
	check(is_instance_valid(game.player) and game.player.net_id == 3, "host owns stable roster slot, not transport peer ID")
	check(game.get_viewport().get_camera_3d() == game.player.camera, "spawn selects first-person camera")
	# The loading UI legitimately takes over while simulation is frozen.
	game.matchmaking_ui_changed()
	check(game.get_viewport().get_camera_3d() == game.menu_camera, "frozen loading screen selects overhead menu camera")
	bridge.session.frozen = false
	bridge.resume_game(1)
	await process_frame
	check(game.get_viewport().get_camera_3d() == game.player.camera, "host resume restores first-person camera after loading UI")
	check(game.current_screen == "playing" and game.hud.visible, "resume restores gameplay HUD")
	# Rejoin/migration can take over presentation again for either role.
	game.menu_camera.make_current()
	bridge.authority = false
	bridge.resume_game(2)
	check(game.get_viewport().get_camera_3d() == game.player.camera, "client resume also restores first-person camera")
	bridge.enabled = false
	game.stop_game()
	game.queue_free()
	await process_frame
	print("MATCHMAKING_CAMERA_RESUME failures=", failures)
	quit(0 if failures == 0 else 1)
