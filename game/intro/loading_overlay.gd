extends CanvasLayer
var menu_requested=false
var frames=0
func _process(_delta: float) -> void:
 if menu_requested and is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/main.tscn":
  frames+=1
  if frames>=3:queue_free()
