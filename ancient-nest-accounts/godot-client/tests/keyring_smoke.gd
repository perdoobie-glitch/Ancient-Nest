extends SceneTree
## Real OS credential-store round trip, isolated from player entries.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(OS.get_name() == "Windows", "Run this credential-store check on Windows")
	assert(ClassDB.class_exists(&"Keyring"))
	var store: RefCounted = preload("res://addons/ancient_nest/credential_store.gd").new()
	store.service = "ci-credential-test"
	store.device = "test-" + str(Time.get_ticks_usec())
	var value := Crypto.new().generate_random_bytes(32).hex_encode()
	var saved: Error = store.write_token(value)
	if saved != OK:
		push_error("Windows credential store write failed")
		quit(1)
		return
	var restored: String = store.read_token()
	var cleared: Error = store.clear_token()
	assert(restored == value, "Windows credential store returned a different secret")
	assert(cleared == OK and store.read_token().is_empty(), "Windows credential store cleanup failed")
	print("GODOT_KEYRING_SMOKE_PASSED: native Windows write/read/delete")
	quit(0)
