extends SceneTree
class TestAuth extends "res://addons/ancient_nest/auth.gd":
	var reply: Dictionary
	func authenticated_request(_path: String, _method: int = HTTPClient.METHOD_GET, _data: Variant = null) -> Dictionary:
		return reply
class FakeStore extends RefCounted:
	func is_available() -> bool: return false

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var policy = root.get_node("AncientNestAgePolicy")
	assert(policy.confirm_adult())
	var auth = root.get_node("AncientNestAuth")
	var original_store = auth.credential_store
	auth.credential_store = FakeStore.new()
	auth.current_user = {"id":"profile-fixture","username":"Player_1234567890abcdef","needs_username":true}
	var login = load("res://addons/ancient_nest/login.gd").new()
	root.add_child(login)
	await process_frame
	login._enter_game({"ok":true})
	assert(login._signed_in.visible and not login._form.visible)
	assert(login._username.text.is_empty() and login._continue_game.disabled)
	assert(login._needs_username(auth.current_user))
	assert(not login._needs_username({"username":"ChosenName","needs_username":false}))
	assert(login._needs_username({"username":"Dis_123456789012345678"}))
	var updater := TestAuth.new()
	updater.current_user = {"id":"profile-fixture","username":"OldGameName","needs_username":true}
	updater.reply = {"ok":true,"data":{"user":{"id":"different-profile","username":"Nope"}}}
	assert(not (await updater.update_game_username("Nope")).ok)
	assert(updater.current_user.username == "OldGameName")
	updater.reply = {"ok":true,"data":{"user":{"id":"profile-fixture","username":"ChosenGameAlias","needs_username":false}}}
	assert((await updater.update_game_username("ChosenGameAlias")).ok)
	assert(updater.current_user.username == "ChosenGameAlias" and not updater.current_user.needs_username)
	assert(NestPreferences.normalize_username("X".repeat(40)).length() == 24)
	auth.current_user = {}
	auth.credential_store = original_store
	login.queue_free()
	updater.free()
	print("GAME USERNAME: provider identity hidden, onboarding required, stable profile update and 24-character names passed")
	quit()
