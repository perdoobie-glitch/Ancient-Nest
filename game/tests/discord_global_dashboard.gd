extends SceneTree
const Fixtures = preload("res://tests/discord_dashboard_layout.gd")
const APP_ID := 1562796619722793010
class Result extends RefCounted:
	func successful() -> bool: return true
class Person extends RefCounted:
	func id() -> int: return 123456789012345678
	func display_name() -> String: return "FixtureFriend"
	func status() -> int: return ClassDB.class_get_integer_constant(&"DiscordStatusType", &"ONLINE")
	func game_activity() -> Object:
		var activity = ClassDB.instantiate(&"DiscordActivity")
		activity.set_name("Ancient Nest")
		activity.set_application_id(APP_ID)
		return activity
class Relationship extends RefCounted:
	func discord_relationship_type() -> int: return ClassDB.class_get_integer_constant(&"DiscordRelationshipType", &"FRIEND")
	func user() -> Object: return Person.new()
class SDK extends RefCounted:
	var requests := 0
	var replies := 0
	var accepts := 0
	var invites := 0
	var secret := ""
	func get_relationships() -> Array: return [Relationship.new()]
	func update_rich_presence(_activity, callback) -> void: callback.call(Result.new())
	func clear_rich_presence() -> void: pass
	func send_activity_join_request(_id, callback) -> void: requests += 1; callback.call(Result.new())
	func send_activity_join_request_reply(_invite, callback) -> void: replies += 1; callback.call(Result.new())
	func accept_activity_invite(_invite, callback) -> void: accepts += 1; callback.call(Result.new(),secret)
	func send_activity_invite(_id, _text, callback) -> void: invites += 1; callback.call(Result.new())

func _initialize() -> void: call_deferred("run")
func frames(count := 3) -> void:
	for i in range(count): await process_frame
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event
func invitation(id: int, request: bool) -> Object:
	var invite = ClassDB.instantiate(&"DiscordActivityInvite")
	invite.set_application_id(APP_ID)
	invite.set_sender_id(Person.new().id())
	invite.set_message_id(id)
	invite.set_is_valid(true)
	invite.set_type(ClassDB.class_get_integer_constant(&"DiscordActivityActionTypes", &"JOIN_REQUEST" if request else &"JOIN"))
	return invite
func run() -> void:
	var auth = root.get_node("AncientNestAuth")
	auth.current_user = {"id":"fixture-profile","username":"ChosenGameName"}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.accounts.busy = true
	var mm = game.matchmaking
	mm.set_process(false)
	var original_hub = mm.hybrid
	var hub := Fixtures.FakeHub.new()
	mm.add_child(hub)
	mm.hybrid = hub
	mm.active = true
	mm.phase = "party"
	mm.playlist = "doubles_2v2"
	mm.party = {"code":"ABCDEF1234","leader":"me","members":[{"user":"me","name":"ChosenGameName","leader":true}],"privacy":"private","lobby_privacy_supported":true,"invite_token":"0123456789abcdef0123456789abcdef"}
	var social = root.get_node("AncientNestDiscordSocial")
	var sdk := SDK.new()
	social._client = sdk
	social._application_id = APP_ID
	social._sdk_ready = true
	assert(root.get_node("AncientNestAgePolicy").confirm_adult())
	var shortcut = root.get_node("AncientNestDiscordShortcut")
	game.show_main()
	await frames()
	assert(game.screen.find_child("DiscordDashboardShortcut",true,false).text.begins_with("[I]"))
	for screen in ["main","matchmaking","settings","lobby","playing","results","forge","account"]:
		game.current_screen = screen
		game.running = screen == "playing"
		game.context = "playing" if screen == "playing" else "menu"
		var original_context: String = game.context
		shortcut._input(key(KEY_I))
		assert(shortcut.is_open() and game.current_screen == screen and game.context == "discord_dashboard")
		shortcut._input(key(KEY_ESCAPE))
		assert(not shortcut.is_open() and game.context == original_context and game.current_screen == screen)
		assert(game.running == (screen == "playing"))
	game.running = false
	game.current_screen = "main"
	game.context = "menu"
	game.open_discord_dashboard()
	await frames()
	var dashboard = shortcut.panel.find_child("DiscordDashboard",true,false)
	assert(dashboard != null and not dashboard._privacy.disabled)
	dashboard._search.grab_focus()
	shortcut._input(key(KEY_I))
	assert(shortcut.is_open()) # Letter I remains usable in friend searches.
	shortcut.close_dashboard()
	if "--qa-screenshots" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		root.content_scale_size = root.size
		game.open_discord_dashboard()
		await frames()
		await RenderingServer.frame_post_draw
		var directory := OS.get_environment("ANCIENT_NEST_QA_OUTPUT")
		DirAccess.make_dir_recursive_absolute(directory)
		root.get_texture().get_image().save_png(directory.path_join("global-dashboard.png"))
		root.size = Vector2i(640,480)
		root.content_scale_size = root.size
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("global-dashboard-compact.png"))
		shortcut.close_dashboard()
	social._update_presence()
	sdk.secret = social.invite_secret(social.party_snapshot())
	assert(social.parse_join_secret(sdk.secret) == "ABCDEF1234")
	assert(sdk.secret.ends_with(mm.party.invite_token))
	social.set_lobby_privacy("open")
	assert(hub.messages[-1] == {"type":"party_privacy","privacy":"open"})
	social.request_join_friend(Person.new().id())
	assert(sdk.requests == 1)
	game.running = true
	social._last_join_request_at = -10
	social.request_join_friend(Person.new().id())
	assert(sdk.requests == 1)
	game.running = false
	social._on_activity_invite(invitation(100,true),social._generation)
	assert(sdk.replies == 0 and social.inbox_entries().size() == 1) # Private: approval required.
	social.respond_to_invite("100")
	assert(sdk.replies == 1 and social.inbox_entries().is_empty())
	social._on_activity_invite(invitation(100,true),social._generation)
	assert(sdk.replies == 1) # Duplicate provider events do not reply twice.
	mm.party.privacy = "open"
	social._update_presence()
	social._on_activity_invite(invitation(101,true),social._generation)
	assert(sdk.replies == 2 and social.inbox_entries().is_empty())
	social._on_activity_invite(invitation(102,false),social._generation)
	assert(sdk.accepts == 0) # Incoming invite never joins without a click.
	social.respond_to_invite("102")
	assert(sdk.accepts == 1)
	assert(hub.messages[-1] == {"type":"party_join","code":"ABCDEF1234","invite_token":mm.party.invite_token})
	var sent := hub.messages.size()
	social._on_activity_join(sdk.secret,social._generation)
	assert(hub.messages.size() == sent) # Two SDK notifications, one join.
	mm.phase = "queue"
	social._last_join_until = 0
	social._on_activity_join(sdk.secret,social._generation)
	assert(hub.messages.size() == sent and social._pending_join_code.is_empty())
	mm.phase = "party"
	social._on_activity_join(sdk.secret,social._generation)
	assert(hub.messages.size() == sent + 1) # Discord's Join click alone routes to the master.
	await frames()
	social.detach_client()
	mm.hybrid = original_hub
	mm.active = false
	hub.queue_free()
	auth.current_user = {}
	game.queue_free()
	await frames()
	print("GLOBAL DISCORD: I/Escape across eight screens, typing, private approval, open auto-reply, explicit invite acceptance and server capability routing passed (mock SDK/master)")
	quit()
