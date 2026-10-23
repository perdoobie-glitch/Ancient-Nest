class_name NestViewArms
extends RefCounted
static func create(character: int,side: String,part: String) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name="Model"+part.capitalize()+"_"+side
 node.mesh=load("res://models/view_arms/%s_%s_%s.res"%["naki" if character==0 else "annu",part,side])
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return node
