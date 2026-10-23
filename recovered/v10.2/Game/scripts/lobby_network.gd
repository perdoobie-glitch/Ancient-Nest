class_name NestLobbyNetwork
extends Node

# TEST FRIENDS — remove before release
const TEST_FRIENDS = []

const DEFAULT_HOST_PORT := 7777
const PORT_RETRIES := 3
const JOIN_TIMEOUT_SECONDS := 8.0
const PROBE_INTERVAL_SECONDS := 5.0
const PROBE_TIMEOUT_SECONDS := 1.5

var game
var host_port: int = DEFAULT_HOST_PORT
var public_ip: String = "Checking…"
var upnp_message: String = ""
var pending_join_name: String = ""
var pending_join_ip: String = ""
var pending_join_port: int = DEFAULT_HOST_PORT
var pending_join_deadline: float = 0.0
var friend_reachable: Dictionary = {}
var probe_peers: Dictionary = {}
var next_probe_at: float = 0.0
var upnp_thread: Thread
var mapped_port: int = 0
var shutting_down := false

func _ready() -> void:
	for friend in TEST_FRIENDS:
		friend_reachable[friend.name] = false
	set_process(true)

func _process(_delta: float) -> void:
	if game == null or shutting_down: return
	_poll_join_timeout()
	_poll_upnp_thread()
	_poll_friend_probes()

func test_friends() -> Array:
	return TEST_FRIENDS

func start_auto_host() -> Error:
	if game == null: return ERR_UNCONFIGURED
	if game.network_active and game.multiplayer.is_server():
		host_port = game.connection_port
		return OK
	if game.network_active:
		game.close_connection()
	var last_error: Error = ERR_CANT_CREATE
	for port in range(DEFAULT_HOST_PORT, DEFAULT_HOST_PORT + PORT_RETRIES):
		last_error = game.host_direct(port, game.current_username(), game.selected_faction)
		if last_error == OK:
			host_port = port
			public_ip = "Checking…"
			game.network_status = "Hosting · Port %d" % port
			_start_upnp(port)
			return OK
	game.network_status = "Couldn't host on UDP ports 7777–7779. Another app may already be using them."
	return last_error

func leave_lobby() -> void:
	cancel_pending_join()
	_stop_upnp_mapping()
	if game != null: game.close_connection()

func quick_join(friend: Dictionary) -> void:
	if game == null: return
	var friend_name := String(friend.get("name", "Friend"))
	var address := String(friend.get("ip", ""))
	var port := int(friend.get("port", DEFAULT_HOST_PORT))
	if address.is_empty(): return
	pending_join_name = friend_name
	pending_join_ip = address
	pending_join_port = port
	pending_join_deadline = Time.get_ticks_msec() / 1000.0 + JOIN_TIMEOUT_SECONDS
	if game.network_active and game.multiplayer.is_server() and game.lobby_members.size() > 1:
		game.host_departing.rpc()
		await game.get_tree().create_timer(0.12).timeout
	_stop_upnp_mapping()
	var err: Error = game.join_direct(address, port, game.current_username(), game.selected_faction)
	if err != OK:
		_join_failed("Couldn't reach %s's lobby (%s:%d). They may not be in Custom Games or their port isn't open." % [friend_name, address, port])
		return
	game.network_status = "Joining %s…" % friend_name
	if game.has_method("network_ui_changed"): game.call_deferred("network_ui_changed")

func cancel_pending_join() -> void:
	pending_join_name = ""
	pending_join_ip = ""
	pending_join_deadline = 0.0

func on_join_succeeded() -> void:
	cancel_pending_join()

func on_join_failed(reason: String = "") -> void:
	if not pending_join_name.is_empty():
		var detail := reason
		if detail.is_empty():
			detail = "Couldn't reach %s's lobby (%s:%d). They may not be in Custom Games or their port isn't open." % [pending_join_name, pending_join_ip, pending_join_port]
		_join_failed(detail)
	else:
		_return_to_host(reason)

func on_server_disconnected(reason: String = "Host disconnected.") -> void:
	_return_to_host(reason)

func status_for(friend_name: String) -> bool:
	return bool(friend_reachable.get(friend_name, false))

func host_badge_text() -> String:
	if game == null or not game.network_active or not game.multiplayer.is_server():
		return game.network_status if game != null else "Offline"
	var text := "●  Hosting · Port %d\nYour IP: %s" % [game.connection_port, public_ip]
	if not upnp_message.is_empty(): text += "\n" + upnp_message
	return text

func shutdown() -> void:
	if shutting_down: return
	shutting_down = true
	cancel_pending_join()
	for key in probe_peers.keys():
		var state: Dictionary = probe_peers[key]
		var peer = state.get("peer")
		if peer != null: peer.close()
	probe_peers.clear()
	_stop_upnp_mapping()
	if upnp_thread != null and upnp_thread.is_started(): upnp_thread.wait_to_finish()
	if game != null: game.close_connection()

func _poll_join_timeout() -> void:
	if pending_join_deadline <= 0.0: return
	if Time.get_ticks_msec() / 1000.0 < pending_join_deadline: return
	var detail := "Couldn't reach %s's lobby (%s:%d). They may not be in Custom Games or their port isn't open." % [pending_join_name, pending_join_ip, pending_join_port]
	_join_failed(detail)

func _join_failed(detail: String) -> void:
	cancel_pending_join()
	if game != null:
		game.close_connection()
		game.network_status = detail
		start_auto_host()
		# Preserve the useful error while still returning to hosting.
		game.network_status = detail + "\nBack to hosting on UDP port %d." % game.connection_port
		if game.has_method("network_ui_changed"): game.call_deferred("network_ui_changed")

func _return_to_host(reason: String) -> void:
	cancel_pending_join()
	if game == null: return
	game.close_connection()
	start_auto_host()
	if not reason.is_empty(): game.network_status = reason + " Back to hosting on UDP port %d." % game.connection_port
	if game.has_method("network_ui_changed"): game.call_deferred("network_ui_changed")

func _start_upnp(port: int) -> void:
	if upnp_thread != null and upnp_thread.is_started(): return
	upnp_message = "Opening UDP port automatically…"
	upnp_thread = Thread.new()
	upnp_thread.start(_upnp_worker.bind(port))

func _upnp_worker(port: int) -> Dictionary:
	var upnp := UPNP.new()
	var discover_result := upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "port": port, "result": discover_result, "ip": "Unavailable"}
	var external := upnp.query_external_address()
	var map_result := upnp.add_port_mapping(port, port, "Ancient Nest", "UDP")
	return {"ok": map_result == UPNP.UPNP_RESULT_SUCCESS, "port": port, "result": map_result, "ip": external}

func _poll_upnp_thread() -> void:
	if upnp_thread == null or not upnp_thread.is_started() or upnp_thread.is_alive(): return
	var result = upnp_thread.wait_to_finish()
	upnp_thread = null
	if not result is Dictionary: return
	public_ip = String(result.get("ip", "Unavailable"))
	if bool(result.get("ok", false)):
		mapped_port = int(result.get("port", 0))
		upnp_message = "UPnP ready"
	else:
		mapped_port = 0
		upnp_message = "Couldn't open port %d automatically. Forward UDP %d to this PC." % [int(result.get("port", host_port)), int(result.get("port", host_port))]
	if game != null and game.has_method("refresh_lobby_network_ui"): game.call_deferred("refresh_lobby_network_ui")

func _stop_upnp_mapping() -> void:
	if mapped_port <= 0: return
	# Removal is short and only runs when leaving/switching hosts.
	var upnp := UPNP.new()
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		upnp.delete_port_mapping(mapped_port, "UDP")
	mapped_port = 0

func _poll_friend_probes() -> void:
	if TEST_FRIENDS.is_empty():return
	var now := Time.get_ticks_msec() / 1000.0
	for key in probe_peers.keys().duplicate():
		var state: Dictionary = probe_peers[key]
		var peer: ENetMultiplayerPeer = state.peer
		peer.poll()
		var status := peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			friend_reachable[key] = true
			peer.close(); probe_peers.erase(key)
			if game != null and game.has_method("refresh_lobby_network_ui"): game.call_deferred("refresh_lobby_network_ui")
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED or now - float(state.started) >= PROBE_TIMEOUT_SECONDS:
			friend_reachable[key] = false
			peer.close(); probe_peers.erase(key)
			if game != null and game.has_method("refresh_lobby_network_ui"): game.call_deferred("refresh_lobby_network_ui")
	if game == null or String(game.get("current_screen")) != "lobby" or now < next_probe_at: return
	next_probe_at = now + PROBE_INTERVAL_SECONDS
	for friend in TEST_FRIENDS:
		if probe_peers.has(friend.name): continue
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(String(friend.ip), int(friend.port))
		if err != OK:
			friend_reachable[friend.name] = false
			continue
		probe_peers[friend.name] = {"peer": peer, "started": now}

func _exit_tree() -> void:
	shutdown()
