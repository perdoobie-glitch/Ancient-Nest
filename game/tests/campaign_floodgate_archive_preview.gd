extends SceneTree
var game
var output=""
var metrics=[]
func _initialize():call_deferred("run")
func frames(count=5):
 for frame in range(count):await process_frame
func capture(camera: Camera3D,at: Vector3,target: Vector3,name: String):
 camera.position=at;camera.look_at(target);await frames(8);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func sample(mission: int):
 var intervals=[];var previous=Time.get_ticks_usec()
 for frame in range(90):
  await process_frame;var now=Time.get_ticks_usec();intervals.append((now-previous)/1000.0);previous=now
 intervals.sort();var record={"mission":mission,"median_frame_ms":intervals[45],"p95_frame_ms":intervals[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
 metrics.append(record);print("DETAIL_RENDER ",JSON.stringify(record))
func run():
 output=OS.get_environment("NEST_CAMPAIGN_PREVIEW")
 if output.is_empty() or OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.master=0.0;game.prefs.apply()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://detail-preview.json";c.selected_mission=3;c.begin_solo(false)
 game.set_physics_process(false);c.set_process(false);c.guide.voice_supported=false
 var camera=Camera3D.new();game.add_child(camera);camera.far=1600;camera.fov=74
 for mission in [3,4]:
  if mission!=3:c.journey.start_standalone(mission)
  c.journey.finish_cinematic();c.cinematic.present(0);c.guide.stop_voice();c.world.set_stage(3)
  for actor in game.actors:actor.set_physics_process(false)
  game.hud.visible=false;camera.current=true
  await capture(camera,Vector3(0,2.1,24),Vector3(-6,4,-10),"mission-%02d-entry"%mission)
  await capture(camera,Vector3(-22,2.1,-3),Vector3(-22,2.2,-9),"mission-%02d-objective"%mission)
  if mission==3:
   await capture(camera,Vector3(-19,2.1,0),Vector3(-12,2.5,-9),"mission-03-pump")
   await capture(camera,Vector3(8,2.1,8),Vector3(38,5,-3),"mission-03-manifold")
   await capture(camera,Vector3(-43,2.1,9),Vector3(-48,1.7,9),"mission-03-maintenance")
   await capture(camera,Vector3(0,7.1,-45),Vector3(12,9,-65),"mission-03-bypass")
   await capture(camera,Vector3(0,6.1,-182),Vector3(0,8,-201),"mission-03-transmitter")
   await capture(camera,Vector3(10,12,13),Vector3(-8,4,-8),"mission-03-overview")
  else:
   await capture(camera,Vector3(38,2.1,7),Vector3(48,2.5,8.5),"mission-04-stacks")
   await capture(camera,Vector3(44,2.1,0),Vector3(50.35,3.6,0),"mission-04-relief")
   await capture(camera,Vector3(0,2.1,7),Vector3(0,14,-19),"mission-04-arches")
   await capture(camera,Vector3(40,8.1,-55),Vector3(51,15,-55),"mission-04-protected-grid")
   await capture(camera,Vector3(18,8.1,-38),Vector3(18,8,-42),"mission-04-ledger-alcove")
   await capture(camera,Vector3(0,20.1,-189),Vector3(0,23,-201.5),"mission-04-reclamation-map")
   await capture(camera,Vector3(24,9,26),Vector3(0,5,-9),"mission-04-overview")
  print("DETAIL_COUNTS ",mission," ",JSON.stringify(c.world.get_meta("flood_archive_detail_counts",{}))," BATCHES ",JSON.stringify(c.world.batch_stats))
  await sample(mission)
 var report=FileAccess.open(output+"/render-samples.json",FileAccess.WRITE);report.store_string(JSON.stringify(metrics,"  "));report.close()
 c.exit_campaign();game.queue_free();await frames(8);quit()
