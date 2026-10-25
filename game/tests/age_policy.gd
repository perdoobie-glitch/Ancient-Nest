extends SceneTree
class FakeStore extends RefCounted:
	var reads := 0
	var clears := 0
	func is_available() -> bool: return false
	func read_token() -> String:
		reads += 1
		return ""
	func clear_token() -> void: clears += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEST_ISOLATED_QA")!="1":
		push_error("This fixture writes age preferences. Run node scripts/campaign-validation.mjs age_policy for an isolated profile.");quit(1);return
	var policy = root.get_node("AncientNestAgePolicy")
	var auth = root.get_node("AncientNestAuth")
	var original_store = auth.credential_store
	var fake := FakeStore.new()
	auth.credential_store = fake
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://addons/ancient_nest/age_gate.tscn")
	assert(policy.MINIMUM_AGE == 18 and "Not officially rated" in policy.DISCLOSURE)
	assert(not policy.is_eligible())
	assert((await auth.restore_session()).error == "age_confirmation_required")
	assert((await auth.sign_in_discord()).error == "age_confirmation_required")
	assert((await auth._request("/auth/discord/config", HTTPClient.METHOD_GET)).error == "age_confirmation_required")
	assert(fake.reads == 0 and fake.clears == 0)
	assert(auth._discord_client == null)
	var gate = load("res://addons/ancient_nest/age_gate.tscn").instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	assert(gate.continue_button.disabled)
	gate._continue()
	assert(not policy.is_eligible())
	gate.confirmation.button_pressed = true
	assert(not gate.continue_button.disabled)
	gate._decline()
	assert(gate.continue_button.disabled and gate.confirmation.disabled)
	assert(not policy.confirm_adult())
	gate._continue()
	assert(current_scene == gate and not policy.is_eligible())
	assert((await auth.sign_in_discord()).error == "age_confirmation_required")
	gate.queue_free()
	await process_frame
	# A declined device cannot restore an earlier response.
	var fresh = load("res://addons/ancient_nest/age_policy.gd").new()
	assert(not fresh.is_eligible() and not fresh.declined)
	fresh.free()
	# Exercise the adult transition with a fake credential store; no real credentials/network.
	policy.declined = false
	gate = load("res://addons/ancient_nest/age_gate.tscn").instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	gate.confirmation.button_pressed = true
	gate._continue()
	await process_frame
	await process_frame
	assert(policy.is_eligible())
	assert(current_scene.get_script().resource_path == "res://addons/ancient_nest/login.gd")
	assert(current_scene._submit.text == "Continue with Discord")
	assert(fake.reads == 0 and fake.clears == 0)
	# A successful sign-in remembers only the declaration and policy version.
	assert(policy.remember_authenticated_confirmation() == OK)
	fresh = load("res://addons/ancient_nest/age_policy.gd").new()
	assert(fresh.restore_confirmation() and fresh.is_eligible())
	var saved := ConfigFile.new()
	assert(saved.load(policy.CONFIRMATION_PATH) == OK)
	assert(saved.get_section_keys("age").size() == 3)
	gate = load("res://addons/ancient_nest/age_gate.tscn").instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	await process_frame
	assert(current_scene.get_script().resource_path == "res://addons/ancient_nest/login.gd")
	assert(gate == null or not is_instance_valid(gate))
	saved.set_value("age", "policy", -1)
	assert(saved.save(policy.CONFIRMATION_PATH) == OK)
	assert(not fresh.restore_confirmation() and not fresh.is_eligible())
	fresh.free()
	auth.credential_store = original_store
	print("AGE POLICY: first-launch blocking, decline lock, authenticated declaration persistence, restart skip and policy-version fallback passed")
	quit()
