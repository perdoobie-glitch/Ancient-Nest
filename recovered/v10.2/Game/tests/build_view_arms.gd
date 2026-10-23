extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("res://models/view_arms")
 for character in [0,1]:
  var scene=load(NestCharacterCatalog.by_index(character).visual).instantiate();root.add_child(scene);await process_frame
  NestReferenceSkin.apply(scene,character)
  var skeleton=scene.find_children("*","Skeleton3D",true,false)[0]
  for side in ["l","r"]:
   for part in ["hand","forearm"]:
    var index=skeleton.find_bone(part+"_"+side);var mesh=ArrayMesh.new();var total=0
    var bone_inverse=skeleton.get_bone_global_rest(index).affine_inverse()
    var batches=[];var bounds=AABB();var first=true
    for node in scene.find_children("*","MeshInstance3D",true,false):
     if node.skin==null or "Cape" in str(node.name):continue
     for surface in range(node.mesh.get_surface_count()):
      var arrays=node.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
      if bones==null:continue
      var influence=[];var stride=bones.size()/vertices.size()
      for v in range(vertices.size()):
       var amount=0.0
       for j in range(stride):
        var bind=int(bones[v*stride+j]);var bone=node.skin.get_bind_bone(bind)
        if bone<0:bone=skeleton.find_bone(node.skin.get_bind_name(bind))
        var selected=bone==index
        if part=="hand":
         var parent=bone
         while parent>=0:
          if parent==index:selected=true;break
          parent=skeleton.get_bone_parent(parent)
        if selected:amount+=weights[v*stride+j]
       influence.append(amount)
      var indices=arrays[Mesh.ARRAY_INDEX];var selected=[]
      for triangle in range(0,indices.size(),3):
       var a=int(indices[triangle]);var b=int(indices[triangle+1]);var c=int(indices[triangle+2])
       if influence[a]+influence[b]+influence[c]<1.8:continue
       for v in [a,b,c]:
        selected.append(v)
        var point=bone_inverse*(skeleton.global_transform.affine_inverse()*node.global_transform*vertices[v])
        if first:bounds=AABB(point,Vector3.ZERO);first=false
        else:bounds=bounds.expand(point)
      if not selected.is_empty():batches.append({"arrays":arrays,"indices":selected,"xf":bone_inverse*skeleton.global_transform.affine_inverse()*node.global_transform,"material":node.get_active_material(surface)})
    assert(not first,"Missing model arm geometry")
    var target=Vector3(.085,.11,.07) if part=="hand" else Vector3(.09,.25,.09)
    var factor=target/bounds.size;var center=bounds.get_center()
    for batch in batches:
     var positions=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array()
     for i in batch.indices:
      positions.append((batch.xf*batch.arrays[Mesh.ARRAY_VERTEX][i]-center)*factor)
      normals.append(((batch.xf.basis*batch.arrays[Mesh.ARRAY_NORMAL][i])/factor).normalized())
      uv.append(batch.arrays[Mesh.ARRAY_TEX_UV][i])
     var data=[];data.resize(Mesh.ARRAY_MAX);data[Mesh.ARRAY_VERTEX]=positions;data[Mesh.ARRAY_NORMAL]=normals;data[Mesh.ARRAY_TEX_UV]=uv
     mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data);mesh.surface_set_material(mesh.get_surface_count()-1,batch.material);total+=positions.size()
    mesh.set_meta("source_model",NestCharacterCatalog.by_index(character).model);mesh.set_meta("source_bone",part+"_"+side);mesh.set_meta("source_vertices",total)
    var path="res://models/view_arms/%s_%s_%s.res"%["naki" if character==0 else "annu",part,side]
    assert(ResourceSaver.save(mesh,path)==OK);print(path," ",total)
  scene.queue_free();await process_frame
 quit()
