extends SceneTree
class FakeHub extends RefCounted:
	var connected := true
	func master_connected() -> bool: return connected
class FakeMatchmaking extends RefCounted:
	var phase := "party"
	var party := {"code":"ABCDEF1234", "members":[{"name":"GameAlias"}]}
	var hybrid := FakeHub.new()
	var actions: Array = []
	var opened := 0
	func team_size() -> int: return 2
	func cancel_search_countdown() -> void: pass
	func party_action(action, data) -> void: actions.append({"action":action,"data":data})
	func open_party() -> void: opened += 1
	var status := ""
	func changed() -> void: pass
class FakeGame extends Node:
	var running := false
	var matchmaking := FakeMatchmaking.new()
	var screens := 0
	func show_matchmaking() -> void: screens += 1
class FakeUser extends RefCounted:
	func id() -> int: return 123456789012345678
	func display_name() -> String: return "DiscordFriend"
class FakeRelationship extends RefCounted:
	var kind := 1
	func discord_relationship_type() -> int: return kind
	func user() -> Object: return FakeUser.new()
class FakeResult extends RefCounted:
	func successful() -> bool: return true
class FakeClient extends RefCounted:
	var relationship := FakeRelationship.new()
	var activity: Object
	var callback: Callable
	var invites := 0
	var clears := 0
	var join_callback: Callable
	var launch_command := ""
	func set_activity_join_callback(cb) -> void: join_callback = cb
	func register_launch_command(_application_id, command) -> void: launch_command = command
	func get_relationships() -> Array: return [relationship]
	func update_rich_presence(value, cb) -> void:
		activity = value
		callback = cb
	func send_activity_invite(_id, _message, cb) -> void:
		invites += 1
		cb.call(FakeResult.new())
	func clear_rich_presence() -> void: clears += 1

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var policy = root.get_node("AncientNestAgePolicy")
	assert(policy.confirm_adult())
	var social = load("res://addons/ancient_nest/discord_social.gd").new()
	var game := FakeGame.new()
	root.add_child(game)
	var client := FakeClient.new()
	client.relationship.kind = ClassDB.class_get_integer_constant(&"DiscordRelationshipType", &"FRIEND")
	social.attach_game(game)
	social.attach_client(client, 1562796619722793010)
	assert(client.join_callback.is_valid())
	assert(client.launch_command.begins_with('"' + OS.get_executable_path() + '"'))
	social._sdk_ready = true
	assert(social.parse_join_secret("ancientnest:party:v1:ABCDEF1234") == "ABCDEF1234")
	for invalid in ["https://example.com/", "ancientnest:party:v1:ABCDEF1234&token=x", "ancientnest:party:v1:abcdef1234", "ancientnest:party:v2:ABCDEF1234"]:
		assert(social.parse_join_secret(invalid).is_empty())
	social._update_presence()
	assert(client.activity.details() == "Ancient Nest")
	assert(client.activity.secrets().join() == "ancientnest:party:v1:ABCDEF1234")
	assert(not "DiscordFriend" in client.activity.state())
	assert(client.activity.party().current_size() == 1 and client.activity.party().max_size() == 2)
	social._send_invite(123456789012345678)
	assert(client.invites == 0) # Presence must be acknowledged first.
	client.callback.call(FakeResult.new())
	social._send_invite(999)
	assert(client.invites == 0)
	social._send_invite(123456789012345678)
	assert(client.invites == 1)
	social._send_invite(123456789012345678)
	assert(client.invites == 1) # Duplicate clicks are throttled.
	game.matchmaking.phase = "queue"
	assert(social.party_snapshot().code.is_empty())
	social._update_presence()
	assert(client.activity.secrets() == null)
	client.callback.call(FakeResult.new())
	social._send_invite(123456789012345678)
	assert(client.invites == 1)
	game.matchmaking.phase = "party"
	game.matchmaking.party.members.append({"name":"SecondGameAlias"})
	assert(social.party_snapshot().code.is_empty())
	game.matchmaking.party.members.pop_back()
	social._joining_code = "ABCDEF1234"
	social._joining_until = social._now() + 20
	social._advance_join()
	assert(game.matchmaking.actions == [{"action":"join","data":{"code":"ABCDEF1234"}}])
	game.matchmaking.phase = "playing"
	social._joining_code = "ABCDEF1234"
	social._advance_join()
	assert(game.matchmaking.actions.size() == 1 and social._joining_code.is_empty())
	client.relationship.kind = ClassDB.class_get_integer_constant(&"DiscordRelationshipType", &"BLOCKED")
	assert(social.friend_choices().is_empty())
	social.detach_client()
	assert(client.clears == 1 and social._presence_code.is_empty())
	game.queue_free()
	social.free()
	print("DISCORD INVITES: private party payload, native presence, friend-only dispatch, throttling, stale/full/searching removal and master join routing passed (mock SDK)")
	quit()
