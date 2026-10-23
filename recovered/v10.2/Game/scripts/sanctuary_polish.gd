class_name NestSanctuaryPolish
extends RefCounted
## Presentation cleanup before static batching; existing routes/walls stay intact.
static func apply(arena: NestArena) -> Dictionary:
 var stats={"labels_hidden":0,"duplicate_meshes":0,"duplicate_colliders":0}
 for sign in arena.find_children("*","Label3D",true,false):
  if sign in arena.flag_labels or sign in arena.deposit_labels:continue
  if sign.text.begins_with("A · ") or sign.text.begins_with("B · "):
   sign.text=sign.text.left(1);sign.pixel_size=.009;sign.visibility_range_end=35;continue
  # Debug-like route instructions used to float over every level and overlap.
  if " · " in sign.text or "→" in sign.text or "↑" in sign.text or "↓" in sign.text:
   sign.hide();stats.labels_hidden+=1
  else:
   sign.pixel_size=minf(sign.pixel_size,.0055);sign.visibility_range_end=15.0
 if arena.forge_editable:return stats
 var seen_meshes={};var seen_bodies={}
 for mesh in arena.find_children("*","MeshInstance3D",true,false):
  if not mesh.mesh is BoxMesh and not mesh.mesh is CylinderMesh:continue
  if dynamic_parent(mesh,arena):continue
  var shape=mesh.mesh
  var dimensions=str(shape.size) if shape is BoxMesh else str(Vector3(shape.top_radius,shape.bottom_radius,shape.height))
  var key=str(shape.get_class())+dimensions+str(mesh.global_transform)+str(mesh.material_override)
  if seen_meshes.has(key):mesh.hide();mesh.queue_free();stats.duplicate_meshes+=1
  else:seen_meshes[key]=true
 for body in arena.find_children("*","StaticBody3D",true,false):
  if dynamic_parent(body,arena) or body.get_child_count()!=1:continue
  var child=body.get_child(0)
  if not child is CollisionShape3D or not child.shape is BoxShape3D:continue
  var key=str(body.collision_layer)+str(child.global_transform)+str(child.shape.size)
  if seen_bodies.has(key):body.collision_layer=0;body.queue_free();stats.duplicate_colliders+=1
  else:seen_bodies[key]=true
 return stats
static func dynamic_parent(node: Node,arena: NestArena) -> bool:
 var parent=node
 while parent!=arena and parent!=null:
  if parent in arena.deposits or parent in arena.pad_meshes or parent is AnimatableBody3D:return true
  parent=parent.get_parent()
 return false
