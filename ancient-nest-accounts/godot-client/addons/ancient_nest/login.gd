extends Control
## Discord is the sign-in provider. Usernames belong to the game profile.
@export var game_scene: PackedScene
var _form: VBoxContainer
var _signed_in: VBoxContainer
var _submit: Button
var _status: Label
var _username: LineEdit
var _remember: CheckBox
var _register := false # Compatibility for the startup smoke fixture.


func _ready() -> void:
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
	_signed_in = VBoxContainer.new()
	_signed_in.hide()
	card.add_child(_signed_in)
	_username = LineEdit.new()
	_username.placeholder_text = "Game username (3–24 letters, numbers, _ or -)"
	_username.max_length = 24
	_signed_in.add_child(_username)
	var save := Button.new()
	save.text = "Save game username"
	save.pressed.connect(_save_username)
	_signed_in.add_child(save)
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
		_status.text = "Discord sign-in failed or was cancelled. Try Continue with Discord again."


func _save_username() -> void:
	var response: Dictionary = await AncientNestAuth.authenticated_request("/profile/username", HTTPClient.METHOD_POST,
		{"username": _username.text.strip_edges()})
	if response.ok:
		AncientNestAuth.current_user = response.data.user
		AncientNestAuth.session_changed.emit(response.data.user)
		_status.text = "Game username saved."
	else:
		_status.text = "Choose an available username using 3–24 letters, numbers, _ or -."


func _enter_game(result: Dictionary) -> void:
	ProjectSettings.set_setting("ancient_nest/require_login", false)
	_form.hide()
	_signed_in.show()
	_username.text = str(AncientNestAuth.current_user.username)
	_status.text = "Signed in as %s" % AncientNestAuth.current_user.username
	if not str(result.get("warning", "")).is_empty():
		_status.text += " · Sign-in could not be saved on this device."
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)
	else:
		var original := str(ProjectSettings.get_setting("ancient_nest/original_main_scene", ""))
		if not original.is_empty():
			get_tree().change_scene_to_file(original)


func _sign_out() -> void:
	var result: Dictionary = await AncientNestAuth.sign_out()
	if result.ok:
		_show_form()
	else:
		_status.text = "Could not reach the server to sign out. Try again."
