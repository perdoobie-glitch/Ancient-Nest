extends SceneTree
## Check the real native API, then verify team controls never touch global/friends voice.

class TeamCall extends RefCounted:
	var muted := false
	var deafened := false
	var ptt := false
	var audio_mode := 0
	func set_self_mute(value: bool) -> void:
		muted = value
	func set_self_deaf(value: bool) -> void:
		deafened = value
	func set_ptt_active(value: bool) -> void:
		ptt = value
	func set_audio_mode(value: int) -> void:
		audio_mode = value

class SdkClient extends RefCounted:
	var ended: Array[int] = []
	var global_changes := 0
	var disconnected := false
	func end_call(lobby_id: int, callback: Callable) -> void:
		ended.append(lobby_id)
		callback.call()
	func end_calls(_callback: Callable) -> void:
		global_changes += 1
	func set_self_mute_all(_value: bool) -> void:
		global_changes += 1
	func disconnect_discord() -> void:
		disconnected = true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(ClassDB.class_exists(&"DiscordClient"), "Install the Discord native addon first")
	assert(ClassDB.class_exists(&"Keyring"), "Install the native credential-store addon first")
	for method in ["get_password", "set_password", "delete_password"]:
		assert(ClassDB.class_has_method(&"Keyring", method))
	for method in ["authorize", "create_authorization_code_verifier", "update_token", "get_lobby_handle", "start_call", "get_call", "end_call"]:
		assert(ClassDB.class_has_method(&"DiscordClient", method), "Missing native SDK method: " + method)
	var client: Object = ClassDB.instantiate(&"DiscordClient")
	client.set_application_id(123456789012345678)
	var verifier: Object = client.create_authorization_code_verifier()
	assert(verifier.verifier().length() >= 43)
	assert(verifier.challenge() != null)
	var scopes: String = ClassDB.class_call_static(&"DiscordClient", &"get_default_communication_scopes")
	assert(scopes.contains("sdk.social_layer"))
	ClassDB.class_call_static(&"Discord", &"run_callbacks")
	client.disconnect_discord()
	client = null
	verifier = null
	var voice: Node = root.get_node("AncientNestDiscordVoice")
	var sdk := SdkClient.new()
	var team_call := TeamCall.new()
	voice._client = sdk
	voice._call = team_call
	voice._lobby_id = 987654321
	voice._muted = true
	voice._deafened = true
	voice._push_to_talk = true
	voice._apply_controls()
	assert(team_call.muted and team_call.deafened and not team_call.ptt)
	assert(team_call.audio_mode == ClassDB.class_get_integer_constant(&"DiscordAudioModeType", &"MODE_PTT"))
	assert(sdk.global_changes == 0)
	voice._leave_team_call()
	assert(sdk.ended == [987654321])
	assert(sdk.global_changes == 0 and not sdk.disconnected)
	voice._on_game_logout()
	assert(sdk.disconnected)
	print("GODOT_DISCORD_SMOKE_PASSED: native SDK, PKCE, communication scopes, per-team controls, isolated call teardown")
	quit(0)
