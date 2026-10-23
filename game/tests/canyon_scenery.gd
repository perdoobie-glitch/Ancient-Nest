extends SceneTree
func _initialize():call_deferred("run")
func run():
 var a=NestArena.new();a.map_selection=2;root.add_child(a);await process_frame
 assert(a.get_meta("savannah_canyon_static",false))
 assert(a.get_meta("savannah_canyon_triangles")==4320)
 var count=0
 for mesh in a.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  for i in mesh.mesh.get_surface_count():
   var mat=mesh.get_active_material(i)
   if mat!=null and mat.resource_name=="Savannah canyon shared sandstone":
    count+=1;assert(mat is StandardMaterial3D and mat.vertex_color_use_as_albedo)
    assert(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.normal_enabled)
    assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 assert(count==1,"Single shared opaque canyon surface after static batching")
 for ring in NestSavannahCanyon.PROFILE.size():
  for sector in NestSavannahCanyon.SEGMENTS:
   var point=NestSavannahCanyon.point(ring,sector)
   assert(point.is_finite() and Vector2(point.x,point.z).length()>64,"Backdrop outside the playable bounds")
 assert(ResourceLoader.exists("res://assets/savannah/canyon_rock.png"))
 print("PASS one opaque 4320-triangle canyon surface, no normal-map/shadow pass; all background vertices outside 64m radius; texture present")
 a.queue_free();await process_frame;quit()
