extends "res://scripts/account_link.gd"
signal resolved(ok: bool)
func _ready():pass
func refresh_session() -> bool:return await resolved
