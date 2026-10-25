extends SceneTree
class FakeClient extends RefCounted:
	var authorizations := 0
	var token_updates := 0
	var connections := 0
	func authorize(_args, _callback) -> void: authorizations += 1
	func update_token(_type, _token, _callback) -> void: token_updates += 1
	func connect_discord() -> void: connections += 1
	func disconnect_discord() -> void: pass
class FakeStore extends RefCounted:
	func write_token(_token) -> int: return OK
	func clear_token() -> void: pass
class FakeResult extends RefCounted:
	var success := true
	func successful() -> bool: return success

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var voice = load("res://addons/ancient_nest/discord_voice.gd").new()
	voice._connect_button = Button.new()
	voice._label = Label.new()
	var tokens := {"access_token": "fixture-access", "refresh_token": "fixture-refresh", "expires_in": 3600}
	voice.set_pending_tokens(tokens, "account-a")
	assert(voice._take_pending_tokens_for_user("account-b").is_empty())
	voice.set_pending_tokens(tokens, "account-a")
	assert(voice._take_pending_tokens_for_user("account-a") == tokens)
	assert(voice._take_pending_tokens_for_user("account-a").is_empty())
	voice.set_pending_tokens(tokens, "account-a")
	voice._on_game_logout()
	assert(voice._pending_tokens.is_empty() and voice._pending_account_id.is_empty())
	var client := FakeClient.new()
	voice._client = client
	voice._store = FakeStore.new()
	voice._accept_discord_tokens({"ok": true, "data": tokens})
	assert(client.token_updates == 1 and client.authorizations == 0)
	assert(voice._connect_button.disabled and voice._oauth_busy)
	voice.connect_discord()
	assert(client.authorizations == 0)
	voice._on_sdk_token_updated(FakeResult.new(), voice._generation)
	assert(client.connections == 1 and not voice._oauth_busy)
	voice._on_sdk_status(voice._constant("DiscordClientStatus", "READY"), 0, 0, voice._generation)
	assert(voice._connect_button.disabled and voice._connect_button.text == "Discord connected")
	voice.connect_discord()
	assert(client.authorizations == 0)
	voice._on_sdk_status(voice._constant("DiscordClientStatus", "DISCONNECTED"), 0, 0, voice._generation)
	assert(not voice._connect_button.disabled and voice._connect_button.text == "Retry Discord voice")
	voice._connect_button.free()
	voice._label.free()
	voice.free()
	print("DISCORD HANDOFF: account-bound one-use tokens, logout cleanup, automatic SDK connection and duplicate-consent prevention passed (mock SDK)")
	quit()
