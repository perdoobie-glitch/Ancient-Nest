class_name NestStaticBatch
extends RefCounted
# Merge fixed architecture by material and spatial cell. Collisions stay intact;
# pickups, lift, banners, deposits, foliage and imported art remain separate.
static func build(arena: NestArena) -> Dictionary:
	var groups={}; var removed=0; var triangles=0
	for original in arena.find_children("*","MeshInstance3D",true,false):
		if original.mesh==null or original.skin!=null or not original.is_visible_in_tree(): continue
		var mat=original.material_override
		if mat!=arena.kit.stone and not mat is StandardMaterial3D and not (mat is ShaderMaterial and mat.shader.resource_path=="res://assets/crossroads_masonry.gdshader"):continue
		var parent=original.get_parent(); var dynamic=false
		while parent!=arena and parent!=null:
			if parent is AnimatableBody3D or parent in arena.deposits or parent in arena.pad_meshes: dynamic=true; break
			parent=parent.get_parent()
		if dynamic: continue
		var transform=arena.global_transform.affine_inverse()*original.global_transform
		var p=transform.origin
		# Wider Sanctuary cells reduce submission cost while retaining separate floors.
		var cell_width=24.0 if arena.map_selection==0 else 16.0
		var key="%d:%d:%d:%d:%d"%[mat.get_instance_id(),floori(p.x/cell_width),floori(p.y/8),floori(p.z/cell_width),original.cast_shadow]
		if not groups.has(key):
			var tool=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tool.set_material(mat)
			groups[key]={"tool":tool,"shadow":original.cast_shadow}
		for surface in range(original.mesh.get_surface_count()):
			groups[key].tool.append_from(original.mesh,surface,transform)
			var arrays=original.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		original.hide(); original.queue_free(); removed+=1
	for group in groups.values():
		var mesh=MeshInstance3D.new(); mesh.name="StaticArchitectureBatch"; mesh.mesh=group.tool.commit(); mesh.cast_shadow=group.shadow; arena.add_child(mesh)
	return {"original_meshes":removed,"batches":groups.size(),"triangles":triangles}
