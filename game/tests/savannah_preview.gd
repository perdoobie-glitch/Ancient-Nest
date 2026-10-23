extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,900)
 var world=Node3D.new();root.add_child(world)
 var a=NestArena.new();a.map_selection=2;world.add_child(a)
 var cam=Camera3D.new();world.add_child(cam);cam.current=true;cam.far=300
 for shot in [{"name":"Savannah-overview","p":Vector3(33,46,39),"at":Vector3(0,0,0)},{"name":"Savannah-digyard","p":Vector3(-5,2.1,16),"at":Vector3(0,4,-1)},{"name":"Savannah-mine","p":Vector3(-15,-1.7,2),"at":Vector3(2,-1.9,2)},{"name":"Savannah-site","p":Vector3(-26,2,7),"at":Vector3(-18,2,-2)}]:
  cam.position=shot.p;cam.look_at(shot.at);cam.fov=55 if shot.name=="Savannah-overview" else 78
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v9-map-balance/"+shot.name+".png")
 world.queue_free();await process_frame;quit()
