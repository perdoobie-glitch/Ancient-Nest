class_name NestCamoPresentation
extends RefCounted
# Clip only the weapon's fragments against the owner's posed body bounds.
# This preserves scene depth/fog and avoids an invisible full-body depth pass.
var actor
var originals=[]
var weapon_root: Node3D
var materials: Array[ShaderMaterial]=[]
var active=false
var body_count=0
func _init(owner_actor):actor=owner_actor
func restore_weapon() -> void:
 for item in originals:
  if is_instance_valid(item.node):item.node.set_surface_override_material(item.surface,item.original)
 originals.clear();materials.clear()
func update(cloaked: bool) -> void:
 if not is_instance_valid(actor.model):return
 var current=actor.remote_art
 if cloaked and (not active or current!=weapon_root):
  restore_weapon();weapon_root=current
  if is_instance_valid(weapon_root):
   var cache={}
   var nodes=weapon_root.find_children("*","MeshInstance3D",true,false)
   if weapon_root is MeshInstance3D:nodes.append(weapon_root)
   for mesh in nodes:
    if mesh.mesh==null:continue
    for surface in range(mesh.mesh.get_surface_count()):
     var source=mesh.get_active_material(surface)
     if not source is StandardMaterial3D:continue
     var key=source.get_instance_id()
     var material: ShaderMaterial=cache.get(key)
     if material==null:
      material=ShaderMaterial.new();material.shader=load("res://assets/camo_weapon.gdshader")
      material.set_shader_parameter("base_color",source.albedo_color)
      material.set_shader_parameter("textured",source.albedo_texture!=null)
      if source.albedo_texture!=null:material.set_shader_parameter("base_texture",source.albedo_texture)
      material.set_shader_parameter("surface_roughness",source.roughness);material.set_shader_parameter("surface_metallic",source.metallic)
      material.set_shader_parameter("glow",source.emission*source.emission_energy_multiplier if source.emission_enabled else Color.BLACK)
      cache[key]=material;materials.append(material)
     originals.append({"node":mesh,"surface":surface,"original":mesh.get_surface_override_material(surface)})
     mesh.set_surface_override_material(surface,material)
 if not cloaked and active:restore_weapon()
 active=cloaked
 if not active:return
 var transforms: Array[Transform3D]=[];var halves=PackedVector3Array();body_count=mini(17,actor.hitboxes.size())
 for i in range(17):
  if i<body_count:
   var area=actor.hitboxes[i];var shape=actor.hitbox_shapes[i]
   var minimum: Vector3=shape.get_meta("minimum");var maximum: Vector3=shape.get_meta("maximum")
   var xf=area.global_transform;xf.origin+=xf.basis*((minimum+maximum)*.5)
   transforms.append(xf.affine_inverse());halves.append((maximum-minimum)*.5)
  else:transforms.append(Transform3D.IDENTITY);halves.append(Vector3.ZERO)
 for material in materials:
  material.set_shader_parameter("body_count",body_count);material.set_shader_parameter("body_inverse",transforms);material.set_shader_parameter("body_half",halves)
