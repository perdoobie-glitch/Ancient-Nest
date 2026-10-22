extends Control
## Make this scene the game's startup scene and assign game_scene in the Inspector.

@export var game_scene: PackedScene
var _username: LineEdit
var _email: LineEdit
var _phone: LineEdit
var _password: LineEdit
var _confirm: LineEdit
var _remember: CheckBox
var _submit: Button
var _switch: Button
var _status: Label
var _title: Label
var _form: VBoxContainer
var _signed_in: VBoxContainer
var _welcome: Label
var _register := true


func _ready() -> void:
	_build_ui()
	AncientNestAuth.session_lost.connect(_on_session_lost)
	await _restore()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.add_theme_constant_override("separation", 12)
	center.add_child(card)
	_title = Label.new()
	_title.text = "Welcome to Ancient Nest"
	_title.add_theme_font_size_override("font_size", 28)
	card.add_child(_title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_status)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 12)
	card.add_child(_form)
	_username = LineEdit.new()
	_username.placeholder_text = "Username"
	_username.max_length = 24
	_form.add_child(_username)
	_email = LineEdit.new()
	_email.placeholder_text = "Email address (required)"
	_email.max_length = 254
	_form.add_child(_email)
	_phone = LineEdit.new()
	_phone.placeholder_text = "Phone number, including country code (required)"
	_phone.max_length = 32
	_form.add_child(_phone)
	_password = LineEdit.new()
	_password.placeholder_text = "Password (8–128 characters)"
	_password.secret = true
	_password.max_length = 128
	_form.add_child(_password)
	_confirm = LineEdit.new()
	_confirm.placeholder_text = "Confirm password"
	_confirm.secret = true
	_confirm.max_length = 128
	_form.add_child(_confirm)
	_remember = CheckBox.new()
	_remember.text = "Stay signed in on this device"
	_remember.button_pressed = AncientNestAuth.can_remember_device()
	_remember.disabled = not AncientNestAuth.can_remember_device()
	_form.add_child(_remember)
	_submit = Button.new()
	_submit.text = "Create account"
	_submit.pressed.connect(_submit_account)
	_form.add_child(_submit)
	_switch = Button.new()
	_switch.text = "Already have an account? Sign in"
	_switch.pressed.connect(_switch_mode)
	_form.add_child(_switch)
	_signed_in = VBoxContainer.new()
	_signed_in.hide()
	card.add_child(_signed_in)
	_welcome = Label.new()
	_signed_in.add_child(_welcome)
	var sign_out := Button.new()
	sign_out.text = "Sign out"
	sign_out.pressed.connect(_sign_out)
	_signed_in.add_child(sign_out)


func _busy(value: bool) -> void:
	_submit.disabled = value
	_switch.disabled = value
	_username.editable = not value
	_email.editable = not value
	_phone.editable = not value
	_password.editable = not value
	_confirm.editable = not value


func _restore() -> void:
	_busy(true)
	_status.text = "Checking saved sign-in…"
	var result: Dictionary = await AncientNestAuth.restore_session()
	_busy(false)
	if result.ok:
		_enter_game(result)
	elif result.error == "account_required":
		_show_form()
	else:
		_register = false
		_apply_mode()
		_show_form()
		_status.text = "Saved sign-in couldn't be restored. Sign in again to continue."


func _on_session_lost() -> void:
	_register = false
	_apply_mode()
	_show_form()


func _show_form() -> void:
	_form.show()
	_signed_in.hide()
	_status.text = "Create your account to start playing." if _register else "Sign in to your account."
	if not AncientNestAuth.can_remember_device():
		_status.text += " Secure sign-in storage isn't available on this device; this session won't be remembered."


func _switch_mode() -> void:
	_register = not _register
	_apply_mode()
	_show_form()


func _apply_mode() -> void:
	_confirm.visible = _register
	_email.visible = _register
	_phone.visible = _register
	_password.clear()
	_confirm.clear()
	_submit.text = "Create account" if _register else "Sign in"
	_switch.text = "Already have an account? Sign in" if _register else "New here? Create an account"


func _submit_account() -> void:
	if _register and _password.text != _confirm.text:
		_status.text = "The passwords don't match."
		return
	_busy(true)
	_status.text = "Creating account…" if _register else "Signing in…"
	var result: Dictionary
	if _register:
		result = await AncientNestAuth.create_account(_username.text.strip_edges(), _password.text, _remember.button_pressed,
			_email.text.strip_edges(), _phone.text.strip_edges())
	else:
		result = await AncientNestAuth.sign_in(_username.text.strip_edges(), _password.text, _remember.button_pressed)
	_password.clear()
	_confirm.clear()
	_busy(false)
	if result.ok:
		_enter_game(result)
	else:
		var messages := {
			"username_taken": "That username is taken. Choose another or sign in.",
			"account_already_registered": "That username, email, or phone is already registered. Sign in or use different details.",
			"valid_email_required": "Enter a valid email address.",
			"valid_phone_required": "Enter your phone number with its country code, such as +12345678900.",
			"invalid_credentials": "The username or password is incorrect.",
			"rate_limited": "Too many attempts. Please wait before trying again.",
			"network_error": "We couldn't connect. Check your connection and try again.",
			"password_must_be_8_to_128_characters": "Use a password with 8–128 characters.",
			"username_must_be_3_to_24_ascii_letters_digits_or_underscores": "Use 3–24 letters, numbers, or underscores for your username.",
			"secure_storage_unavailable": "We couldn't save sign-in securely. Try again with Stay signed in turned off."
		}
		_status.text = messages.get(result.error, "We couldn't sign you in. Please try again.")


func _enter_game(result: Dictionary) -> void:
	_form.hide()
	_signed_in.show()
	_title.text = "Ancient Nest"
	_welcome.text = "Signed in as %s" % AncientNestAuth.current_user.username
	_status.text = "You're ready to play."
	if not str(result.get("warning", "")).is_empty():
		_status.text = "You're signed in for this session, but we couldn't save sign-in on this device."
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)


func _sign_out() -> void:
	var result: Dictionary = await AncientNestAuth.sign_out()
	if result.ok:
		_show_form()
	else:
		_status.text = "We couldn't reach the account service to sign out. Please try again."
