class_name NestRigidBatch
extends RefCounted
## Merge only fixed sibling meshes; preserve skeletons, moving parts and their names.
static func moving(name: String) -> bool:
 for prefix in ["ReloadMagazine","ChargingHandle","Pump","PistolSlide","Wing","PlasmaBlade","Blade","SniperRecharge","RocketReload","UniqueMuzzle"]:
  if name.begins_with(prefix):return true
 return false
static func build(root: Node3D) -> Dictionary:
 if root==null:return {}
 var parents: Array[Node]=[root];parents.append_array(root.find_children("*","Node3D",true,false))
 var removed=0;var batches=0
 for parent in parents:
  if not is_instance_valid(parent) or moving(String(parent.name)):continue
  var groups={}
  for child in parent.get_children():
   if not child is MeshInstance3D or child.mesh==null or child.skin!=null or child.get_child_count()>0 or not child.visible or moving(String(child.name)) or child.get_meta_list().size()>0:continue
   if child.mesh.get_surface_count()!=1:continue
   var material=child.get_active_material(0)
   if not material is StandardMaterial3D or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
   var key=str(material.get_instance_id())+":"+str(child.cast_shadow)
   if not groups.has(key):groups[key]={"material":material,"nodes":[]}
   groups[key].nodes.append(child)
  for group in groups.values():
   if group.nodes.size()<2:continue
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(group.material)
   for child in group.nodes:tool.append_from(child.mesh,0,child.transform)
   var merged=MeshInstance3D.new();merged.name="RigidDetailBatch";merged.mesh=tool.commit();merged.cast_shadow=group.nodes[0].cast_shadow;parent.add_child(merged)
   for child in group.nodes:parent.remove_child(child);child.queue_free();removed+=1
   batches+=1
 return {"removed_meshes":removed,"batches":batches}
