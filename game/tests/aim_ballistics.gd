extends SceneTree
# Real camera projection and real weapon/contact tests. Frozen actors in a clear
# test volume remove bot movement and map geometry from these aiming checks.
var game
var player: NestActor
var victim: NestActor
var checks: int = 0
var failures: int = 0
const ORIGIN = Vector3(90, 15, 90)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func tick(count: int = 3) -> void:
	for i in range(count):
		await physics_frame

func equip(kind: String, zero_spread: bool = true) -> NestWeapon:
	var profile: NestWeapon = load("res://resources/" + kind + ".tres").duplicate()
	if zero_spread:
		profile.spread_degrees = 0
	player.weapons.assign([profile])
	player.ammo.assign([100])
	player.reserve.assign([100])
	player.slot = 0
	player.action_state = "ready"
	player.action_until = 0
	player.cooldown = 0
	player.burst_left = 0
	if player.has_method("reset_aim"):
		player.call("reset_aim")
	return profile

func aim_at(point: Vector3) -> void:
	clear_recoil()
	var difference = point - player.eye.global_position
	player.rotation.y = atan2(-difference.x, -difference.z)
	player.eye.rotation = Vector3(atan2(difference.y, Vector2(difference.x, difference.z).length()), 0, 0)
	player.camera.rotation = Vector3.ZERO
	player.camera.position = Vector3.ZERO

func clear_recoil() -> void:
	if player.has_method("is_scoped"):
		player.set("aim_punch", Vector2.ZERO)
	player.camera.rotation = Vector3.ZERO

func reset_target(distance: float, sideways: float = 0) -> void:
	victim.global_position = ORIGIN + Vector3(sideways, 0, -distance)
	victim.rotation = Vector3.ZERO
	victim.health = 100
	victim.shield = 100
	victim.armor = 100
	victim.alive = true
	victim.last_damage = game.now
	for area in victim.hitboxes:
		area.collision_layer = 4

func target_center() -> Vector3:
	return victim.hitboxes[0].global_position

func projection_direction() -> Vector3:
	var center: Vector2 = player.camera.get_viewport().get_visible_rect().size * 0.5
	return player.camera.project_ray_normal(center).normalized()

func scoped() -> bool:
	return player.has_method("is_scoped") and player.is_scoped()

func run() -> void:
	if "host" in OS.get_cmdline_user_args() or "client" in OS.get_cmdline_user_args():
		await run_network()
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.bot_fill = false
	game.team_size = 1
	game.start_game()
	player = game.player
	player.faction = 1
	game.create_hud()
	game.hud.visible = true
	game.context = "playing"
	game.current_screen = "playing"
	game.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = ORIGIN
	victim = NestActor.new()
	victim.game = game
	victim.faction = 0
	game.add_child(victim)
	game.actors.append(victim)
	victim.set_physics_process(false)
	reset_target(10)
	network_floor()
	await tick()
	# Establish a genuine floor contact before freezing movement for subsequent
	# stationary accuracy checks. Airborne sniper accuracy intentionally differs.
	player.global_position = ORIGIN + Vector3(0, 0.08, 0)
	player.set_physics_process(true)
	await tick(20)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.controlled = Vector3.ZERO
	check(player.is_on_floor(), "The isolated aiming fixture uses a real supported standing pose")
	# Center projection must remain the aim ray at each supported aspect ratio,
	# and when looking toward the pitch limit rather than only straight ahead.
	for resolution in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(2560, 1080)]:
		root.size = resolution
		for pitch in [0.0, deg_to_rad(88)]:
			player.rotation.y = 0.65
			player.eye.rotation = Vector3(pitch, 0, 0)
			player.camera.rotation = Vector3.ZERO
			await process_frame
			check(projection_direction().distance_to(player.aim_direction()) < 0.00001,
				"Camera center and shot direction coincide at %dx%d, pitch %.0f" % [resolution.x, resolution.y, rad_to_deg(pitch)])
	root.size = Vector2i(1440, 900)
	equip("burst")
	# Fire the normal production path with spread disabled solely to isolate
	# ray/muzzle convergence. Damage must arrive at the anatomical head collider.
	for distance in [0.9, 5.0, 35.0, 120.0]:
		reset_target(distance)
		aim_at(target_center())
		await tick()
		var ray = game.trace(player.eye.global_position, player.eye.global_position + projection_direction() * 150,
			5, player.ray_exclusions())
		check(not ray.is_empty() and ray.collider is Area3D and ray.collider.get_meta("actor", null) == victim,
			"Screen center selects target geometry at %.1f meters" % distance)
		var before: int = player.ammo[0]
		player.shoot_round()
		await tick(5 if player.weapons[0].speed==0 else ceili(distance/player.weapons[0].speed*60)+5)
		check(victim.shield < 100 and victim.shield >= 80 and player.ammo[0] == before - 1,
			"Crosshair-directed projectile hits and spends one round at %.1f meters" % distance)
	# A target beside the screen center must not get hit by automatic snapping.
	reset_target(10, 2)
	player.rotation = Vector3.ZERO
	player.eye.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await tick()
	player.shoot_round()
	await tick(25)
	check(victim.shield == 100, "An off-crosshair opponent is not selected or auto-aimed")
	# Solid cover on the crosshair remains the first bullet collision, including
	# hitscan shotgun pellets. This detects camera aiming through visible walls.
	reset_target(10)
	aim_at(target_center())
	var wall = Node3D.new()
	game.add_child(wall)
	game.arena.kit.box(wall, ORIGIN + Vector3(0, 1.5, -5), Vector3(4, 4, 0.15), game.arena.kit.stone, true)
	await tick()
	player.shoot_round()
	await tick(25)
	check(victim.shield == 100, "A thin solid wall blocks a crosshair-directed projectile")
	equip("shotgun", false)
	player.shoot_round()
	await tick()
	check(victim.shield == 100, "The same wall blocks every hitscan shotgun pellet")
	wall.queue_free()
	await tick()
	# Statistical bounds and forward/vertical singularities for the actual cone
	# sampler; these catch normalized-vector errors and a systematic pellet bias.
	seed(90317)
	for direction in [Vector3.FORWARD, Vector3.UP, Vector3.DOWN]:
		var bound = deg_to_rad(5)
		var sum = Vector3.ZERO
		var bounded = true
		for i in range(3000):
			var pellet = player.cone_direction(direction, bound)
			bounded = bounded and pellet.is_finite() and absf(pellet.length() - 1) < 0.00001 and pellet.dot(direction) >= cos(bound) - 0.00001
			sum += pellet
		check(bounded and sum.normalized().dot(direction) > 0.99999,
			"All sampled pellets stay normalized, unbiased and inside the 5-degree cone for " + str(direction))
	check(player.cone_direction(Vector3.FORWARD, 0).is_equal_approx(Vector3.FORWARD),
		"Zero spread preserves the exact center ray")
	if player.has_method("is_scoped"):
		await scope_checks()
		await accuracy_and_recoil_checks()
		preferences_migration_checks()
	game.stop_game()
	game.queue_free()
	await tick()
	print("RESULT: %d aim ballistics checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func scope_checks() -> void:
	equip("rifle", false)
	player.call("toggle_scope")
	check(not scoped() and player.get("scope_level") == 0,
		"A standard rifle keeps Counter-Strike hipfire rather than generic ADS")
	# The default sniper uses its production accuracy policy, without a modified
	# resource: first and second scope levels must select the same geometric point.
	equip("sniper", false)
	player.call("toggle_scope")
	check(scoped() and player.get("scope_level") == 1, "First sniper scope level activates")
	player.call("update_aim", 1.0)
	var primary_fov=rad_to_deg(2*atan(tan(deg_to_rad(game.prefs.values.fov)*.5)/4))
	check(absf(player.camera.fov - primary_fov) < 0.001 and not player.weapon_view.visible,
		"First scope smoothly reaches four-times zoom and clears the weapon from view")
	check(is_equal_approx(player.call("current_spread_degrees"),.02), "Scoped sniper uses the specified tight .02-degree spread")
	for distance in [8.0, 75.0, 120.0]:
		reset_target(distance)
		aim_at(target_center())
		player.call("update_aim", 1.0)
		await tick()
		var ray: Dictionary = player.call("resolve_shot_aim", 150.0)
		var contact = game.trace(ray.origin, ray.origin + ray.direction * 150, 5, player.ray_exclusions())
		check(not contact.is_empty() and contact.collider is Area3D and contact.collider.get_meta("actor", null) == victim,
			"Scoped muzzle convergence selects the reticle target at %.0f meters" % distance)
		player.shoot_round()
		await tick(5 if player.weapons[0].speed==0 else ceili(distance/player.weapons[0].speed*60)+5)
		check(not victim.alive and victim.health == 0,
			"A production scoped sniper round reaches the reticle target at %.0f meters" % distance)
	player.call("toggle_scope")
	check(scoped() and player.get("scope_level") == 2, "Second sniper zoom level activates")
	player.call("update_aim", 1.0)
	check(absf(player.camera.fov - 15) < 0.001, "Second scope smoothly reaches 15 degrees")
	player.set("aim_punch", Vector2(0.01, 0.02))
	player.call("apply_aim_rotation")
	check(projection_direction().distance_to(player.aim_direction()) < 0.00001,
		"Second-zoom crosshair ray includes current visible camera recoil")
	player.call("toggle_scope")
	check(not scoped() and player.get("scope_level") == 0, "A third scope press restores hipfire")
	player.call("update_aim", 1.0)
	check(absf(player.camera.fov - game.prefs.values.fov) < 0.001 and player.weapon_view.visible,
		"Leaving scope restores normal FOV and visible weapon")
	player.call("toggle_scope")
	player.call("cancel_scope")
	check(not scoped(), "Cancelled actions release scope state")

func accuracy_and_recoil_checks() -> void:
	equip("rifle", false)
	reset_target(10, 8)
	player.rotation = Vector3.ZERO
	player.eye.rotation = Vector3.ZERO
	clear_recoil()
	var standing: float = player.call("current_spread_degrees")
	player.set_crouch(true)
	await tick()
	var crouching: float = player.call("current_spread_degrees")
	player.set_crouch(false)
	await tick()
	if player.crouched:
		var query = PhysicsShapeQueryParameters3D.new()
		var shape = CapsuleShape3D.new()
		shape.height = 1.9
		shape.radius = 0.35
		query.shape = shape
		query.transform = Transform3D(Basis(), player.global_position + Vector3(0, 0.95, 0))
		query.collision_mask = 3
		query.exclude = [player.get_rid()]
		for result in player.get_world_3d().direct_space_state.intersect_shape(query):
			print("STAND DIAGNOSTIC: position=", player.global_position, " collider=", result.collider.get_path())
	check(not player.crouched, "A clear standing volume lets the aiming fixture leave crouch")
	player.velocity = Vector3(6, 0, 0)
	var running: float = player.call("current_spread_degrees")
	player.velocity = Vector3.ZERO
	check(standing > 0 and crouching < standing and is_equal_approx(running,standing),
		"Rifle retains stationary accuracy while moving and still gains a crouch bonus")
	player.velocity=Vector3(4,7,2)
	check(is_equal_approx(player.current_spread_degrees(),standing),"Rifle has no jumping or strafing accuracy penalty")
	player.velocity=Vector3.ZERO
	player.shoot_round()
	var kicked: Vector2 = player.get("aim_punch")
	check(kicked.y > 0 and player.call("current_spread_degrees") > standing,
		"A rifle shot adds upward recoil and a temporary spray accuracy penalty")
	check(projection_direction().distance_to(player.aim_direction()) < 0.00001,
		"A visible recoil kick remains aligned with the exact camera-center aim ray")
	game.now += 1
	player.call("update_aim", 0.5)
	var recovered: Vector2 = player.get("aim_punch")
	check(recovered.length() < kicked.length() * 0.05 and absf(player.call("current_spread_degrees") - standing) < 0.00001,
		"Stopping fire recovers recoil and restores first-shot rifle accuracy")
	# Sustain the production fire_trigger cadence while advancing real-sized aim
	# updates between shots. Recovery during each interval must not erase bloom.
	var spray_spreads: Array[float] = []
	await process_frame;await process_frame
	var initial_ammo = player.ammo[0]
	for shot in range(5):
		player.fire_trigger()
		spray_spreads.append(player.call("current_spread_degrees"))
		if shot < 4:
			for frame in range(6):
				var step = player.weapons[0].interval / 6.0 + 0.00001
				game.now += step
				player.call("update_aim", step)
				await process_frame
	check(player.ammo[0] == initial_ammo - 5 and spray_spreads[2] > spray_spreads[0] + 0.25 and spray_spreads[4] > spray_spreads[2] + 0.25,
		"Five sustained rifle shots accumulate bloom through their normal firing intervals")
	game.now += 0.5
	player.call("update_aim", 0.5)
	check(absf(player.call("current_spread_degrees") - standing) < 0.00001,
		"Stopping a sustained rifle spray restores the stationary first-shot spread")
	player.eye.rotation.x = deg_to_rad(88.8)
	player.set("aim_punch", Vector2(0.01, deg_to_rad(3)))
	player.call("apply_aim_rotation")
	check(absf(asin(clampf(player.aim_direction().y,-1,1))) <= deg_to_rad(89) + 0.00001 and player.aim_direction().is_finite(),
		"Recoil at the pitch limit stays finite and cannot overturn the camera")
	player.eye.rotation.x = 0
	clear_recoil()

func network_floor() -> void:
	var stage = Node3D.new()
	game.add_child(stage)
	game.arena.kit.box(stage, ORIGIN + Vector3(0, -0.2, -5), Vector3(20, 0.4, 40), game.arena.kit.stone, true)

func preferences_migration_checks() -> void:
	# Back up the exact file bytes and restore them before returning. Run with an
	# isolated XDG_DATA_HOME during QA so parallel native sessions cannot race it.
	var had_file = FileAccess.file_exists(NestPreferences.PATH)
	var original = FileAccess.get_file_as_bytes(NestPreferences.PATH) if had_file else PackedByteArray()
	var old = ConfigFile.new()
	old.set_value("meta", "schema", 1)
	old.set_value("personal", "sensitivity", 0.14)
	old.set_value("personal", "aim_sensitivity", 0.65)
	old.set_value("personal", "invert_y", true)
	old.set_value("personal", "fov", 95.0)
	old.set_value("personal", "crosshair", false)
	old.set_value("bindings", "jump", KEY_J)
	var written = old.save(NestPreferences.PATH)
	check(written == OK, "A schema 1 preferences fixture can be saved")
	if written != OK:
		return
	var migrated = NestPreferences.new()
	migrated.load_saved()
	check(absf(deg_to_rad(migrated.values.sensitivity * 0.022) - 0.14 * 0.01) < 0.0000001,
		"An existing sensitivity preserves its physical mouse turn distance")
	check(migrated.values.invert_y and migrated.values.fov == 95 and not migrated.values.crosshair and migrated.keys.jump == KEY_J and migrated.values.aim_sensitivity == 0.65,
		"Sensitivity migration preserves other aiming, display and key settings")
	check(migrated.save() == OK, "Migrated preferences save in the current schema")
	var new_cfg = ConfigFile.new()
	new_cfg.load(NestPreferences.PATH)
	var reloaded = NestPreferences.new()
	reloaded.load_saved()
	check(new_cfg.get_value("meta", "schema", 0) == 4 and absf(reloaded.values.sensitivity - migrated.values.sensitivity) < 0.00001,
		"Reloading current schema does not convert the sensitivity a second time")
	var legacy_max = rad_to_deg(0.5 * 0.01) / 0.022
	reloaded.values.sensitivity = legacy_max
	reloaded.validate()
	check(absf(reloaded.values.sensitivity - legacy_max) < 0.00001,
		"The previous maximum legal sensitivity fits the new preference range")
	if had_file:
		var restored = FileAccess.open(NestPreferences.PATH, FileAccess.WRITE)
		if restored:
			restored.store_buffer(original)
			restored.close()
		check(FileAccess.get_file_as_bytes(NestPreferences.PATH) == original, "The original preference file is restored byte for byte")
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(NestPreferences.PATH))
		check(not FileAccess.file_exists(NestPreferences.PATH), "The temporary preference file is removed after migration checks")
	game.prefs.apply()

func network_wall() -> void:
	var cover = Node3D.new()
	game.add_child(cover)
	game.arena.kit.box(cover, ORIGIN + Vector3(0, 1.5, -5), Vector3(4, 4, 0.15), game.arena.kit.stone, true)

func run_network() -> void:
	var host_role = "host" in OS.get_cmdline_user_args()
	var role = "host" if host_role else "client"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.bot_fill = false
	game.team_size = 1
	game.mode = 2
	game.tuning.round_seconds = 600
	if host_role:
		check(game.host_direct(17880, "AimHost", 0) == OK, "Aim test host opens a direct UDP session")
	else:
		check(game.join_direct("127.0.0.1", 17880, "AimClient", 1) == OK, "Aim test client begins direct-IP connection")
	var timeout = Time.get_ticks_msec() + 20000
	while game.lobby_members.size() < 2 and Time.get_ticks_msec() < timeout:
		await process_frame
	check(game.lobby_members.size() == 2, "Both players join the aiming test lobby")
	if game.lobby_members.size() < 2:
		quit(1)
		return
	if host_role:
		game.start_game()
		network_floor()
		game.context = "pause"
		for actor in game.actors:
			actor.global_position = ORIGIN + Vector3(0, 0.03, -10 if actor.remote_peer == 1 else 0)
			actor.rotation = Vector3.ZERO
			actor.eye.rotation = Vector3.ZERO
			actor.weapons.assign([load("res://resources/sniper.tres")])
			actor.ammo.assign([4])
			actor.reserve.assign([12])
			actor.slot = 0
		await create_timer(2).timeout
		network_wall()
		await create_timer(2).timeout
		var remote: NestActor
		for actor in game.actors:
			if actor.remote_peer > 1:
				remote = actor
		check(game.player.shield == 0 and game.player.health == 100,
			"Server applies one scoped hit and receives no hit through cover")
		check(remote != null and remote.ammo[0] == 2, "Server owns ammunition for both scoped shots")
		check(game.shot_authorizations.size() == 2, "Both scoped shots require ordinary shot authorization")
		await create_timer(0.7).timeout
	else:
		while not game.running and Time.get_ticks_msec() < timeout:
			await process_frame
		check(game.running, "Host start creates the aiming test match")
		network_floor()
		await create_timer(0.8).timeout
		player = game.player
		victim = game.actor_by_id(1)
		check(player.weapons.size() == 1 and player.weapons[0].kind == "sniper",
			"The host-provided sniper loadout reaches the owner")
		if not player.has_method("is_scoped"):
			check(false, "Scoped aiming API exists")
		else:
			player.call("toggle_scope")
			await create_timer(0.25).timeout
			aim_at(target_center())
			check(scoped() and projection_direction().distance_to(player.aim_direction()) < 0.00001,
				"Network owner aims from the active scoped camera center")
			player.fire_trigger()
			await create_timer(0.6).timeout
			check(victim.shield == 0 and player.ammo[0] == 3,
				"A scoped owner-view hit returns as authoritative damage and ammo")
			network_wall()
			player.call("toggle_scope")
			await create_timer(0.6).timeout
			aim_at(target_center())
			player.fire_trigger()
			await create_timer(0.6).timeout
			check(victim.health == 100 and player.ammo[0] == 2,
				"A second scoped shot consumes ammo while cover prevents damage")
			await create_timer(2).timeout
	print("RESULT " + role + ": %d network aim checks, %d failures" % [checks, failures])
	game.stop_game()
	game.close_connection()
	game.queue_free()
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
