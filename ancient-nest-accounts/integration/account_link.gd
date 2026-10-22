class_name NestAccountLink
extends Node
## Adapter for Ancient Nest's existing game account interface. Gameplay is unchanged.

signal assertion_refreshed(result: bool)
var game
var identity: CryptoKey
var account_assertion := ""
var assertion_until := 0.0
var state: Dictionary = {}
var refresh_in_progress := false
var status := "Signed in through Ancient Nest accounts."


func _ready() -> void:
	game.matchmaking.hybrid.load_identity()
	identity = game.matchmaking.hybrid.identity
	state = AncientNestAuth.current_user.duplicate()
	state["account_id"] = state.get("id", "")


func linked() -> bool:
	return not AncientNestAuth.current_user.is_empty()


func clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func key_hash() -> String:
	return identity.save_to_string(true).sha256_text()


func refresh_session() -> bool:
	if refresh_in_progress:
		return await assertion_refreshed
	if not linked():
		return false
	if not account_assertion.is_empty() and clock() < assertion_until - 30:
		return true
	refresh_in_progress = true
	var user_id: String = AncientNestAuth.current_user.id
	var response: Dictionary = await AncientNestAuth.authenticated_request("/api/game/assertion", HTTPClient.METHOD_POST,
		{"public_key": identity.save_to_string(true)})
	var ok: bool = response.ok and linked() and str(AncientNestAuth.current_user.get("id", "")) == user_id
	if ok:
		var data: Dictionary = response.data
		ok = data.get("account_id") == user_id and data.get("key_hash") == key_hash() and data.get("assertion") is String
		if ok:
			account_assertion = data.assertion
			assertion_until = clock() + minf(600, float(data.get("expires_in", 0)))
			state["username"] = AncientNestAuth.current_user.username
			if is_instance_valid(game.prefs):
				game.prefs.values.username = state.username
				game.prefs.save()
	if not ok:
		account_assertion = ""
		assertion_until = 0
		status = "Account session could not be refreshed. Check your connection or sign in again."
	refresh_in_progress = false
	assertion_refreshed.emit(ok)
	return ok


func _process(_delta: float) -> void:
	if not account_assertion.is_empty() and clock() > assertion_until - 30 and not refresh_in_progress:
		if game.matchmaking.hybrid.enabled:
			_refresh_connected()


func _refresh_connected() -> void:
	if await refresh_session():
		game.matchmaking.hybrid.send({"type": "account_refresh", "account_assertion": account_assertion})


func show_panel() -> void:
	if game.running:
		return
	game.current_screen = "account"
	game.context = "menu"
	game.clear_screen()
	game.shade(0.90)
	game.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel = game.center_panel(820, 690)
	game.header(panel, "ANCIENT NEST ACCOUNT", "Account")
	panel.add_child(game.label("Signed in as " + str(AncientNestAuth.current_user.get("username", "Player")), 26, game.GOLD))
	panel.add_child(game.label("Account ID: " + str(AncientNestAuth.current_user.get("id", "")), 13))
	panel.add_child(game.label(status, 15))
	panel.add_child(game.button("Verify email and phone", func() -> void: await AncientNestVerification.refresh_status()))
	panel.add_child(game.label("Use Connect Discord in the voice panel to authorize your own Discord account.\nTeam voice uses your server-assigned team room.", 15))
	panel.add_child(game.button("Sign out", func() -> void: await AncientNestAuth.sign_out()))
	panel.add_child(game.button("Back to main menu", game.show_main))


func begin_link() -> void:
	show_panel()


func forget_local() -> void:
	await AncientNestAuth.sign_out()
