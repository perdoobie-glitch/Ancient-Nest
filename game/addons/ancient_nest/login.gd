extends Control
## Discord is the sign-in provider. Usernames belong to the game profile.
@export var game_scene: PackedScene
var _form: VBoxContainer
var _signed_in: VBoxContainer
var _submit: Button
var _status: Label
var _username: LineEdit
var _remember: CheckBox
var _save_name: Button
var _continue_game: Button
var _profile_busy := false
var _register := false # Compatibility for the startup smoke fixture.


func _ready() -> void:
	if not AncientNestAgePolicy.is_eligible():
		get_tree().call_deferred("change_scene_to_file", "res://addons/ancient_nest/age_gate.tscn")
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.add_theme_constant_override("separation", 12)
	center.add_child(card)
	var title := Label.new()
	title.text = "Ancient Nest"
	title.add_theme_font_size_override("font_size", 28)
	card.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_status)
	_form = VBoxContainer.new()
	card.add_child(_form)
	_remember = CheckBox.new()
	_remember.text = "Stay signed in on this device"
	_remember.button_pressed = AncientNestAuth.can_remember_device()
	_remember.disabled = not AncientNestAuth.can_remember_device()
	_form.add_child(_remember)
	_submit = Button.new()
	_submit.text = "Continue with Discord"
	_submit.pressed.connect(_sign_in)
	_form.add_child(_submit)
	var offline_campaign=Button.new()
	offline_campaign.name="OfflineCampaign"
	offline_campaign.text="Campaign • Play offline"
	offline_campaign.pressed.connect(func():
		if not AncientNestAgePolicy.is_eligible():return
		get_tree().set_meta("open_offline_campaign",true)
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	card.add_child(offline_campaign)
	_signed_in = VBoxContainer.new()
	_signed_in.hide()
	card.add_child(_signed_in)
	var name_note := Label.new()
	name_note.text = "Choose the name other players see in Ancient Nest. Your game name is separate from your Discord identity."
	name_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_signed_in.add_child(name_note)
	_username = LineEdit.new()
	_username.placeholder_text = "Game username (3–24 letters, numbers, _ or -)"
	_username.max_length = 24
	_signed_in.add_child(_username)
	_save_name = Button.new()
	_save_name.text = "Save game username"
	_save_name.pressed.connect(_save_username)
	_signed_in.add_child(_save_name)
	_continue_game = Button.new()
	_continue_game.text = "Continue to Ancient Nest"
	_continue_game.disabled = true
	_continue_game.pressed.connect(_open_game)
	_signed_in.add_child(_continue_game)
	var logout := Button.new()
	logout.text = "Sign out"
	logout.pressed.connect(_sign_out)
	_signed_in.add_child(logout)
	AncientNestAuth.session_lost.connect(_show_form)
	await _restore()


func _show_form() -> void:
	_form.show()
	_signed_in.hide()
	_status.text = "Continue with your Discord account to play."


func _restore() -> void:
	_submit.disabled = true
	_status.text = "Checking saved sign-in…"
	var result: Dictionary = await AncientNestAuth.restore_session()
	_submit.disabled = false
	if result.ok:
		_enter_game(result)
	else:
		_show_form()
		if result.get("error", "") != "account_required":
			_status.text = "Saved sign-in failed. Continue with Discord again."


func _sign_in() -> void:
	_submit.disabled = true
	_status.text = "Approve Ancient Nest in Discord."
	var result: Dictionary = await AncientNestAuth.sign_in_discord(_remember.button_pressed)
	_submit.disabled = false
	if result.ok:
		_enter_game(result)
	else:
		# Report only known error codes/status, never OAuth codes, tokens or response bodies.
		var reason := str(result.get("error", "unknown"))
		var safe_reasons := ["busy", "discord_sdk_unavailable", "discord_not_approved", "network_error", "invalid_response", "invalid_api_url", "invalid_discord_authorization", "discord_authorization_expired", "discord_unavailable", "account_banned", "invalid_token", "username_conflict", "service_unavailable", "rate_limited"]
		if reason not in safe_reasons:
			reason = "service_error"
		var status := int(result.get("status", 0))
		_status.text = "Discord sign-in failed: %s (HTTP %d). Try Continue with Discord again." % [reason, status]
		print("Discord sign-in diagnostic: %s HTTP %d" % [reason, status])


func _save_username() -> void:
	if _profile_busy:
		return
	_profile_busy = true
	_save_name.disabled = true
	_continue_game.disabled = true
	var response: Dictionary = await AncientNestAuth.update_game_username(_username.text)
	_profile_busy = false
	_save_name.disabled = false
	if response.ok:
		_username.text = str(AncientNestAuth.current_user.username)
		_status.text = "Game username saved: %s" % AncientNestAuth.current_user.username
		_continue_game.disabled = false
	else:
		_status.text = "That game username is taken. Choose another." if response.get("status", 0) == 409 else "Choose an available username using 3–24 letters, numbers, _ or -."


func _enter_game(result: Dictionary) -> void:
	_form.hide()
	if _needs_username(AncientNestAuth.current_user):
		_signed_in.show()
		_username.text = ""
		_continue_game.disabled = true
		_status.text = "Discord connected. Choose your game username."
		_username.grab_focus()
		return
	_status.text = "Signed in as %s" % AncientNestAuth.current_user.username
	if not str(result.get("warning", "")).is_empty():
		_status.text += " · Sign-in could not be saved on this device."
	_open_game()


func _needs_username(user: Dictionary) -> bool:
	if user.has("needs_username"):
		return bool(user.needs_username)
	var generated := RegEx.new()
	generated.compile("^(?:.{1,3}_[0-9]{17,20}|Player_[a-f0-9]{16})$")
	return generated.search(str(user.get("username", ""))) != null


func _open_game() -> void:
	if _profile_busy or AncientNestAuth.current_user.is_empty() or _needs_username(AncientNestAuth.current_user):
		return
	ProjectSettings.set_setting("ancient_nest/require_login", false)
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)
	else:
		var original := str(ProjectSettings.get_setting("ancient_nest/original_main_scene", ""))
		if not original.is_empty():
			get_tree().call_deferred("change_scene_to_file", original)


func _sign_out() -> void:
	var result: Dictionary = await AncientNestAuth.sign_out()
	if result.ok:
		_show_form()
	else:
		_status.text = "Could not reach the server to sign out. Try again."
