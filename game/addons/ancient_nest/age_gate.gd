extends Control
## First interactive screen, before saved-login restoration or Discord SDK authorization.
const LOGIN_SCENE := "res://addons/ancient_nest/login.tscn"
var confirmation: CheckBox
var continue_button: Button
var underage_button: Button
var status_label: Label
var _transitioning := false
var _card: VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if AncientNestAgePolicy.is_eligible():
		get_tree().call_deferred("change_scene_to_file", LOGIN_SCENE)
		return
	# Existing installations signed in only after the old age gate. Validate that
	# saved login once to carry its declaration forward, without asking again.
	set_meta("restoring_age_confirmation", true)
	var restored := await AncientNestAgePolicy.restore_previous_sign_in(AncientNestAuth)
	remove_meta("restoring_age_confirmation")
	if restored:
		get_tree().call_deferred("change_scene_to_file", LOGIN_SCENE)
		return
	var background := ColorRect.new()
	background.color = Color("121820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 18)
	center.add_child(_card)
	_label("ANCIENT NEST", 22, Color("d6b878"))
	_label(AncientNestAgePolicy.NOTICE, 34)
	_label(AncientNestAgePolicy.DISCLOSURE, 18)
	_label(AncientNestAgePolicy.CONTENT_NOTICE, 20)
	_label("Online voice and player communication may contain content created by other players.", 18)
	_label("You must be 18 or older to play this edition. Confirm your age before Discord sign-in. No birth date is collected or stored; this is a self-declaration.", 18)
	confirmation = CheckBox.new()
	confirmation.text = "I confirm I am 18 years of age or older."
	confirmation.toggled.connect(_confirmation_changed)
	_card.add_child(confirmation)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size.y = 48
	continue_button.disabled = true
	continue_button.pressed.connect(_continue)
	_card.add_child(continue_button)
	underage_button = Button.new()
	underage_button.text = "I am under 18"
	underage_button.custom_minimum_size.y = 44
	underage_button.pressed.connect(_decline)
	_card.add_child(underage_button)
	status_label = _label("", 18)
	var exit_button := Button.new()
	exit_button.text = "Exit game"
	exit_button.custom_minimum_size.y = 44
	exit_button.pressed.connect(func(): get_tree().quit())
	_card.add_child(exit_button)
	resized.connect(_layout)
	_layout()
	if AncientNestAgePolicy.declined:
		_decline()
	confirmation.grab_focus()

func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_card.add_child(label)
	return label

func _layout() -> void:
	if _card != null:
		_card.custom_minimum_size.x = clampf(size.x - 72, 280, 650)

func _confirmation_changed(checked: bool) -> void:
	continue_button.disabled = not checked or AncientNestAgePolicy.declined or _transitioning

func _continue() -> void:
	if _transitioning or not confirmation.button_pressed or not AncientNestAgePolicy.confirm_adult():
		return
	_transitioning = true
	continue_button.disabled = true
	if get_tree().change_scene_to_file(LOGIN_SCENE) != OK:
		_transitioning = false
		AncientNestAgePolicy.confirmed_adult = false
		status_label.text = "Unable to open sign-in. Please restart Ancient Nest."

func _decline() -> void:
	AncientNestAgePolicy.decline()
	confirmation.set_pressed_no_signal(false)
	confirmation.disabled = true
	continue_button.disabled = true
	underage_button.disabled = true
	status_label.text = "Ancient Nest is restricted to players aged 18 and older. Discord sign-in and gameplay remain unavailable."
