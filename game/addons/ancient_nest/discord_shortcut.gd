extends CanvasLayer
## Persistent dashboard overlay. Does not change scenes or stop online simulation.
var panel: Control
var _game: Node
var _previous_context := ""
var _previous_mouse := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	AncientNestAuth.session_changed.connect(func(user: Dictionary):
		if user.is_empty(): close_dashboard())

func is_open() -> bool:
	return is_instance_valid(panel)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_open() and event.keycode == KEY_ESCAPE:
		close_dashboard()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_I or event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is CodeEdit: return
	var game := AncientNestDiscordSocial.game_node()
	if is_instance_valid(game) and not str(game.binding_action).is_empty(): return
	if not AncientNestAgePolicy.is_eligible(): return
	if is_open(): close_dashboard()
	else: open_dashboard(game)
	get_viewport().set_input_as_handled()

func open_dashboard(game: Node = null) -> void:
	if not AncientNestAgePolicy.is_eligible() or is_open(): return
	_game = game
	_previous_mouse = Input.mouse_mode
	if is_instance_valid(_game):
		_previous_context = _game.context
		_game.clear_held_input()
		_game.context = "discord_dashboard"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel = Control.new()
	panel.name = "GlobalDiscordDashboard"
	if is_instance_valid(game): panel.theme = game.make_theme()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.04,0.035,0.96)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = "DISCORD DASHBOARD"
	title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Close · I / Esc"
	close.pressed.connect(close_dashboard)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var dashboard = load("res://addons/ancient_nest/discord_dashboard.gd").new()
	dashboard.game = game
	dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dashboard)
	close.grab_focus()

func _process(_delta: float) -> void:
	if is_open() and not is_instance_valid(_game):
		var game := AncientNestDiscordSocial.game_node()
		if is_instance_valid(game):
			_game = game
			_previous_context = game.context
			_previous_mouse = Input.mouse_mode
			var dashboard := panel.find_child("DiscordDashboard",true,false)
			if dashboard != null: dashboard.game = game
	if is_open() and is_instance_valid(_game) and _game.context != "discord_dashboard":
		_previous_context = _game.context
		_game.context = "discord_dashboard"
		_game.clear_held_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_dashboard() -> void:
	if not is_open(): return
	remove_child(panel)
	panel.queue_free()
	panel = null
	if is_instance_valid(_game) and _game.context == "discord_dashboard":
		_game.context = _previous_context
		_game.clear_held_input()
		Input.mouse_mode = _previous_mouse
	else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game = null
