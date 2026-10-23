class_name NestImpactDebug
extends MeshInstance3D
static var block: BoxMesh
static var red: StandardMaterial3D
var game
var expires: float
func _ready() -> void:
 if block==null:
  block=BoxMesh.new();block.size=Vector3.ONE*.035
  red=StandardMaterial3D.new();red.albedo_color=Color("ff2525");red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh=block;material_override=red;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 expires=game.now+5
func _process(_delta: float) -> void:
 if not is_instance_valid(game) or not game.running or game.now>=expires:queue_free()
