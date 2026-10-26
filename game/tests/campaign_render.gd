extends SceneTree
# Fixed-camera, uncapped renderer sample. Isolated APPDATA is supplied by runner.
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var quality=clampi(int(OS.get_environment("NEST_RENDER_QUALITY")),0,2)
 var settings=NestPreferences.DEFAULTS.duplicate(true);settings.graphics_quality=quality;NestGraphicsQuality.apply_viewport(root,settings)
 var rows=[]
 for region in ["preparation","forest"]:
  var start=Time.get_ticks_usec();var world=NestCampaignWorld.new();world.region=region;world.quality=quality;root.add_child(world)
  var build_ms=(Time.get_ticks_usec()-start)/1000.0
  var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=80
  var views=[Vector3(-19,1.8,18),Vector3(0,2,29),Vector3(28,4,28)] if region=="preparation" else [world.maze.checkpoints[0]+Vector3(0,1.8,5),world.maze.checkpoints[2]+Vector3(0,1.8,5),world.maze.checkpoints[4]+Vector3(0,1.8,5)]
  for view in views:
   camera.position=view;camera.look_at(Vector3(0,2,-9) if region=="preparation" else view+Vector3(12,0,-10))
   for i in range(45):await process_frame
   var frames=[];var draws=[];var primitives=[];var previous=Time.get_ticks_usec()
   for i in range(120):
    await process_frame
    var now=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
    draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
   frames.sort();draws.sort();primitives.sort()
   var row={"region":region,"quality":quality,"view":str(view),"build_ms":build_ms,"frame_median_ms":frames[60],"frame_p95_ms":frames[114],"draw_calls_median":draws[60],"primitives_median":primitives[60],"batch_stats":world.batch_stats}
   rows.append(row);print("CAMPAIGN_RENDER "+JSON.stringify(row))
  camera.queue_free();world.queue_free();await process_frame
 var output=OS.get_environment("NEST_RENDER_REPORT")
 if not output.is_empty():var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(rows," "))
 quit()
