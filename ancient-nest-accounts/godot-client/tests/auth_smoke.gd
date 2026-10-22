extends SceneTree
## Uses the actual local accounts Worker, with an in-memory keyring test double.

class MemoryStore extends RefCounted:
	var token := ""
	var fail_write := false
	func is_available() -> bool:
		return true
	func read_token() -> String:
		return token
	func write_token(value: String) -> Error:
		if fail_write:
			return FAILED
		token = value
		return OK
	func clear_token() -> Error:
		token = ""
		return OK


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var api := OS.get_environment("ANCIENT_NEST_TEST_URL")
	assert(not api.is_empty())
	var store := MemoryStore.new()
	var auth: Node = root.get_node("AncientNestAuth")
	auth.api_url = api
	auth.credential_store = store
	var result: Dictionary = await auth.restore_session()
	assert(not result.ok and result.error == "account_required")
	result = await auth.create_account("GodotPlayer", "test password for godot only", true, "godot@example.com", "+12025550123")
	assert(result.ok and result.remembered)
	assert(store.token.length() == 64)
	var first_token := store.token
	var user_id: String = auth.current_user.id
	# Simulate a new game process: no access token or user state survives in memory.
	var reopened: Node = load("res://addons/ancient_nest/auth.gd").new()
	root.add_child(reopened)
	reopened.api_url = api
	reopened.credential_store = store
	result = await reopened.restore_session()
	assert(result.ok and reopened.current_user.id == user_id)
	assert(store.token != first_token)
	var saved_token := store.token
	# An unavailable service must not erase the saved refresh token or report logout success.
	reopened.api_url = "http://127.0.0.1:1"
	result = await reopened.refresh_session()
	assert(not result.ok and result.error == "network_error")
	assert(store.token == saved_token)
	result = await reopened.sign_out()
	assert(not result.ok and store.token == saved_token)
	reopened.api_url = api
	result = await reopened.sign_out()
	assert(result.ok and store.token.is_empty() and reopened.current_user.is_empty())
	# A revoked saved token is cleared after a definitive HTTP 401.
	store.token = saved_token
	result = await reopened.restore_session()
	assert(not result.ok and result.status == 401 and store.token.is_empty())
	# A startup outage requires manual login and stops automatic background restoration.
	result = await reopened.sign_in("GodotPlayer", "test password for godot only", true)
	assert(result.ok and not store.token.is_empty())
	reopened.api_url = "http://127.0.0.1:1"
	result = await reopened.restore_session()
	assert(not result.ok and store.token.is_empty() and reopened.current_user.is_empty())
	assert(reopened.get("_refresh_token").is_empty())
	reopened.api_url = api
	# Storage failure must not pretend that this login will survive a restart.
	store.fail_write = true
	result = await reopened.sign_in("GodotPlayer", "test password for godot only", true)
	assert(result.ok and not result.remembered and not result.warning.is_empty())
	assert(store.token.is_empty())
	result = await reopened.get_access_token()
	assert(result.ok and not result.token.is_empty())
	result = await reopened.sign_out()
	assert(result.ok)
	# Exercise the real startup screen, including the failed-auto-login fallback.
	var ui_store := MemoryStore.new()
	auth.credential_store = ui_store
	auth.api_url = api
	var gate: Node = load("res://addons/ancient_nest/login.tscn").instantiate()
	root.add_child(gate)
	await process_frame
	assert(gate.get("_register") and gate.get("_form").visible)
	result = await auth.sign_in("GodotPlayer", "test password for godot only", true)
	assert(result.ok and not ui_store.token.is_empty())
	await gate._restore()
	assert(gate.get("_signed_in").visible and not gate.get("_form").visible)
	auth.api_url = "http://127.0.0.1:1"
	await gate._restore()
	assert(not gate.get("_register") and gate.get("_form").visible)
	assert(gate.get("_submit").text == "Sign in" and not gate.get("_signed_in").visible)
	assert(ui_store.token.is_empty())
	gate.queue_free()
	print("GODOT_AUTH_SMOKE_PASSED: first launch, automatic reopen, failed startup requires login, background offline retention, logout, revoked login, storage failure")
	quit(0)
