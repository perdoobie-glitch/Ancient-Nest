extends VBoxContainer
## A settings page, not an always-visible gameplay overlay.
var game: Node
var _summary: Label
var _party_hint: Label
var _message: Label
var _search: LineEdit
var _online_only: CheckBox
var _invite: Button
var _friends: VBoxContainer
var _last_key := ""
var _privacy: OptionButton
var _playlist: OptionButton
var _connect_lobby: Button
var _inbox_rows: VBoxContainer
var _inbox_key := ""

func _ready() -> void:
	name = "DiscordDashboard"
	add_theme_constant_override("separation", 12)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",12)
	add_child(heading)
	_summary = Label.new()
	_summary.text = "Discord dashboard"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_summary)
	var identity := _label("Game username: " + str(AncientNestAuth.current_user.get("username", "Player")))
	identity.name = "DiscordDashboardGameName"
	_party_hint = _label("")
	var lobby_controls := HFlowContainer.new()
	lobby_controls.add_theme_constant_override("h_separation",10)
	add_child(lobby_controls)
	_connect_lobby = Button.new()
	_connect_lobby.text = "Connect lobby"
	_connect_lobby.pressed.connect(func():
		if not is_instance_valid(game) or game.running or game.matchmaking.phase not in ["idle","error"]: return
		game.matchmaking.open_party())
	lobby_controls.add_child(_connect_lobby)
	_privacy = OptionButton.new()
	_privacy.name = "DiscordLobbyPrivacy"
	_privacy.add_item("Open lobby",0)
	_privacy.add_item("Private · invite / approval",1)
	_privacy.item_selected.connect(func(index): AncientNestDiscordSocial.set_lobby_privacy("private" if index == 1 else "open"))
	lobby_controls.add_child(_privacy)
	_playlist = OptionButton.new()
	_playlist.name = "DiscordLobbyPlaylist"
	for playlist in NestMatchmaking.PLAYLIST_NAMES: _playlist.add_item(playlist)
	_playlist.item_selected.connect(func(index):
		if is_instance_valid(game) and not game.running and game.matchmaking.phase == "party" and game.matchmaking.party_leader():
			game.matchmaking.cancel_search_countdown()
			game.matchmaking.party_action("playlist",{"playlist":NestMatchmaking.PLAYLIST_IDS[index]}))
	lobby_controls.add_child(_playlist)
	_invite = Button.new()
	_invite.name = "DiscordDashboardInvite"
	_invite.text = "Invite friends"
	_invite.pressed.connect(func(): AncientNestDiscordSocial.show_invite_dialog(game))
	heading.add_child(_invite)
	_search = LineEdit.new()
	_search.name = "DiscordFriendsSearch"
	_search.placeholder_text = "Find a Discord friend"
	_search.clear_button_enabled = true
	_search.add_theme_color_override("font_placeholder_color",Color("626b64"))
	_search.text_changed.connect(func(_value): _last_key = ""; _refresh())
	add_child(_search)
	_online_only = CheckBox.new()
	_online_only.text = "Show online friends only"
	_online_only.button_pressed = true
	for style in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		_online_only.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	_online_only.toggled.connect(func(_value): _last_key = ""; _refresh())
	add_child(_online_only)
	_message = _label("")
	_message.hide()
	_message.name = "DiscordInviteStatus"
	_friends = VBoxContainer.new()
	_friends.name = "DiscordFriendsList"
	_friends.add_theme_constant_override("separation", 8)
	add_child(_friends)
	var inbox_title := _label("INVITATIONS & JOIN REQUESTS")
	inbox_title.name = "DiscordInboxTitle"
	_inbox_rows = VBoxContainer.new()
	_inbox_rows.add_theme_constant_override("separation",8)
	add_child(_inbox_rows)
	var separator := HSeparator.new()
	add_child(separator)
	AncientNestDiscordVoice.build_settings(self)
	AncientNestDiscordSocial.invite_status_changed.connect(_on_invite_status)
	AncientNestDiscordSocial.inbox_changed.connect(_refresh_inbox)
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label

func _refresh() -> void:
	if not is_visible_in_tree() or not is_instance_valid(_friends): return
	var social = AncientNestDiscordSocial
	var identity := get_node_or_null("DiscordDashboardGameName")
	if identity != null: identity.text = "Game username: " + str(AncientNestAuth.current_user.get("username", "Player"))
	var friends: Array = social.friend_choices()
	var online: int = friends.filter(func(friend): return bool(friend.online)).size()
	_summary.text = "Discord connected — %d online / %d friends" % [online, friends.size()] if social.is_discord_connected() else "Discord is connecting. Your game account stays signed in."
	if AncientNestAuth.current_user.is_empty(): _summary.text = "Sign in with Discord to see friends, invite or join a lobby."
	var party: Dictionary = social.party_snapshot()
	var mm = game.matchmaking if is_instance_valid(game) else null
	_connect_lobby.disabled = mm == null or game.running or mm.phase not in ["idle","error"]
	_connect_lobby.visible = mm == null or mm.phase in ["idle","error","connecting"]
	_privacy.select(1 if party.get("privacy", "open") == "private" else 0)
	_privacy.disabled = mm == null or game.running or mm.phase != "party" or not mm.party_leader() or not mm.party.get("lobby_privacy_supported", false)
	_privacy.tooltip_text = "Only the lobby leader can change privacy. The matchmaking server must support lobby privacy."
	_playlist.disabled = mm == null or game.running or mm.phase != "party" or not mm.party_leader()
	if mm != null: _playlist.select(maxi(0,NestMatchmaking.PLAYLIST_IDS.find(mm.playlist)))
	var can_invite: bool = social.is_discord_connected() and not str(party.code).is_empty()
	_invite.disabled = not can_invite
	_party_hint.text = "Party ready: %d / %d teammates. Choose a friend below to invite." % [party.size, party.maximum] if can_invite else "To invite, open Play → Matchmaking, connect, and choose a playlist with room for teammates. Cancel search before changing your party."
	_party_hint.visible = not can_invite
	_refresh_inbox()
	var can_join: bool = social.can_join_friend()
	var key := JSON.stringify([friends, can_invite, can_join, _search.text, _online_only.button_pressed])
	if key == _last_key: return
	_last_key = key
	for child in _friends.get_children():
		_friends.remove_child(child)
		child.queue_free()
	var shown := 0
	for friend in friends:
		if _online_only.button_pressed and not bool(friend.online): continue
		if not _search.text.strip_edges().is_empty() and not str(friend.label).to_lower().contains(_search.text.strip_edges().to_lower()): continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_friends.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = str(friend.label) + " · " + str(friend.status)
		if not str(friend.activity).is_empty(): label.text += " · " + str(friend.activity)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var invite := Button.new()
		invite.text = "Invite"
		invite.custom_minimum_size = Vector2(90, 42)
		invite.disabled = not can_invite
		var friend_id := int(friend.id)
		invite.pressed.connect(func(): social.invite_friend(friend_id))
		row.add_child(invite)
		var join := Button.new()
		join.text = "Join game"
		join.tooltip_text = "Ask to join. Open lobbies reply automatically; private lobbies require approval."
		join.disabled = not can_join or not bool(friend.get("playing_ancient_nest", false))
		join.pressed.connect(func(): social.request_join_friend(friend_id))
		row.add_child(join)
	if shown == 0:
		var empty := Label.new()
		empty.text = "No friends match this filter. Try showing offline friends or refresh after Discord connects."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_friends.add_child(empty)

func _on_invite_status(message: String) -> void:
	if is_instance_valid(_message):
		_message.text = message
		_message.visible = not message.is_empty()

func _exit_tree() -> void:
	if is_instance_valid(AncientNestDiscordSocial) and AncientNestDiscordSocial.invite_status_changed.is_connected(_on_invite_status):
		AncientNestDiscordSocial.invite_status_changed.disconnect(_on_invite_status)
	if AncientNestDiscordSocial.inbox_changed.is_connected(_refresh_inbox): AncientNestDiscordSocial.inbox_changed.disconnect(_refresh_inbox)

func _refresh_inbox() -> void:
	if not is_instance_valid(_inbox_rows): return
	var social = AncientNestDiscordSocial
	var entries: Array = social.inbox_entries()
	var key := JSON.stringify(entries)
	if key == _inbox_key: return
	_inbox_key = key
	for child in _inbox_rows.get_children():
		_inbox_rows.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No pending invitations or join requests."
		_inbox_rows.add_child(empty)
	for entry in entries:
		var row := HBoxContainer.new()
		_inbox_rows.add_child(row)
		var label := Label.new()
		label.text = str(entry.label) + (" wants to join" if entry.request else " invited you")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var accept := Button.new()
		accept.text = "Approve" if entry.request else "Accept"
		accept.disabled = bool(entry.busy)
		var id := str(entry.id)
		accept.pressed.connect(func(): social.respond_to_invite(id))
		row.add_child(accept)
		var dismiss := Button.new()
		dismiss.text = "Dismiss"
		dismiss.pressed.connect(func(): social.dismiss_invite(id))
		row.add_child(dismiss)
