extends SceneTree
# Explicit peer phases keep restarts from destroying an actor while the other
# process is still measuring its jump. Model-loading time can differ per peer.
class PhaseGate:
	extends Node
	var marks: Dictionary = {}
	@rpc("any_peer", "call_remote", "reliable")
	func mark(phase: String, session: int) -> void:
		marks[phase] = {"session": session, "sender": multiplayer.get_remote_sender_id()}

var game
var gate: PhaseGate
var role: String
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS " + role + ": " + description)
	else:
		failures += 1
		push_error("FAIL " + role + ": " + description)

func received(phase: String, session: int, sender: int) -> bool:
	var value: Dictionary = gate.marks.get(phase, {})
	return value.get("session", -1) == session and value.get("sender", -1) == sender

func wait_for_phase(phase: String, session: int, sender: int, timeout_ms: int = 15000) -> bool:
	var deadline = Time.get_ticks_msec() + timeout_ms
	while not received(phase, session, sender) and Time.get_ticks_msec() < deadline and game.network_active:
		await process_frame
	return received(phase, session, sender)

func finish() -> void:
	print("RESULT " + role + ": %d checks, %d failures" % [checks, failures])
	game.stop_game()
	game.close_connection()
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)

func run() -> void:
	role = "host" if "host" in OS.get_cmdline_user_args() else "client"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.bot_fill = false
	game.team_size = 2
	gate = PhaseGate.new()
	gate.name = "RegressionPhaseGate"
	game.add_child(gate)
	var started: int
	if role == "host":
		started = game.host_direct(17879, "RegressionHost", 0)
	else:
		started = game.join_direct("127.0.0.1", 17879, "RegressionClient", 1)
	check(started == OK, "Direct session starts")
	var deadline = Time.get_ticks_msec() + 20000
	while game.lobby_members.size() < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.lobby_members.size() == 2, "Both peers reach the regression lobby")
	if game.lobby_members.size() != 2:
		await finish()
		return
	if role == "host":
		await run_host()
	else:
		await run_client()
	await finish()

func run_host() -> void:
	game.start_game()
	game.context = "pause"
	for actor in game.actors:
		actor.global_position = Vector3(-13 if actor.remote_peer == 1 else 13, 7, -17)*.85+Vector3.UP*.05
	var remote: NestActor
	for actor in game.actors:
		if actor.remote_peer > 1:
			remote = actor
	if remote == null:
		check(false, "The remote test actor exists")
		return
	var remote_id = remote.remote_peer
	var old: int = game.match_session
	var ready = await wait_for_phase("started", old, remote_id)
	check(ready, "Client confirms its first actor before the host measures the jump")
	if not ready:
		return
	var apex = remote.global_position.y
	var deadline = Time.get_ticks_msec() + 15000
	while not received("jump_done", old, remote_id) and Time.get_ticks_msec() < deadline and game.network_active:
		await physics_frame
		apex = maxf(apex, remote.global_position.y)
	check(received("jump_done", old, remote_id), "Client completes jump measurement before restart")
	if not received("jump_done", old, remote_id):
		return
	check(apex > 7.70, "Short-tap jump survives five dropped command packets and reaches the authoritative ~2m apex")
	game.stop_game()
	await create_timer(0.4).timeout
	game.start_game()
	game.context = "pause"
	check(game.match_session != old, "Restart issues a new match session ID")
	var verified = await wait_for_phase("restart_verified", game.match_session, remote_id)
	check(verified, "Client completes its new-session checks before host teardown")
	if not verified:
		return
	check(game.shot_authorizations.is_empty(), "Old-session shot authorization is rejected")
	check(game.command_received.get(remote_id, {"sequence": 0}).sequence < 99999,
		"Old-session high-sequence movement cannot poison new input")
	gate.mark.rpc_id(remote_id, "server_verified", game.match_session)
	await create_timer(0.3).timeout

func run_client() -> void:
	var deadline = Time.get_ticks_msec() + 20000
	while (not game.running or not is_instance_valid(game.player)) and Time.get_ticks_msec() < deadline and game.network_active:
		await process_frame
	check(game.running and is_instance_valid(game.player), "The client creates its first test actor")
	if not game.running or not is_instance_valid(game.player):
		return
	await create_timer(0.6).timeout
	var old: int = game.match_session
	gate.mark.rpc_id(1, "started", old)
	game.command_drop_packets = 5 # v0.11: redundancy must still deliver the jump
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	var apex = game.player.global_position.y
	deadline = Time.get_ticks_msec() + 1600
	while Time.get_ticks_msec() < deadline and game.running and is_instance_valid(game.player):
		await physics_frame
		if is_instance_valid(game.player):
			apex = maxf(apex, game.player.global_position.y)
	check(apex > 7.60, "A tap between input packets preserves client jump height")
	gate.mark.rpc_id(1, "jump_done", old)
	deadline = Time.get_ticks_msec() + 20000
	while (not game.running or not is_instance_valid(game.player) or game.match_session == old) and Time.get_ticks_msec() < deadline and game.network_active:
		await process_frame
	check(game.running and is_instance_valid(game.player) and game.match_session != old, "Client enters the restarted session")
	if not game.running or not is_instance_valid(game.player) or game.match_session == old:
		return
	await create_timer(0.5).timeout
	game.receive_commands.rpc_id(1, game.encode_command_packet([{"seq":99999,"move":Vector2(1,0),"yaw":0.0,"pitch":0.0,"jump":false,"interact":false,"crouch":-1}], old))
	game.authorize_shot.rpc_id(1, 999984, game.player.life_id, game.round_number, "rifle", game.player.eye.global_position, Vector3.FORWARD, old)
	await create_timer(0.7).timeout
	check(game.player.ammo[0] == game.player.weapons[0].magazine, "Old-session shot cannot consume new-life ammunition")
	check(game.snapshot_received > 0, "Snapshots continue after restarting instead of freezing")
	# Isolate client physics from the host's valid snapshot correction. Waiting
	# for a frame here allowed an authoritative zero to overwrite this fixture.
	var authoritative_over=game.player.overshield
	var authoritative_deadline=game.player.over_deadline
	game.player.overshield = 100
	game.player.over_deadline = 0
	game.player._physics_process(1.0/60)
	check(game.player.overshield > 0, "Client physics does not expire host-owned bonus protection")
	game.player.overshield=authoritative_over; game.player.over_deadline=authoritative_deadline
	gate.mark.rpc_id(1, "restart_verified", game.match_session)
	var verified = await wait_for_phase("server_verified", game.match_session, 1)
	check(verified, "Host confirms its authority checks before client teardown")
