extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://scenes/characters/NakiVisual.tscn").instantiate();root.add_child(scene);await process_frame
 var sk=scene.find_children("*","Skeleton3D",true,false)[0]
 for i in range(sk.get_bone_count()):
  if "hand" in sk.get_bone_name(i) or "forearm" in sk.get_bone_name(i):print(i," ",sk.get_bone_name(i)," ",sk.get_bone_global_rest(i))
 for m in scene.find_children("*","MeshInstance3D",true,false):
  print(m.name," surfaces ",m.mesh.get_surface_count()," skin ",m.skin!=null," xf ",m.global_transform)
  var a=m.mesh.surface_get_arrays(0);print("vertices ",a[0].size()," bones ",a[10].size() if a[10]!=null else 0)
 quit()
