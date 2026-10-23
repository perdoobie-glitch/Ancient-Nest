extends SceneTree
# End-to-end input routing: inject events through Godot's Input singleton, never
# call the actor's look handler. This catches GUI Controls swallowing mouse aim.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func mouse_motion(delta: Vector2, point: Vector2 = Vector2(-1, -1), viewport_delta: Vector2 = Vector2.INF) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.size * 0.5 if point.x < 0 else point
	event.global_position = event.position
	event.relative = delta if viewport_delta == Vector2.INF else viewport_delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	await frames(2)

func mouse_button(index: MouseButton, pressed: bool, point: Vector2 = Vector2(-1, -1)) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.size * 0.5 if point.x < 0 else point
	event.global_position = event.position
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func tap_key(code: Key) -> void:
	await key(code, true)
	await key(code, false)

func text_input(text: String) -> void:
	for i in range(text.length()):
		var character := text.substr(i, 1)
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = character.to_upper().unicode_at(0)
		event.physical_keycode = event.keycode
		event.pressed = true
		Input.parse_input_event(event)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await frames(3)

func yaw_change(before: float) -> float:
	return angle_difference(before, game.player.rotation.y)

func right_click() -> void:
	await mouse_button(MOUSE_BUTTON_RIGHT, true)
	await mouse_button(MOUSE_BUTTON_RIGHT, false)

func scope_input_checks(actor) -> void:
	var old_scope_ratio: float = game.prefs.values.aim_sensitivity
	game.prefs.values.aim_sensitivity = 0.2
	await mouse_button(MOUSE_BUTTON_RIGHT, true)
	var before: float = actor.rotation.y
	await mouse_motion(Vector2(100, 0))
	check(actor.scope_level == 0 and absf(actor.camera.fov - game.prefs.values.fov) < 0.01, "Right mouse on the rifle keeps Counter-Strike hip aim without universal zoom")
	check(absf(absf(yaw_change(before)) - deg_to_rad(4.4)) < 0.00001, "Holding right mouse on a rifle does not reduce hip mouse sensitivity")
	await mouse_button(MOUSE_BUTTON_RIGHT, false)
	actor.weapons[0] = load("res://resources/sniper.tres")
	actor.ammo[0] = 4
	actor.reserve[0] = 12
	actor.slot = 0
	actor.action_state = "ready"
	await frames(3)
	await tap_key(KEY_Z)
	check(actor.scope_level==1,"The routed Z Zoom control activates sniper scope")
	await tap_key(KEY_Z)
	check(actor.scope_level==2,"The routed Zoom control advances to second zoom")
	await tap_key(KEY_Z)
	check(actor.scope_level==0,"The routed Zoom control cycles back to hipfire")
	await right_click()
	await frames(20)
	check(actor.scope_level == 1 and actor.is_scoped(), "A routed right-click enables the sniper's first scope")
	var first_fov=rad_to_deg(2*atan(tan(deg_to_rad(game.prefs.values.fov)*.5)/5))
	check(absf(actor.camera.fov - first_fov) < 1 and not actor.weapon_view.visible, "First scope settles to five-times zoom and hides the view weapon")
	before = actor.rotation.y
	var expected_angle: float = deg_to_rad(4.4) * tan(deg_to_rad(actor.camera.fov)*.5) / tan(deg_to_rad(game.prefs.values.fov)*.5) * game.prefs.values.aim_sensitivity * game.prefs.values.zoom_feel_tweak
	await mouse_motion(Vector2(100, 0))
	check(absf(absf(yaw_change(before)) - expected_angle) < 0.00001, "Scoped aiming uses the tangent FOV ratio and configured zoom sensitivity")
	await right_click()
	await frames(20)
	check(actor.scope_level == 2 and absf(actor.camera.fov - rad_to_deg(2*atan(tan(deg_to_rad(game.prefs.values.fov)*.5)/15))) < 1, "Second routed right-click cycles to the fifteen-times scope")
	await right_click()
	await frames(20)
	check(actor.scope_level == 0 and absf(actor.camera.fov - game.prefs.values.fov) < 1 and actor.weapon_view.visible, "Third routed right-click returns to hip aim and restores the weapon")
	await right_click()
	await tap_key(KEY_ESCAPE)
	check(game.context == "pause" and actor.scope_level == 0, "Opening pause exits sniper scope")
	await tap_key(KEY_ESCAPE)
	await right_click()
	await tap_key(KEY_ENTER)
	check(game.context == "chat" and actor.scope_level == 0, "Opening chat exits sniper scope")
	await tap_key(KEY_ESCAPE)
	await right_click()
	actor.ammo[0] = 2
	await tap_key(KEY_R)
	check(actor.action_state == "reloading" and actor.scope_level == 0, "A routed reload exits sniper scope")
	actor.action_until = game.now
	await frames(4)
	await right_click()
	await mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	await mouse_button(MOUSE_BUTTON_WHEEL_UP, false)
	check(actor.slot == 1 and actor.scope_level == 0, "A routed weapon wheel change exits sniper scope")
	actor.reset_loadout()
	game.prefs.values.aim_sensitivity = old_scope_ratio
	await frames(20)

func run() -> void:
	root.size=Vector2i(800,500)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.grab_focus()
	await frames(8)
	game.starting_primary="default"; game.starting_secondary="default"; game.selected_faction=0; game.fair_playing_field=false
	game.bot_fill = false
	game.team_size = 1
	game.mode = 2
	game.tuning.round_seconds = 600
	game.prefs.values.invert_y = false
	game.prefs.values.chat = true
	game.show_lobby()
	await frames(3)
	game.begin_match()
	await frames(15)
	check(game.running and game.current_screen == "playing" and game.player.input_active(), "Starting from the real lobby activates player input")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Match start captures the mouse")
	var actor = game.player
	var previous = actor.rotation.y
	await mouse_motion(Vector2(40, 0))
	check(yaw_change(previous) < -0.0001, "Horizontal mouse event routed through the GUI turns right")
	previous = actor.rotation.y
	await mouse_motion(Vector2(-40, 0), Vector2(20, 400))
	check(yaw_change(previous) > 0.0001, "Mouse look also works away from the center crosshair")
	var pitch_before: float = actor.eye.rotation.x
	await mouse_motion(Vector2(0, -30))
	check(actor.eye.rotation.x > pitch_before + 0.0001, "Upward mouse movement aims above the horizon")
	pitch_before = actor.eye.rotation.x
	await mouse_motion(Vector2(0, 30))
	check(actor.eye.rotation.x < pitch_before - 0.0001, "Downward mouse movement aims below the horizon")
	previous = actor.rotation.y
	await key(KEY_TAB, true)
	await frames(3)
	check(game.scoreboard.visible, "Holding Tab opens the real scoreboard")
	await mouse_motion(Vector2(30, 0))
	check(yaw_change(previous) < -0.0001, "A visible scoreboard cannot block captured mouse look")
	await key(KEY_TAB, false)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0), game.radar.get_global_rect().get_center())
	check(yaw_change(previous) < -0.0001, "The radar cannot block captured mouse look")
	# Counter-Strike convention: sensitivity 2.0 at 0.022 degrees per count.
	game.prefs.values.sensitivity = 2.0
	previous = actor.rotation.y
	await mouse_motion(Vector2(100, 0))
	check(absf(absf(yaw_change(previous)) - deg_to_rad(4.4)) < 0.00001, "Sensitivity 2.0 turns exactly 4.4 degrees per 100 raw mouse counts")
	previous = actor.rotation.y
	await mouse_motion(Vector2(100, 0), Vector2(-1, -1), Vector2(10, 0))
	check(absf(absf(yaw_change(previous)) - deg_to_rad(4.4)) < 0.00001, "Unscaled screen counts keep aiming consistent despite viewport scaling")
	var first_step: float = actor.rotation.y
	for i in range(10):
		await mouse_motion(Vector2(10, 0))
	check(absf(absf(yaw_change(first_step)) - deg_to_rad(4.4)) < 0.00001, "Ten small mouse events turn the same angle as one large event")
	game.prefs.values.invert_y = true
	pitch_before = actor.eye.rotation.x
	await mouse_motion(Vector2(0, -30))
	check(actor.eye.rotation.x < pitch_before - 0.0001, "Invert Y reverses the pitch direction")
	game.prefs.values.invert_y = false
	await mouse_motion(Vector2(0, -100000))
	check(actor.eye.rotation.x < PI / 2 and actor.eye.rotation.x > deg_to_rad(80), "Large upward motion clamps below vertical and prevents camera flipping")
	await mouse_motion(Vector2(0, 100000))
	check(actor.eye.rotation.x > -PI / 2 and actor.eye.rotation.x < deg_to_rad(-80), "Large downward motion clamps above negative vertical")
	actor.eye.rotation.x = 0
	actor.apply_aim_rotation() # Detached view is updated explicitly, not through parent inheritance.
	check(actor.aim_direction().dot(-actor.camera.global_transform.basis.z) > 0.99999, "Shot aiming follows the direction at the camera's center crosshair")
	await scope_input_checks(actor)
	previous = actor.rotation.y
	await tap_key(KEY_ESCAPE)
	check(game.context == "pause" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape pauses controls and releases the cursor")
	await mouse_motion(Vector2(30, 0))
	check(absf(yaw_change(previous)) < 0.00001, "Mouse movement in the pause menu does not turn the player")
	await tap_key(KEY_ESCAPE)
	check(game.context == "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Escape resumes and captures the cursor")
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(yaw_change(previous) < -0.0001, "Mouse look returns immediately after resuming")
	await tap_key(KEY_ENTER)
	check(game.context == "chat" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Chat opens its text entry and releases the cursor")
	game.chat_entry.release_focus()
	var chat_point: Vector2 = game.chat_entry.get_global_rect().get_center() * Vector2(root.size) / game.hud.size
	await mouse_button(MOUSE_BUTTON_LEFT, true, chat_point)
	await mouse_button(MOUSE_BUTTON_LEFT, false, chat_point)
	check(root.gui_get_focus_owner() == game.chat_entry, "The chat field remains clickable after disabling gameplay HUD mouse interception")
	await text_input("aim test")
	check(game.chat_entry.text == "aim test", "The chat field still accepts keyboard text through normal GUI routing")
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(absf(yaw_change(previous)) < 0.00001, "Chat mouse movement does not turn the player")
	await tap_key(KEY_ESCAPE)
	check(game.context == "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing chat restores captured play")
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(yaw_change(previous) < -0.0001, "Mouse look works after closing chat")
	game.show_pause()
	game.open_settings("pause")
	await frames(3)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(game.context == "settings" and absf(yaw_change(previous)) < 0.00001, "Mouse movement in settings does not turn the player")
	game.settings_back()
	game.resume_game()
	await frames(3)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(yaw_change(previous) < -0.0001, "Mouse look works after returning from settings")
	# If capture is lost without a menu, the first click should restore it safely.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(2)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(absf(yaw_change(previous)) < 0.00001, "An uncaptured gameplay cursor cannot turn the camera")
	var capture_ammo: int = actor.ammo[actor.slot]
	await mouse_button(MOUSE_BUTTON_LEFT, true)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and actor.ammo[actor.slot] == capture_ammo, "The first capture-restoring click captures the cursor without firing")
	# The release may arrive in a menu; it must still clear the first-click guard.
	game.show_pause()
	await mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(10, 10))
	game.resume_game()
	await frames(2)
	await mouse_button(MOUSE_BUTTON_LEFT, true)
	await mouse_button(MOUSE_BUTTON_LEFT, false)
	check(actor.ammo[actor.slot] < capture_ammo, "Releasing a capture click in the pause menu allows the next deliberate shot")
	# The platform focus notification is sent by Windows and X11 on Alt-Tab.
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(3)
	check(game.context == "pause" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Losing application focus pauses controls and releases the cursor")
	previous = actor.rotation.y
	var ammo_before: int = actor.ammo[actor.slot]
	await mouse_motion(Vector2(100, 0))
	await mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(10, 10))
	await mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(10, 10))
	check(absf(yaw_change(previous)) < 0.00001 and actor.ammo[actor.slot] == ammo_before, "Mouse input while focus is lost cannot turn or fire")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.resume_game()
	await frames(3)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(yaw_change(previous) < -0.0001, "Restoring focus and resuming recaptures working mouse look")
	actor.die(null, "Aim input regression")
	await frames(3)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(not actor.alive and absf(yaw_change(previous)) < 0.00001, "The eliminated player cannot turn the death camera")
	actor.respawn()
	await frames(3)
	previous = actor.rotation.y
	await mouse_motion(Vector2(30, 0))
	check(actor.alive and yaw_change(previous) < -0.0001, "Respawning restores mouse aiming without reopening any menu")
	game.stop_game()
	game.queue_free()
	await frames(5)
	print("RESULT: %d native aim input checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
