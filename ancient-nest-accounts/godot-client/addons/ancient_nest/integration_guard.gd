extends Node
## When installed into the existing game, losing account authorization returns to the gate.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AncientNestAuth.session_lost.connect(_return_to_login)


func _return_to_login() -> void:
	if str(ProjectSettings.get_setting("ancient_nest/original_main_scene", "")).is_empty():
		return
	get_tree().paused = true
	_change_scene.call_deferred()


func _change_scene() -> void:
	get_tree().change_scene_to_file("res://addons/ancient_nest/login.tscn")
	get_tree().paused = false
