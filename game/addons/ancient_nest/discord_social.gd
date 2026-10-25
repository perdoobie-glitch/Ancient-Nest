extends Node
signal invite_status_changed(message: String)
signal inbox_changed
## Discord owns the friend list and invitation delivery. The master validates party admission.
## No bot/coordinator keys or Discord identity are published in party payloads.
const JOIN_PREFIX := "ancientnest:party:v1:"
var _client: Object
var _application_id := 0
var _generation := 0
var _sdk_ready := false
var _game_ref: WeakRef
var _presence_key := ""
var _presence_code := ""
var _presence_busy := false
var _presence_retry_at := 0.0
var _pending_join_code := ""
var _pending_join_until := 0.0
var _joining_code := ""
var _joining_until := 0.0
var _join_started := false
var _friends_dialog: AcceptDialog
var _friends_status: Label
var _last_invite_at := -10.0
var _last_join_request_at := -10.0
var _pending_join_token := ""
var _joining_token := ""
var _inbox: Dictionary = {}
var _handled_inbox: Dictionary = {}
const PRIVATE_JOIN_PREFIX := "ancientnest:party:v2:"
var _last_join_secret := ""
var _last_join_until := 0.0

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()

func attach_game(game: Node) -> void:
	_game_ref = weakref(game)
	_presence_key = ""

func game_node() -> Node:
	return _game_ref.get_ref() if _game_ref != null else null

func attach_client(client: Object, application_id: int) -> void:
	detach_client()
	_client = client
	_application_id = application_id
	_client.set_activity_join_callback(_on_activity_join.bind(_generation))
	if _client.has_method("set_activity_invite_created_callback"):
		_client.set_activity_invite_created_callback(_on_activity_invite.bind(_generation))
		_client.set_activity_invite_updated_callback(_on_activity_invite.bind(_generation))
	var executable := OS.get_executable_path()
	var command := '"%s"' % executable
	if not OS.has_feature("template"):
		command += ' --path "%s"' % ProjectSettings.globalize_path("res://")
	# Supported SDK registration is local to this PC; never registers an old project copy.
	_client.register_launch_command(application_id, command)

func detach_client() -> void:
	if _client != null and _sdk_ready:
		_client.clear_rich_presence()
	_generation += 1
	_client = null
	_sdk_ready = false
	_presence_key = ""
	_presence_code = ""
	_presence_busy = false
	_presence_retry_at = 0
	_pending_join_code = ""
	_joining_code = ""
	_join_started = false
	_pending_join_token = ""
	_joining_token = ""
	_inbox.clear()
	_handled_inbox.clear()
	_last_join_secret = ""
	_last_join_until = 0.0
	inbox_changed.emit()
	for dialog in [_friends_dialog]:
		if is_instance_valid(dialog): dialog.queue_free()

func set_connected(connected: bool) -> void:
	_sdk_ready = connected
	_presence_key = ""
	_presence_code = ""
	if connected: _tick()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func valid_party_code(code: String) -> bool:
	if code.length() != 10: return false
	for character in code:
		if character not in "0123456789ABCDEF": return false
	return true

func parse_join_secret(secret: String) -> String:
	if secret.begins_with(PRIVATE_JOIN_PREFIX):
		var pieces := secret.substr(PRIVATE_JOIN_PREFIX.length()).split(":")
		if pieces.size() != 2 or not valid_party_code(pieces[0]) or not valid_invite_token(pieces[1]): return ""
		return pieces[0]
	if not secret.begins_with(JOIN_PREFIX): return ""
	var code := secret.substr(JOIN_PREFIX.length())
	return code if valid_party_code(code) else ""

func valid_invite_token(token: String) -> bool:
	if token.length() != 32: return false
	for character in token:
		if character not in "0123456789abcdef": return false
	return true

func invite_secret(snapshot: Dictionary) -> String:
	if str(snapshot.code).is_empty(): return ""
	var token := str(snapshot.get("invite_token", ""))
	return PRIVATE_JOIN_PREFIX + str(snapshot.code) + ":" + token if valid_invite_token(token) else JOIN_PREFIX + str(snapshot.code)

func party_snapshot() -> Dictionary:
	var game := game_node()
	if game == null: return {"state": "Signing in", "code": "", "size": 0, "maximum": 0}
	var mm = game.matchmaking
	var code := str(mm.party.get("code", ""))
	var size: int = mm.party.get("members", []).size()
	var maximum := int(mm.team_size())
	var available: bool = not game.running and mm.phase == "party" and mm.hybrid.master_connected() and size > 0 and size < maximum and valid_party_code(code)
	return {"state": "In a match" if game.running else "In a party" if not mm.party.is_empty() else "In menus",
		"code": code if available else "", "size": size, "maximum": maximum,
		"privacy": str(mm.party.get("privacy", "open")), "invite_token": str(mm.party.get("invite_token", "")) if available else ""}

func _tick() -> void:
	_prune_inbox()
	if not _sdk_ready or _client == null or not AncientNestAgePolicy.is_eligible(): return
	_update_presence()
	_auto_reply_open_requests()
	_check_pending_join()
	_advance_join()

func _update_presence() -> void:
	var snapshot := party_snapshot()
	var key := JSON.stringify(snapshot)
	if _presence_busy or key == _presence_key or _now() < _presence_retry_at: return
	_presence_busy = true
	var activity: Object = ClassDB.instantiate(&"DiscordActivity")
	activity.set_type(ClassDB.class_get_integer_constant(&"DiscordActivityTypes", &"PLAYING"))
	activity.set_details("Ancient Nest")
	activity.set_state(snapshot.state)
	if not str(snapshot.code).is_empty():
		var party: Object = ClassDB.instantiate(&"DiscordActivityParty")
		party.set_id("ancientnest-party-" + str(snapshot.code))
		party.set_current_size(int(snapshot.size))
		party.set_max_size(int(snapshot.maximum))
		activity.set_party(party)
		var secrets: Object = ClassDB.instantiate(&"DiscordActivitySecrets")
		secrets.set_join(invite_secret(snapshot))
		activity.set_secrets(secrets)
		activity.set_supported_platforms(ClassDB.class_get_integer_constant(&"DiscordActivityGamePlatforms", &"DESKTOP"))
	_client.update_rich_presence(activity, _on_presence_updated.bind(_generation, key, invite_secret(snapshot)))

func _on_presence_updated(result: Variant, generation: int, key: String, code: String) -> void:
	if generation != _generation: return
	_presence_busy = false
	if result.successful():
		_presence_key = key
		_presence_code = code
		_auto_reply_open_requests.call_deferred()
	else:
		_presence_key = ""
		_presence_code = ""
		_presence_retry_at = _now() + 10.0

func show_invite_dialog(game: Node) -> void:
	attach_game(game)
	if is_instance_valid(_friends_dialog): _friends_dialog.queue_free()
	_friends_dialog = AcceptDialog.new()
	_friends_dialog.title = "Invite Discord friends"
	_friends_dialog.ok_button_text = "Close"
	_friends_dialog.min_size = Vector2i(420, 360)
	game.add_child(_friends_dialog)
	_friends_dialog.confirmed.connect(_friends_dialog.queue_free)
	_friends_dialog.canceled.connect(_friends_dialog.queue_free)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(410, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_friends_dialog.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	_friends_status = Label.new()
	_friends_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_friends_status)
	var snapshot := party_snapshot()
	if not _sdk_ready:
		_friends_status.text = "Discord is still connecting. Wait for Discord connected, then reopen Invite. Your game sign-in stays active."
	elif str(snapshot.code).is_empty():
		_friends_status.text = "Invites are available in a connected party with space. Choose a larger team playlist if the party is full, and cancel search before inviting."
	else:
		_friends_status.text = "Choose a Discord friend to invite to your Ancient Nest party."
		var friends := friend_choices()
		if friends.is_empty():
			_friends_status.text = "No Discord friends are available in the SDK yet. You can also send a game invite from Discord or use Copy party code."
		for friend in friends:
			var invite := Button.new()
			invite.text = "Invite " + str(friend.label)
			invite.clip_text = true
			invite.custom_minimum_size.y = 40
			invite.pressed.connect(_send_invite.bind(int(friend.id)))
			rows.add_child(invite)
	var copy := Button.new()
	copy.text = "Copy party code"
	copy.disabled = not valid_party_code(str(game.matchmaking.party.get("code", "")))
	copy.pressed.connect(func(): DisplayServer.clipboard_set(str(game.matchmaking.party.get("code", ""))); _friends_status.text = "Party code copied. Your friend can use Play → Join Party.")
	rows.add_child(copy)
	_friends_dialog.popup_centered(Vector2i(460, 420))

func friend_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not _sdk_ready or _client == null: return choices
	var friend_type := ClassDB.class_get_integer_constant(&"DiscordRelationshipType", &"FRIEND")
	for relationship in _client.get_relationships():
		if relationship.discord_relationship_type() != friend_type: continue
		var user: Object = relationship.user()
		if user == null: continue
		var friend_label := str(user.display_name()).strip_edges()
		if friend_label.is_empty(): friend_label = str(user.username())
		var presence := friend_presence(user)
		choices.append({"id": str(user.id()), "label": friend_label.left(80), "status": presence.status, "online": presence.online, "activity": presence.activity})
		choices[-1]["playing_ancient_nest"] = bool(presence.get("playing_ancient_nest", false))
	choices.sort_custom(func(a, b):
		if bool(a.online) != bool(b.online): return bool(a.online)
		return str(a.label).naturalnocasecmp_to(str(b.label)) < 0)
	return choices

func friend_presence(user: Object) -> Dictionary:
	var result := {"status": "Status unavailable", "online": false, "activity": ""}
	if not user.has_method("status"): return result
	var value: int = user.status()
	for key in ["ONLINE", "IDLE", "DND", "STREAMING", "OFFLINE", "INVISIBLE", "UNKNOWN"]:
		if value != ClassDB.class_get_integer_constant(&"DiscordStatusType", key): continue
		result.online = key in ["ONLINE", "IDLE", "DND", "STREAMING"]
		result.status = {"ONLINE":"Online", "IDLE":"Away", "DND":"Do not disturb", "STREAMING":"Streaming", "OFFLINE":"Offline", "INVISIBLE":"Offline", "UNKNOWN":"Status unavailable"}[key]
		break
	# Respect SDK-reported offline/invisible state; never infer hidden online activity.
	if result.online and user.has_method("game_activity"):
		var activity: Object = user.game_activity()
		if activity != null:
			result.activity = str(activity.name()).left(80)
			if activity.has_method("application_id"): result["playing_ancient_nest"] = int(activity.application_id()) == _application_id
	return result

func is_discord_connected() -> bool:
	return _sdk_ready and _client != null

func invite_friend(user_id: int) -> void:
	_send_invite(user_id)

func _send_invite(user_id: int) -> void:
	if not AncientNestAgePolicy.is_eligible(): return
	var code := str(party_snapshot().code)
	if not _sdk_ready or _client == null or code.is_empty():
		_set_invite_status("This party is no longer accepting invites.")
		return
	# Only current Discord friends from the SDK picker may receive an invite.
	if not friend_choices().any(func(friend): return int(friend.id) == user_id): return
	if _presence_code != invite_secret(party_snapshot()):
		_set_invite_status("Updating your Discord party presence. Try Invite again in a moment.")
		_update_presence()
		return
	if _now() - _last_invite_at < 2.0: return
	_last_invite_at = _now()
	_set_invite_status("Sending invite…")
	_client.send_activity_invite(user_id, "Join my Ancient Nest party!", _on_invite_sent.bind(_generation))

func _on_invite_sent(result: Variant, generation: int) -> void:
	if generation != _generation: return
	_set_invite_status("Discord invite sent." if result.successful() else "Discord couldn't send this invite. Check your connection and party availability.")

func _set_invite_status(message: String) -> void:
	if is_instance_valid(_friends_status): _friends_status.text = message
	invite_status_changed.emit(message)

func _on_activity_join(secret: String, generation: int) -> void:
	if generation != _generation: return
	var code := parse_join_secret(secret)
	if code.is_empty(): return
	# The SDK may report both accept-invite and activity-join for the same user click.
	if secret == _last_join_secret and _now() < _last_join_until: return
	if code == _pending_join_code or code == _joining_code: return
	_last_join_secret = secret
	_last_join_until = _now() + 10.0
	_pending_join_token = secret.get_slice(":", 4) if secret.begins_with(PRIVATE_JOIN_PREFIX) else ""
	_pending_join_code = code
	_pending_join_until = _now() + 120.0
	_check_pending_join()

func _check_pending_join() -> void:
	if not AncientNestAgePolicy.is_eligible(): return
	if _pending_join_code.is_empty(): return
	if _now() > _pending_join_until:
		_pending_join_code = ""
		_pending_join_token = ""
		return
	var game := game_node()
	if game == null or AncientNestAuth.current_user.is_empty() or AncientNestAuth.current_user.get("needs_username", false): return
	if game.running or game.matchmaking.phase not in ["idle", "error", "party", "connecting"]:
		_pending_join_code = ""
		_pending_join_token = ""
		_last_join_until = 0.0 # Allow a fresh click immediately after leaving search/match.
		_set_invite_status("Leave your match or cancel search, then accept the invitation again to join your friend.")
		return # Never pull a player out of a ranked search or active match.
	# Clicking Join in Discord (or Accept in our inbox) is the user's join action.
	_joining_code = _pending_join_code
	_joining_token = _pending_join_token
	_joining_until = _now() + 20.0
	_join_started = false
	_pending_join_code = ""
	_pending_join_token = ""
	_set_invite_status("Joining your friend's lobby…")
	_advance_join()

func _advance_join() -> void:
	if _joining_code.is_empty(): return
	var game := game_node()
	if game == null: return
	var mm = game.matchmaking
	if _now() > _joining_until or game.running or mm.phase not in ["idle", "error", "party", "connecting"]:
		if not game.running:
			mm.status = "Discord party join expired or became unavailable. Ask your friend for another invite."
			mm.changed()
		_joining_code = ""
		_joining_token = ""
		return
	if mm.phase == "party" and mm.hybrid.master_connected():
		mm.cancel_search_countdown()
		var payload := {"code": _joining_code}
		if not _joining_token.is_empty(): payload["invite_token"] = _joining_token
		mm.party_action("join", payload)
		_joining_code = ""
		_joining_token = ""
		AncientNestDiscordShortcut.close_dashboard()
		game.show_matchmaking()
	elif mm.phase == "connecting":
		_join_started = true # Wait for the existing authenticated connection.
	elif not _join_started:
		_join_started = true
		mm.open_party()
		game.show_matchmaking()

func _exit_tree() -> void:
	detach_client()

func can_join_friend() -> bool:
	var game := game_node()
	return is_instance_valid(game) and not game.running and game.matchmaking.phase in ["idle", "error", "party", "connecting"] and not AncientNestAuth.current_user.is_empty() and not AncientNestAuth.current_user.get("needs_username", false)

func request_join_friend(user_id: int) -> void:
	if not is_discord_connected() or not can_join_friend() or not AncientNestAgePolicy.is_eligible():
		_set_invite_status("Finish sign-in and leave your match or search before joining a friend.")
		return
	if not friend_choices().any(func(friend): return int(friend.id) == user_id and bool(friend.get("playing_ancient_nest", false))): return
	if _now() - _last_join_request_at < 3.0: return
	_last_join_request_at = _now()
	_set_invite_status("Requesting to join your friend's lobby…")
	_client.send_activity_join_request(user_id, _on_join_request_sent.bind(_generation))

func _on_join_request_sent(result: Variant, generation: int) -> void:
	if generation != _generation: return
	_set_invite_status("Join request sent. Open lobbies reply automatically; private lobbies need approval. Accept the returned invitation here." if result.successful() else "Discord could not send the join request. Your friend may not have a joinable lobby.")

func set_lobby_privacy(privacy: String) -> void:
	var game := game_node()
	if not is_instance_valid(game) or game.running or game.matchmaking.phase != "party": return
	var mm = game.matchmaking
	if not mm.party_leader() or not mm.party.get("lobby_privacy_supported", false): return
	mm.cancel_search_countdown()
	mm.party_action("privacy", {"privacy":privacy})

func _on_activity_invite(invite: Object, generation: int) -> void:
	if generation != _generation or not is_discord_connected() or not AncientNestAgePolicy.is_eligible(): return
	if invite.application_id() != _application_id: return
	var id := str(invite.message_id())
	if not invite.is_valid():
		_inbox.erase(id)
		inbox_changed.emit()
		return
	if _handled_inbox.has(id) or _inbox.has(id): return
	var friends := friend_choices().filter(func(friend): return int(friend.id) == invite.sender_id())
	if friends.is_empty(): return
	var request: bool = invite.type() == ClassDB.class_get_integer_constant(&"DiscordActivityActionTypes", &"JOIN_REQUEST")
	if not request and invite.type() != ClassDB.class_get_integer_constant(&"DiscordActivityActionTypes", &"JOIN"): return
	_prune_inbox()
	if _inbox.size() >= 32: return
	_inbox[id] = {"invite":invite,"label":str(friends[0].label),"request":request,"expires":_now()+300.0,"busy":false,"retry_at":0.0}
	# Open means a friend may ask to join without host approval. Never do this for private lobbies.
	if request and str(party_snapshot().get("privacy", "open")) == "open" and not str(party_snapshot().code).is_empty():
		respond_to_invite(id)
	inbox_changed.emit()

func inbox_entries() -> Array:
	_prune_inbox()
	var entries: Array = []
	for id in _inbox:
		var item: Dictionary = _inbox[id]
		entries.append({"id":id,"label":item.label,"request":item.request,"busy":item.busy})
	return entries

func _auto_reply_open_requests() -> void:
	if not is_discord_connected() or party_snapshot().get("privacy", "open") != "open" or str(party_snapshot().code).is_empty(): return
	if _presence_code != invite_secret(party_snapshot()): return
	for id in _inbox.keys():
		if _inbox.has(id) and _inbox[id].request and not _inbox[id].busy and _inbox[id].retry_at <= _now(): respond_to_invite(id)

func _prune_inbox() -> void:
	var changed := false
	for id in _inbox.keys():
		if _inbox[id].expires < _now(): _inbox.erase(id); changed = true
	for id in _handled_inbox.keys():
		if _handled_inbox[id] < _now(): _handled_inbox.erase(id)
	if changed: inbox_changed.emit()

func dismiss_invite(id: String) -> void:
	_inbox.erase(id)
	_handled_inbox[id] = _now() + 600.0
	inbox_changed.emit()

func respond_to_invite(id: String) -> void:
	if not _inbox.has(id) or not is_discord_connected(): return
	var item: Dictionary = _inbox[id]
	if item.busy or item.expires < _now(): return
	if not friend_choices().any(func(friend): return int(friend.id) == item.invite.sender_id()): dismiss_invite(id); return
	if item.request:
		if str(party_snapshot().code).is_empty():
			_set_invite_status("Your lobby is full, disconnected or searching. Cancel search before approving a join.")
			return
		if _presence_code != invite_secret(party_snapshot()):
			_update_presence()
			_set_invite_status("Updating lobby presence. Try approving the request again in a moment.")
			return
		item.busy = true
		item.retry_at = _now() + 10.0
		_client.send_activity_join_request_reply(item.invite, _on_request_reply.bind(_generation, id))
	else:
		if not can_join_friend():
			_set_invite_status("Leave your match or cancel search before joining a friend.")
			return
		item.busy = true
		_client.accept_activity_invite(item.invite, _on_invite_accepted.bind(_generation, id))
	inbox_changed.emit()

func _on_request_reply(result: Variant, generation: int, id: String) -> void:
	if generation != _generation: return
	if result.successful(): dismiss_invite(id)
	elif _inbox.has(id): _inbox[id].busy = false
	_set_invite_status("Join approved. Discord sent your friend an invitation." if result.successful() else "Discord could not approve this request. Try again or send an invite.")
	inbox_changed.emit()

func _on_invite_accepted(result: Variant, secret: String, generation: int, id: String) -> void:
	if generation != _generation: return
	if result.successful():
		dismiss_invite(id)
		if can_join_friend(): _on_activity_join(secret, generation)
	else:
		if _inbox.has(id): _inbox[id].busy = false
		_set_invite_status("This invitation could not be accepted. Ask your friend for a fresh invite.")
	inbox_changed.emit()
