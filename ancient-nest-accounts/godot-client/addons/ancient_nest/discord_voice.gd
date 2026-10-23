extends Node
## Discord Social SDK 5.0.0 binding by thiagola92. No Discord password or bot token in the game.
## All controls below apply only to the game's team call, never to the desktop Discord app.

signal state_changed(message: String)

var _pending_tokens: Dictionary = {}
var _client: Object
var _call: Object
var _verifier: Object
var _store: RefCounted = preload("credential_store.gd").new()
var _application_id := 0
var _game_user := ""
var _generation := 0
var _ready_for_calls := false
var _oauth_busy := false
var _poll_busy := false
var _discord_refresh := ""
var _discord_expiry := 0
var _lobby_id := 0
var _room_expiry := 0
var _auto_join := true
var _muted := false
var _deafened := false
var _push_to_talk := true
var _timer: Timer
var _panel: PanelContainer
var _label: Label
var _connect_button: Button


func _ready() -> void:
	_load_preferences()
	_build_panel()
	if not InputMap.has_action("team_voice_ptt"):
		InputMap.add_action("team_voice_ptt")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_V
		InputMap.action_add_event("team_voice_ptt", event)
	_timer = Timer.new()
	_timer.wait_time = 5.0
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	AncientNestAuth.session_changed.connect(_on_game_session)
	AncientNestAuth.session_lost.connect(_on_game_logout)
	if not AncientNestAuth.current_user.is_empty():
		_on_game_session(AncientNestAuth.current_user)


func _process(_delta: float) -> void:
	if _client != null:
		ClassDB.class_call_static(&"Discord", &"run_callbacks")
	if _call != null:
		if int(Time.get_unix_time_from_system()) >= _room_expiry:
			_leave_team_call()
			_state("Team voice ended")
		elif _push_to_talk:
			_call.set_ptt_active(Input.is_action_pressed("team_voice_ptt") and get_window().has_focus())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _call != null:
		_call.set_ptt_active(false)


func _state(message: String) -> void:
	if is_instance_valid(_label):
		_label.text = message
	state_changed.emit(message)


func _on_game_session(user: Dictionary) -> void:
	if _game_user == str(user.id):
		return
	_on_game_logout()
	_game_user = str(user.id)
	_panel.show()
	_store.service = "discord-oauth-refresh"
	_store.device = _game_user
	var generation := _generation
	_state("Preparing Discord voice…")
	var config: Dictionary = await AncientNestAuth.authenticated_request("/discord/config")
	if generation != _generation:
		return
	if not config.ok or not config.data.get("enabled", false):
		_state("Discord voice is not available yet")
		return
	if not ClassDB.class_exists(&"DiscordClient"):
		_state("Discord voice is unavailable on this device")
		return
	_application_id = int(config.data.application_id)
	_client = ClassDB.instantiate(&"DiscordClient")
	_client.set_application_id(_application_id)
	_client.set_status_changed_callback(_on_sdk_status.bind(generation))
	_connect_button.disabled = false
	if not _pending_tokens.is_empty():
		var pending := _pending_tokens
		_pending_tokens = {}
		_accept_discord_tokens({"ok": true, "data": pending})
		return
	_discord_refresh = _store.read_token()
	if _discord_refresh.is_empty():
		_state("Connect Discord to enable team voice")
	else:
		await _refresh_discord()


func connect_discord() -> void:
	if _client == null or _oauth_busy:
		return
	_oauth_busy = true
	_connect_button.disabled = true
	_state("Approve the Discord connection to enable team voice")
	_verifier = _client.create_authorization_code_verifier()
	var args: Object = ClassDB.instantiate(&"DiscordAuthorizationArgs")
	args.set_client_id(_application_id)
	args.set_scopes(ClassDB.class_call_static(&"DiscordClient", &"get_default_communication_scopes"))
	args.set_code_challenge(_verifier.challenge())
	_client.authorize(args, _on_authorized.bind(_generation))


func _on_authorized(result: Variant, code: String, redirect_uri: String, generation: int) -> void:
	if generation != _generation:
		return
	if not result.successful():
		_oauth_busy = false
		_connect_button.disabled = false
		_state("Discord connection was not approved. You can try again.")
		return
	var response: Dictionary = await AncientNestAuth.authenticated_request("/discord/exchange", HTTPClient.METHOD_POST,
		{"code": code, "code_verifier": _verifier.verifier(), "redirect_uri": redirect_uri})
	if generation != _generation:
		return
	_accept_discord_tokens(response)


func _refresh_discord() -> void:
	if _oauth_busy or _discord_refresh.is_empty():
		return
	_oauth_busy = true
	var generation := _generation
	var response: Dictionary = await AncientNestAuth.authenticated_request("/discord/refresh", HTTPClient.METHOD_POST,
		{"refresh_token": _discord_refresh})
	if generation != _generation:
		return
	_accept_discord_tokens(response)


func _accept_discord_tokens(response: Dictionary) -> void:
	_oauth_busy = false
	_connect_button.disabled = false
	if not response.ok:
		if response.get("error", "") == "discord_authorization_expired" or response.get("error", "") == "discord_link_required":
			_store.clear_token()
			_discord_refresh = ""
		_state("Couldn't connect Discord. Retry Connect Discord; your game account is still signed in.")
		return
	_discord_refresh = str(response.data.refresh_token)
	_discord_expiry = int(Time.get_unix_time_from_system()) + int(response.data.expires_in)
	if AncientNestAuth.get("_remember_device") and _store.write_token(_discord_refresh) != OK:
		_state("Discord connected for this session; the connection couldn't be saved on this device")
	_client.update_token(_constant("DiscordAuthorizationTokenType", "BEARER"), str(response.data.access_token),
		_on_sdk_token_updated.bind(_generation))


func _on_sdk_token_updated(result: Variant, generation: int) -> void:
	if generation != _generation:
		return
	if not result.successful():
		_state("Discord couldn't accept this connection. Try Connect Discord again.")
		return
	if not _ready_for_calls:
		_client.connect_discord()


func _on_sdk_status(status: int, _error: int, _detail: int, generation: int) -> void:
	if generation != _generation:
		return
	_ready_for_calls = status == _constant("DiscordClientStatus", "READY")
	if _ready_for_calls:
		_state("Discord connected · waiting for your team")
		_poll()
	elif status == _constant("DiscordClientStatus", "RECONNECTING"):
		_state("Reconnecting Discord voice…")
	elif status == _constant("DiscordClientStatus", "DISCONNECTED"):
		_leave_team_call()
		_state("Discord voice disconnected · your game account is still signed in")


func _poll() -> void:
	if not _ready_for_calls or _poll_busy or _oauth_busy or _game_user.is_empty():
		return
	if _discord_expiry < int(Time.get_unix_time_from_system()) + 300:
		await _refresh_discord()
		return
	if not _auto_join:
		return
	_poll_busy = true
	var generation := _generation
	var response: Dictionary = await AncientNestAuth.authenticated_request("/voice/session")
	_poll_busy = false
	if generation != _generation:
		return
	if not response.ok:
		# Retain an existing call only until its last server-issued lease expires.
		return
	if not response.data.get("assigned", false):
		if _lobby_id != 0:
			_leave_team_call()
			_state("Discord connected · waiting for your team")
		return
	var lobby_id := int(response.data.lobby_id)
	_room_expiry = int(response.data.expires_at)
	if lobby_id == _lobby_id:
		return
	_leave_team_call()
	# Membership was created by the server. Do not create/join using a client-supplied secret.
	if _client.get_lobby_handle(lobby_id) == null:
		return # Wait for SDK membership propagation; the next poll retries.
	_lobby_id = lobby_id
	_room_expiry = int(response.data.expires_at)
	_call = _client.start_call(_lobby_id)
	if _call == null:
		_call = _client.get_call(_lobby_id)
	if _call == null:
		_lobby_id = 0
		return
	_call.set_self_mute(true)
	_call.set_status_changed_callback(_on_call_status.bind(_generation, _lobby_id))
	_state("Connecting team voice…")
	if _call.get_status() == _constant("DiscordCallStatus", "CONNECTED"):
		_on_call_status(_constant("DiscordCallStatus", "CONNECTED"), 0, 0, _generation, _lobby_id)


func _on_call_status(status: int, _error: int, _detail: int, generation: int, lobby_id: int) -> void:
	if generation != _generation or lobby_id != _lobby_id or _call == null:
		return
	if status == _constant("DiscordCallStatus", "CONNECTED"):
		_apply_controls()
		_state("Team voice connected · hold V to talk" if _push_to_talk else "Team voice connected · voice activity")
	elif status == _constant("DiscordCallStatus", "DISCONNECTED"):
		_leave_team_call()
		_state("Team voice disconnected · retrying your team assignment")
	else:
		_state("Connecting team voice…")


func _apply_controls() -> void:
	if _call == null:
		return
	_call.set_audio_mode(_constant("DiscordAudioModeType", "MODE_PTT" if _push_to_talk else "MODE_VAD"))
	_call.set_self_mute(_muted)
	_call.set_self_deaf(_deafened)
	_call.set_ptt_active(false)


func _leave_team_call() -> void:
	var old_lobby := _lobby_id
	_lobby_id = 0
	_room_expiry = 0
	if _call != null:
		_call.set_self_mute(true)
		_call.set_ptt_active(false)
	_call = null
	if _client != null and old_lobby != 0:
		_client.end_call(old_lobby, func() -> void: pass)


func _on_game_logout() -> void:
	_generation += 1
	_leave_team_call()
	if _client != null:
		_client.disconnect_discord()
	_client = null
	_game_user = ""
	_pending_tokens = {}
	_discord_refresh = ""
	_discord_expiry = 0
	_ready_for_calls = false
	_oauth_busy = false
	_poll_busy = false
	if is_instance_valid(_panel):
		_panel.hide()
		_connect_button.disabled = true


func _constant(class_name_value: String, name_value: String) -> int:
	return ClassDB.class_get_integer_constant(class_name_value, name_value)


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(330, 0)
	layer.add_child(_panel)
	var contents := VBoxContainer.new()
	_panel.add_child(contents)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(_label)
	_connect_button = Button.new()
	_connect_button.text = "Connect Discord"
	_connect_button.disabled = true
	_connect_button.pressed.connect(connect_discord)
	contents.add_child(_connect_button)
	var auto_join := CheckBox.new()
	auto_join.text = "Automatically join team voice"
	auto_join.button_pressed = _auto_join
	auto_join.toggled.connect(func(value: bool) -> void:
		_auto_join = value
		_save_preferences()
		if not value:
			_leave_team_call()
		else:
			_poll())
	contents.add_child(auto_join)
	var mute := CheckBox.new()
	mute.text = "Mute team microphone"
	mute.toggled.connect(func(value: bool) -> void:
		_muted = value
		_apply_controls())
	contents.add_child(mute)
	var deaf := CheckBox.new()
	deaf.text = "Deafen team voice"
	deaf.toggled.connect(func(value: bool) -> void:
		_deafened = value
		_apply_controls())
	contents.add_child(deaf)
	var ptt := CheckBox.new()
	ptt.text = "Push-to-talk · hold V"
	ptt.button_pressed = _push_to_talk
	ptt.toggled.connect(func(value: bool) -> void:
		_push_to_talk = value
		_save_preferences()
		_apply_controls())
	contents.add_child(ptt)
	_panel.hide()


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://voice-preferences.cfg") == OK:
		_auto_join = bool(config.get_value("voice", "auto_join", true))
		_push_to_talk = bool(config.get_value("voice", "push_to_talk", true))


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("voice", "auto_join", _auto_join)
	config.set_value("voice", "push_to_talk", _push_to_talk)
	config.save("user://voice-preferences.cfg")


func set_pending_tokens(tokens: Dictionary) -> void:
	if _client != null:
		_accept_discord_tokens({"ok": true, "data": tokens})
	else:
		_pending_tokens = tokens
