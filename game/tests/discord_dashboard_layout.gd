extends SceneTree
class FakeHub extends NestHybridNetwork:
	var connected := true
	var messages: Array = []
	func _init() -> void:
		enabled = true
		cloud = true
		authority = false
		player_id = "me"
	func _ready() -> void:
		add_child(session)
		add_child(rtc)
		set_process(false)
		session.set_process(false)
		rtc.set_process(false)
	func _process(_delta: float) -> void: pass
	func master_connected() -> bool: return connected
	func send(value: Dictionary) -> void: messages.append(value)
	func leave(_abandon: bool=false) -> void: enabled = false
class FakeUser extends RefCounted:
	var value := 0
	var label := "OnlineFriend"
	func id() -> int: return 123456789012345678 + value
	func display_name() -> String: return label
	func status() -> int: return value
class FakeRelationship extends RefCounted:
	var person: FakeUser
	func discord_relationship_type() -> int: return ClassDB.class_get_integer_constant(&"DiscordRelationshipType", &"FRIEND")
	func user() -> Object: return person
class FakeClient extends RefCounted:
	var relationships: Array = []
	func get_relationships() -> Array: return relationships
	func clear_rich_presence() -> void: pass

func _initialize() -> void: call_deferred("run")
func frames(count := 5) -> void:
	for i in range(count): await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless" or not "--qa-screenshots" in OS.get_cmdline_user_args(): return
	var directory := OS.get_environment("ANCIENT_NEST_QA_OUTPUT")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK)
func run() -> void:
	var auth = root.get_node("AncientNestAuth")
	auth.current_user = {"id":"fixture-profile", "username":"ChosenGameName", "needs_username":false}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	if "--qa-screenshots" in OS.get_cmdline_user_args(): DisplayServer.window_set_title("Ancient Nest UI QA — mock data")
	game.accounts.busy = true
	var mm = game.matchmaking
	mm.set_process(false)
	var original_hub = mm.hybrid
	var hub := FakeHub.new()
	mm.add_child(hub)
	mm.hybrid = hub
	mm.active = true
	mm.phase = "party"
	mm.party = {"code":"ABCDEF1234","leader":"me","members":[{"user":"me","name":"ChosenGameName"}]}
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540),Vector2i(640,480)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		game.show_matchmaking()
		await frames()
		var search: Button = game.screen.find_child("MatchmakingSearch", true, false)
		assert(search != null and search.is_visible_in_tree() and not search.disabled)
		var bounds := search.get_global_rect()
		assert(bounds.position.y >= 0 and bounds.end.y <= root.get_visible_rect().size.y)
		assert(bounds.position.x >= 0 and bounds.end.x <= root.get_visible_rect().size.x)
		var parent: Node = search
		while parent != game.screen:
			assert(not parent is ScrollContainer)
			parent = parent.get_parent()
		if dimensions==Vector2i(1920,1080): await capture("matchmaking-search-pinned")
	var view = game.screen.get_node("MatchmakingView")
	view.search_button.pressed.emit()
	assert(mm.search_countdown_until > 0)
	mm.advance_search_countdown(mm.search_countdown_until + 1)
	assert(hub.messages.any(func(message): return message.type == "party_search"))
	mm.phase = "error"
	hub.connected = false
	game.show_matchmaking()
	await frames()
	assert(game.screen.find_child("MatchmakingSearch", true, false).disabled)
	assert(game.screen.find_child("MatchmakingReconnect", true, false) != null)
	mm.phase = "party"
	hub.connected = true
	var social = root.get_node("AncientNestDiscordSocial")
	var client := FakeClient.new()
	for info in [["OnlineFriend","ONLINE"],["HiddenFriend","INVISIBLE"],["OfflineFriend","OFFLINE"]]:
		var person := FakeUser.new()
		person.label = info[0]
		person.value = ClassDB.class_get_integer_constant(&"DiscordStatusType", info[1])
		var relation := FakeRelationship.new()
		relation.person = person
		client.relationships.append(relation)
	social._client = client
	social._sdk_ready = true
	game.open_discord_settings("matchmaking")
	await frames()
	assert(game.current_screen == "settings" and game.settings_tab == "Discord")
	var dashboard = game.preferences_groups.Discord.get_node("DiscordDashboard")
	dashboard._refresh()
	assert(dashboard._summary.text.contains("1 online / 3 friends"))
	assert(dashboard._friends.get_child_count() == 1)
	assert(not root.get_node("AncientNestDiscordVoice")._panel.visible)
	assert(dashboard.find_child("DiscordVoiceConnect", true, false) != null)
	assert(not dashboard._invite.disabled)
	var settings_panel: Control=game.preferences_groups.Discord
	assert(settings_panel.get_global_rect().position.x>=0)
	await capture("discord-dashboard")
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	game.open_discord_settings("matchmaking")
	await frames()
	dashboard=game.preferences_groups.Discord.get_node("DiscordDashboard")
	dashboard._refresh()
	await capture("discord-dashboard-desktop")
	dashboard._online_only.button_pressed = false
	dashboard._refresh()
	assert(dashboard._friends.get_child_count() == 3)
	dashboard._search.text = "HiddenFriend"
	dashboard._refresh()
	assert(dashboard._friends.get_child_count() == 1)
	assert(social.friend_choices().filter(func(friend): return friend.label == "HiddenFriend")[0].status == "Offline")
	game.matchmaking_ui_changed()
	assert(game.current_screen == "settings")
	game.return_from_settings()
	await frames()
	assert(game.current_screen == "matchmaking")
	social._sdk_ready = false
	social._client = null
	mm.hybrid = original_hub
	mm.active = false
	hub.queue_free()
	auth.current_user = {}
	game.queue_free()
	await frames()
	print("DISCORD DASHBOARD: online/privacy filters, friend search, settings-only voice controls, navigation and pinned Search at four resolutions passed (mock SDK/master)")
	quit()
