extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame;game.show_lobby()
 var materials=[]
 for pivot in game.lobby_preview.pivots:
  for mesh in pivot.find_children("*","MeshInstance3D",true,false):
   for i in range(mesh.mesh.get_surface_count()):
    var mat=mesh.get_surface_override_material(i)
    if mat is BaseMaterial3D:materials.append(mat)
 check(not materials.is_empty() and materials.all(func(mat):return mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a==0),"Preview fade starts with transparent per-instance materials")
 await create_timer(.35).timeout
 check(materials.all(func(mat):return mat.albedo_color.a>.99 and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED),"Preview fade completes and restores opaque rendering")
 if DisplayServer.get_name()!="headless":
  for pivot in game.lobby_preview.pivots:
   for player in pivot.find_children("*","AnimationPlayer",true,false):player.stop(true)
  await RenderingServer.frame_post_draw
  var before=game.lobby_preview.viewport.get_texture().get_image().get_data()
  for mat in materials:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=0
  await process_frame;await RenderingServer.frame_post_draw
  var after=game.lobby_preview.viewport.get_texture().get_image().get_data();var different=0
  for i in range(before.size()):
   if before[i]!=after[i]:different+=1
  check(different>100,"Compatibility-rendered preview pixels change when material alpha fades")
  print("PREVIEW MATERIAL FADE CHANGED BYTES: ",different)
 game.queue_free();await process_frame;print("PREVIEW FADE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
