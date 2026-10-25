extends Node
## Register as the AncientNestAuth autoload. Never put coordinator/JWT secrets here.

signal session_changed(user: Dictionary)
signal session_lost
signal refresh_completed(result: Dictionary)
signal discord_sign_in_completed(result: Dictionary)
var _discord_client: Object
var _discord_verifier: Object

var api_url: String = str(ProjectSettings.get_setting("ancient_nest/account_api", "")).trim_suffix("/")
var credential_store: RefCounted = preload("credential_store.gd").new()
var current_user: Dictionary = {}
var last_verification_send_errors: Array = []
var _access_token := ""
var _access_expires_at := 0
var _refresh_token := ""
var _remember_device := true
var _refreshing := false
var _auth_busy := false
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.timeout.connect(_maintain_session)
	add_child(_timer)
	_timer.start()


func can_remember_device() -> bool:
	return credential_store.is_available()


func restore_session() -> Dictionary:
	if not _age_eligible():
		return {"ok": false, "error": "age_confirmation_required"}
	if _auth_busy or _refreshing:
		return {"ok": false, "error": "busy"}
	if not current_user.is_empty() and not _access_token.is_empty() and _access_expires_at > int(Time.get_unix_time_from_system()) + 30:
		return {"ok": true, "user": current_user, "remembered": _remember_device}
	if not can_remember_device():
		return {"ok": false, "error": "account_required"}
	_refresh_token = credential_store.read_token()
	_remember_device = true
	if _refresh_token.is_empty():
		return {"ok": false, "error": "account_required"}
	var result := await refresh_session()
	if not result.ok:
		# A failed startup restoration requires manual login, including an outage.
		credential_store.clear_token()
		_clear_session()
	return result


func create_account(username: String, password: String, remember: bool = true, email: String = "", phone: String = "") -> Dictionary:
	return await _authenticate("/register", username, password, remember, email, phone)


func sign_in(username: String, password: String, remember: bool = true) -> Dictionary:
	return await _authenticate("/login", username, password, remember)


func _authenticate(path: String, username: String, password: String, remember: bool, email: String = "", phone: String = "") -> Dictionary:
	if _auth_busy or _refreshing:
		return {"ok": false, "error": "busy"}
	if remember and not can_remember_device():
		return {"ok": false, "error": "secure_storage_unavailable"}
	_auth_busy = true
	var fields := {"username": username, "password": password}
	if path == "/register":
		fields["email"] = email
		fields["phone"] = phone
	var result := await _post(path, fields)
	if result.ok:
		_remember_device = remember
		last_verification_send_errors = result.data.get("send_errors", [])
		result = _accept_session(result.data)
	_auth_busy = false
	return result


func refresh_session() -> Dictionary:
	if _auth_busy:
		return {"ok": false, "error": "busy"}
	if _refreshing:
		return await refresh_completed
	if _refresh_token.is_empty():
		return {"ok": false, "error": "account_required"}
	_refreshing = true
	var result := await _post("/refresh", {"refresh_token": _refresh_token})
	# A timeout or service outage must never erase a working saved login.
	if result.ok:
		result = _accept_session(result.data)
	elif result.get("status", 0) == 401:
		credential_store.clear_token()
		_clear_session()
	_refreshing = false
	refresh_completed.emit(result)
	return result


func get_access_token() -> Dictionary:
	if _access_token.is_empty() or _access_expires_at <= int(Time.get_unix_time_from_system()) + 60:
		var result := await refresh_session()
		if not result.ok:
			return result
	return {"ok": true, "token": _access_token}


func sign_out() -> Dictionary:
	if _auth_busy:
		return {"ok": false, "error": "busy"}
	_auth_busy = true
	if _refreshing:
		await refresh_completed
	var result: Dictionary = {"ok": true}
	if not _refresh_token.is_empty():
		result = await _post("/logout", {"refresh_token": _refresh_token})
	# Do not claim successful server revocation when the network is unavailable.
	if result.ok or result.get("status", 0) == 401:
		credential_store.clear_token()
		var voice_store: RefCounted = preload("credential_store.gd").new()
		voice_store.service = "discord-oauth-refresh"
		voice_store.device = str(current_user.get("id", ""))
		voice_store.clear_token()
		_clear_session()
		result = {"ok": true}
	_auth_busy = false
	return result


func _clear_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_access_expires_at = 0
	current_user = {}
	last_verification_send_errors = []
	session_lost.emit()


func _accept_session(data: Dictionary) -> Dictionary:
	if not (data.get("user") is Dictionary) or not (data.get("token") is String) \
		or not (data.get("refresh_token") is String) or not (data.get("expires_at") is float or data.get("expires_at") is int):
		return {"ok": false, "error": "invalid_response"}
	if not (data.user.get("id") is String) or not (data.user.get("username") is String):
		return {"ok": false, "error": "invalid_response"}
	if data.user.id.is_empty() or data.user.username.is_empty() \
		or data.token.is_empty() or data.refresh_token.length() != 64:
		return {"ok": false, "error": "invalid_response"}
	_access_token = data.token
	_access_expires_at = int(data.expires_at)
	_refresh_token = data.refresh_token
	current_user = data.user
	AncientNestAgePolicy.remember_authenticated_confirmation()
	var remembered := false
	if _remember_device:
		remembered = credential_store.write_token(_refresh_token) == OK
	else:
		credential_store.clear_token()
	session_changed.emit(current_user)
	return {"ok": true, "user": current_user, "remembered": remembered,
		"warning": "" if remembered or not _remember_device else "secure_storage_unavailable"}


func _maintain_session() -> void:
	if _auth_busy or _refreshing or _refresh_token.is_empty():
		return
	if _access_expires_at > int(Time.get_unix_time_from_system()) + 120:
		return
	var result := await refresh_session()
	_timer.wait_time = 30.0 if result.ok else minf(_timer.wait_time * 2.0, 300.0)


func _post(path: String, data: Dictionary) -> Dictionary:
	return await _request(path, HTTPClient.METHOD_POST, data)


func authenticated_request(path: String, method: int = HTTPClient.METHOD_GET, data: Variant = null) -> Dictionary:
	var auth := await get_access_token()
	if not auth.ok:
		return auth
	return await _request(path, method, data, PackedStringArray(["Authorization: Bearer " + auth.token]))


func update_game_username(username: String) -> Dictionary:
	var name_pattern := RegEx.new()
	name_pattern.compile("^[a-zA-Z0-9_-]{3,24}$")
	var chosen := username.strip_edges()
	if name_pattern.search(chosen) == null:
		return {"ok": false, "error": "invalid_game_username", "status": 400}
	var response := await authenticated_request("/profile/username", HTTPClient.METHOD_POST, {"username": chosen})
	if response.ok:
		if not response.data.get("user") is Dictionary or response.data.user.get("id") != current_user.get("id"):
			return {"ok": false, "error": "invalid_response"}
		current_user.merge(response.data.user, true)
		current_user["needs_username"] = false
		session_changed.emit(current_user)
	return response


func _request(path: String, method: int, data: Variant = null, extra_headers: PackedStringArray = []) -> Dictionary:
	if not _age_eligible():
		return {"ok": false, "error": "age_confirmation_required", "status": 0}
	var local_debug := OS.is_debug_build() and (api_url.begins_with("http://127.0.0.1:") or api_url.begins_with("http://localhost:"))
	if not api_url.begins_with("https://") and not local_debug:
		return {"ok": false, "error": "invalid_api_url"}
	var http := HTTPRequest.new()
	http.timeout = 15.0
	http.max_redirects = 0
	http.body_size_limit = 65536
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append_array(extra_headers)
	var error := http.request(api_url + path, headers, method, "" if data == null else JSON.stringify(data))
	if error != OK:
		http.queue_free()
		return {"ok": false, "error": "network_error", "status": 0}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network_error", "status": 0}
	var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	var status: int = response[1]
	if not (parsed is Dictionary):
		return {"ok": false, "error": "invalid_response", "status": status}
	if status < 200 or status >= 300:
		return {"ok": false, "error": str(parsed.get("error", "service_unavailable")), "status": status}
	return {"ok": true, "data": parsed, "status": status}


func _process(_delta: float) -> void:
	if _discord_client != null:
		ClassDB.class_call_static(&"Discord", &"run_callbacks")


func sign_in_discord(remember: bool = true) -> Dictionary:
	if not _age_eligible():
		return {"ok": false, "error": "age_confirmation_required"}
	if _auth_busy or _refreshing:
		return {"ok": false, "error": "busy"}
	if not ClassDB.class_exists(&"DiscordClient"):
		return {"ok": false, "error": "discord_sdk_unavailable"}
	_auth_busy = true
	_remember_device = remember
	var config := await _request("/auth/discord/config", HTTPClient.METHOD_GET)
	if not config.ok:
		_auth_busy = false
		return config
	_discord_client = ClassDB.instantiate(&"DiscordClient")
	_discord_client.set_application_id(int(config.data.application_id))
	_discord_verifier = _discord_client.create_authorization_code_verifier()
	var args: Object = ClassDB.instantiate(&"DiscordAuthorizationArgs")
	args.set_client_id(int(config.data.application_id))
	args.set_scopes(ClassDB.class_call_static(&"DiscordClient", &"get_default_communication_scopes"))
	args.set_code_challenge(_discord_verifier.challenge())
	# SDK chooses the running desktop client, with its supported browser fallback.
	_discord_client.authorize(args, _on_discord_authorized)
	return await discord_sign_in_completed


func _age_eligible() -> bool:
	var policy := get_node_or_null("/root/AncientNestAgePolicy")
	return policy != null and policy.is_eligible()


func _on_discord_authorized(result: Variant, code: String, redirect_uri: String) -> void:
	var response: Dictionary = {"ok": false, "error": "discord_not_approved"}
	if not result.successful():
		# Restrict diagnostic text to a fixed vocabulary; arbitrary SDK strings may contain URLs/data.
		var diagnostic_text := str(result.error()).to_lower() + " " + str(result.response_body()).to_lower()
		var diagnostic_terms: Array[String] = []
		for term in ["invalid_scope", "invalid_request", "invalid_client", "unauthorized_client", "access_denied", "invalid_redirect_uri", "redirect_uri", "code_challenge", "code_verifier", "pkce", "public client", "client secret", "not enabled", "not approved", "not authorized", "not whitelisted", "social sdk", "social_layer", "timeout", "cancelled", "canceled", "state mismatch", "invalid state", "invalid_grant", "unsupported_response_type", "application does not exist", "missing", "scope", "redirect", "rpc", "oauth2"]:
			if term in diagnostic_text:
				diagnostic_terms.append(term)
		print("Discord authorization diagnostic categories: ", ", ".join(diagnostic_terms))
		# Numeric SDK diagnostics only: never log OAuth codes, callback queries or bodies.
		for diagnostic_method in ["type", "error_code", "status"]:
			if result.has_method(diagnostic_method):
				var diagnostic: Variant = result.call(diagnostic_method)
				if diagnostic is int or diagnostic is float:
					print("Discord authorization SDK %s: %d" % [diagnostic_method, int(diagnostic)])
	if result.successful():
		response = await _post("/auth/discord/exchange", {"code": code,
			"code_verifier": _discord_verifier.verifier(), "redirect_uri": redirect_uri})
		if response.ok:
			# Seed the voice connection before session_changed starts it. No second consent screen.
			var store: RefCounted = preload("credential_store.gd").new()
			store.service = "discord-oauth-refresh"
			store.device = str(response.data.user.id)
			if _remember_device:
				store.write_token(str(response.data.discord.refresh_token))
			else:
				store.clear_token()
			var voice_tokens: Dictionary = response.data.discord
			# Seed the verified account's voice tokens before session_changed starts voice setup.
			get_node("/root/AncientNestDiscordVoice").set_pending_tokens(voice_tokens, str(response.data.user.id))
			response = _accept_session(response.data)
	_discord_verifier = null
	_discord_client = null
	_auth_busy = false
	discord_sign_in_completed.emit(response)
