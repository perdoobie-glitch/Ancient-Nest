extends SceneTree
func _initialize():call_deferred("run")
func run():
 var baseline_shapes=-1;var resources=[]
 for cycle in range(3):
  var arena=NestArena.new();arena.map_selection=0;root.add_child(arena);await physics_frame;await physics_frame
  assert(arena.get_meta("sanctuary_vaults").vaults==6)
  var cores=[]
  for mesh in arena.find_children("*","MeshInstance3D",true,false):
   if not mesh.has_meta("sanctuary_plasma_core"):continue
   cores.append(mesh);assert(mesh.mesh==NestSanctuaryVaults.core_mesh and mesh.material_override==NestSanctuaryVaults.plasma)
   assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.visibility_range_end==55)
   assert(not mesh.is_processing() and not mesh.is_physics_processing())
   assert(mesh.global_transform.is_finite())
  assert(cores.size()==6)
  if cycle==0:resources=[NestSanctuaryVaults.door_mesh,NestSanctuaryVaults.frame_mesh,NestSanctuaryVaults.core_mesh,NestSanctuaryVaults.plasma]
  else:assert(resources==[NestSanctuaryVaults.door_mesh,NestSanctuaryVaults.frame_mesh,NestSanctuaryVaults.core_mesh,NestSanctuaryVaults.plasma])
  for station in arena.get_children():
   if not String(station.name).begins_with("SanctuaryEnergyVault"):continue
   assert(station.get_child_count()==1,"Opaque casing and trim merge into spatial architecture batches")
   assert(not station.is_processing() and not station.is_physics_processing())
  var shapes=arena.find_children("*","CollisionShape3D",true,false).size()
  if baseline_shapes<0:baseline_shapes=shapes
  assert(shapes==baseline_shapes)
  arena.queue_free();await process_frame;await process_frame
 for map_id in [1,2]:
  var arena=NestArena.new();arena.map_selection=map_id;root.add_child(arena);await process_frame
  assert(not arena.has_meta("sanctuary_vaults"));arena.queue_free();await process_frame
 var shader=FileAccess.get_file_as_string("res://assets/sanctuary_plasma.gdshader")
 assert(not "ALPHA" in shader and not "SCREEN_TEXTURE" in shader and not "DEPTH_TEXTURE" in shader)
 print("PASS six Sanctuary vaults; opaque depth-tested cores; no script ticks/shadows; casing spatially batched; shared resources stable over three rebuilds; other maps untouched")
 quit()
