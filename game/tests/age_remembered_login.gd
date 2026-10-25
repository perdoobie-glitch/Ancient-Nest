extends SceneTree
class Store extends RefCounted:
	var token := ""
	func read_token() -> String: return token
class PriorLogin extends Node:
	var credential_store := Store.new()
	var valid := false
	var calls := 0
	func can_remember_device() -> bool: return true
	func restore_session() -> Dictionary:
		calls += 1
		return {"ok":valid}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var policy = root.get_node("AncientNestAgePolicy")
	var login := PriorLogin.new()
	assert(not FileAccess.file_exists(policy.CONFIRMATION_PATH))
	assert(not await policy.restore_previous_sign_in(login))
	assert(login.calls == 0 and not policy.is_eligible())
	login.credential_store.token = "x".repeat(64)
	assert(not await policy.restore_previous_sign_in(login))
	assert(login.calls == 1 and not policy.is_eligible())
	assert(not FileAccess.file_exists(policy.CONFIRMATION_PATH))
	login.valid = true
	assert(await policy.restore_previous_sign_in(login))
	assert(login.calls == 2 and policy.is_eligible())
	var fresh = load("res://addons/ancient_nest/age_policy.gd").new()
	assert(fresh.restore_confirmation() and fresh.is_eligible())
	# Existing policy records, even invalidated ones, cannot be silently migrated again.
	assert(not await fresh.restore_previous_sign_in(login))
	assert(login.calls == 2)
	fresh.free()
	login.free()
	print("REMEMBERED AGE: missing/invalid saved login stays gated; valid prior login carries declaration forward; fresh process restores it (mock authentication)")
	quit()
