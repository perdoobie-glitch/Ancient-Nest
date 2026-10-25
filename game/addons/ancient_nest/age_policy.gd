extends Node
## Publisher policy, not an ESRB/PEGI certification or verified identity/age proof.
## Remember the declaration locally after sign-in; never collect a birth date.
const MINIMUM_AGE := 18
const NOTICE := "MATURE AUDIENCES — 18+"
const DISCLOSURE := "Publisher-designated age restriction. Not officially rated."
const CONTENT_NOTICE := "Contains violence, blood effects, and online player communication."
var confirmed_adult := false
var declined := false
const CONFIRMATION_PATH := "user://age-confirmation.cfg"
const POLICY_VERSION := 1

func _ready() -> void:
	restore_confirmation()

func restore_confirmation() -> bool:
	if declined: return false
	confirmed_adult = false
	var config := ConfigFile.new()
	if config.load(CONFIRMATION_PATH) != OK: return false
	if config.get_value("age", "policy", 0) != POLICY_VERSION or config.get_value("age", "minimum", 0) != MINIMUM_AGE: return false
	var accepted = config.get_value("age", "confirmed", false)
	confirmed_adult = accepted is bool and accepted
	return confirmed_adult

func remember_authenticated_confirmation() -> Error:
	if not is_eligible(): return ERR_UNAUTHORIZED
	var config := ConfigFile.new()
	config.set_value("age", "policy", POLICY_VERSION)
	config.set_value("age", "minimum", MINIMUM_AGE)
	config.set_value("age", "confirmed", true)
	return config.save(CONFIRMATION_PATH)

func restore_previous_sign_in(auth: Node) -> bool:
	if declined or FileAccess.file_exists(CONFIRMATION_PATH) or not auth.can_remember_device(): return false
	var token: String = auth.credential_store.read_token()
	if token.length() != 64: return false
	token = ""
	confirmed_adult = true # Provisional, only while validating the old age-gated login.
	var restored: Dictionary = await auth.restore_session()
	if not restored.get("ok", false):
		confirmed_adult = false
		return false
	remember_authenticated_confirmation()
	return true

func confirm_adult() -> bool:
	if declined:
		return false
	confirmed_adult = true
	return true

func decline() -> void:
	confirmed_adult = false
	declined = true
	# A later under-age declaration supersedes any old local remembered response.
	var config := ConfigFile.new()
	config.set_value("age", "confirmed", false)
	config.save(CONFIRMATION_PATH)

func is_eligible() -> bool:
	return confirmed_adult and not declined
