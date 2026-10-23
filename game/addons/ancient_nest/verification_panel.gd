extends CanvasLayer
## Verification status is supplied to matchmaking as flags; this panel does not change game admission policy.

var _panel: PanelContainer
var _status: Label
var _email: Label
var _phone: Label
var _email_code: LineEdit
var _phone_code: LineEdit
var _buttons: Array[Button] = []
var _user_id := ""
var _generation := 0
var _busy := false


func _ready() -> void:
	if not bool(ProjectSettings.get_setting("ancient_nest/legacy_accounts", false)):
		return
	layer = 49
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Verify your account"
	box.add_child(title)
	_email = Label.new()
	box.add_child(_email)
	_email_code = _code_row(box, "email")
	_phone = Label.new()
	box.add_child(_phone)
	_phone_code = _code_row(box, "phone")
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var hide_button := Button.new()
	hide_button.text = "Close"
	hide_button.pressed.connect(_panel.hide)
	box.add_child(hide_button)
	_panel.hide()
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)
	AncientNestAuth.session_changed.connect(_on_session)
	AncientNestAuth.session_lost.connect(_on_logout)
	if not AncientNestAuth.current_user.is_empty():
		_on_session(AncientNestAuth.current_user)


func _position_panel() -> void:
	_panel.position = Vector2(maxf(16.0, get_viewport().get_visible_rect().size.x - 432.0), 16)


func _code_row(box: VBoxContainer, type: String) -> LineEdit:
	var row := HBoxContainer.new()
	box.add_child(row)
	var field := LineEdit.new()
	field.placeholder_text = "6-digit code"
	field.max_length = 6
	field.custom_minimum_size.x = 150
	row.add_child(field)
	var verify := Button.new()
	verify.text = "Verify"
	verify.pressed.connect(func() -> void: await _submit(type, field))
	row.add_child(verify)
	_buttons.append(verify)
	var resend := Button.new()
	resend.text = "Resend"
	resend.pressed.connect(func() -> void: await _resend(type))
	row.add_child(resend)
	_buttons.append(resend)
	return field


func _on_session(user: Dictionary) -> void:
	if _user_id == str(user.id):
		return
	_generation += 1
	_user_id = str(user.id)
	_set_busy(false)
	await refresh_status()


func _on_logout() -> void:
	_generation += 1
	_user_id = ""
	_set_busy(false)
	_email_code.clear()
	_phone_code.clear()
	_panel.hide()


func refresh_status() -> void:
	if _user_id.is_empty():
		return
	var generation := _generation
	var response: Dictionary = await AncientNestAuth.authenticated_request("/account")
	if generation != _generation or not response.ok:
		return
	var account: Dictionary = response.data
	_email.text = "Email: %s · %s" % [account.email, "verified" if account.email_verified else "not verified"]
	_phone.text = "Phone: %s · %s" % [account.phone, "verified" if account.phone_verified else "not verified"]
	_panel.visible = not (account.email_verified and account.phone_verified)
	_status.text = "Enter the codes sent to your email and phone."
	if not AncientNestAuth.last_verification_send_errors.is_empty():
		_status.text = "One or both codes couldn't be sent. Try Resend when your connection is available."


func _set_busy(value: bool) -> void:
	_busy = value
	for button in _buttons:
		button.disabled = value


func _submit(type: String, field: LineEdit) -> void:
	if _busy:
		return
	_set_busy(true)
	var generation := _generation
	var response: Dictionary = await AncientNestAuth.authenticated_request("/verify/" + type, HTTPClient.METHOD_POST,
		{"code": field.text.strip_edges()})
	if generation != _generation:
		return
	_set_busy(false)
	field.clear()
	if response.ok:
		await refresh_status()
	else:
		_status.text = "That code is invalid, expired, or has too many attempts. Use Resend for a new code."


func _resend(type: String) -> void:
	if _busy:
		return
	_set_busy(true)
	var generation := _generation
	var response: Dictionary = await AncientNestAuth.authenticated_request("/verify/" + type + "/resend", HTTPClient.METHOD_POST, {})
	if generation != _generation:
		return
	_set_busy(false)
	if response.ok:
		_status.text = "A new %s code was sent. It expires in 10 minutes." % type
	else:
		_status.text = "We couldn't send a new code. Please wait before retrying, then contact support if it continues."
