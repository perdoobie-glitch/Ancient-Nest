extends RefCounted
## Adapter for https://github.com/shomykohai/godot-keyring (Windows/Linux).
## Ship its native addon for each target platform; there is no plaintext fallback.

const PACKAGE := "net.ancientnest.game"
const SERVICE := "accounts-refresh-token"
const DEVICE := "current-os-user"
var service := SERVICE
var device := DEVICE


func is_available() -> bool:
	return ClassDB.class_exists(&"Keyring")


func read_token() -> String:
	if not is_available():
		return ""
	return str(ClassDB.class_call_static(&"Keyring", &"get_password", PACKAGE, service, device))


func write_token(token: String) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	var result: int = ClassDB.class_call_static(&"Keyring", &"set_password", PACKAGE, service, device, token)
	return OK if result == 0 else FAILED


func clear_token() -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	if read_token().is_empty():
		return OK
	var result: int = ClassDB.class_call_static(&"Keyring", &"delete_password", PACKAGE, service, device)
	return OK if result == 0 else FAILED
