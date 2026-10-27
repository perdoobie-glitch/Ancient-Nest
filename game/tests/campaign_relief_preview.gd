extends SceneTree
# Real rendered review of the raised route and story presentation, using isolated preferences.
var game
var output=""
var metrics=[]
func _initialize():call_deferred("run")
func frames(count=5):
 for i in range(count):await process_frame
func capture(name: String):
 await frames(8);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func sample(label: String):
 var samples=[];var start=Time.get_ticks_usec()
 for i in range(90):
  await process_frame
  var now=Time.get_ticks_usec();samples.append((now-start)/1000.0);start=now
 samples.sort()
 var record={"scene":label,"median_frame_ms":samples[45],"p95_frame_ms":samples[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
 metrics.append(record);print("RENDER_SAMPLE ",JSON.stringify(record))
func run():
 output=OS.get_environment("NEST_CAMPAIGN_PREVIEW")
 if output.is_empty() or OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.master=0.0;game.prefs.apply()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://relief-preview.json";c.selected_mission=2;c.begin_solo(false)
 game.set_physics_process(false);c.set_process(false);c.guide.voice_supported=false
 var camera=Camera3D.new();game.add_child(camera);camera.far=1800;camera.fov=74
 var hud_only=OS.get_environment("NEST_RELIEF_HUD_ONLY")=="1"
 for mission in range(2,10):
  if mission!=2:c.journey.start_standalone(mission)
  for actor in game.actors:actor.set_physics_process(false)
  if not hud_only:
   for shot in [0,1,2]:
    c.cinematic.present(shot*5+2.0);await capture("mission-%02d-intro-%d"%[mission,shot])
  c.journey.finish_cinematic();c.cinematic.present(0);c.guide.stop_voice()
  await frames(3) # Let the previous HUD's queued controls retire before rebuilding guidance.
  for actor in game.actors:actor.set_physics_process(false)
  if mission==2:
   c.journey.motorcycles.interact(game.player,"bike:mount:1");c.journey.motorcycles.visual_update()
  game.player.camera.current=true;game.hud.visible=true;c.set_process(true);c.guide.update(true)
  await capture("mission-%02d-player-hud"%mission)
  c.set_process(false)
  if hud_only:continue
  for control in [c.guide.panel,c.guide.marker,c.guide.narration]:
   if is_instance_valid(control):control.visible=false
  game.hud.visible=false;camera.current=true
  if mission==2:
   for distance in [1700.0,2250.0,6100.0]:
    var at=NestCampaignMotorcycleWorld.point(distance);camera.position=at+Vector3(22,18,35);camera.look_at(NestCampaignMotorcycleWorld.point(distance+55)+Vector3.UP*3)
    await capture("mission-02-ridge-%d"%int(distance))
   var duck=NestCampaignMotorcycleWorld.point(300);camera.position=duck+Vector3(5,3.0,10);camera.look_at(duck+Vector3(0,1.7,-7));await capture("mission-02-branches")
  else:
   c.world.set_stage(3)
   var at=c.world.locations.objective1;camera.position=at+Vector3(-17,10,23);camera.look_at(at+Vector3.UP*2)
   await capture("mission-%02d-elevation"%mission)
   var cache=c.world.weapon_cache_points()[2];camera.position=cache+Vector3(2.2,2.1,3.4);camera.look_at(cache+Vector3.UP*.25)
   await capture("mission-%02d-cache"%mission)
   var end=c.world.locations.objective3;camera.position=end+Vector3(22,16,28);camera.look_at(end+Vector3.UP*2)
   await capture("mission-%02d-destination"%mission)
  await sample("mission-%02d-static"%mission)
  c.state.chapter_stage=c.state.chapter_stage_count-1;c.state.chapter_expected=0;c.state.chapter_spawned.clear();c.state.chapter_enemies.clear();c.state.chapter_defeated.clear();c.state.chapter_flags={"objective":true};c.state.chapters_completed=mission;c.journey._finish_presentation()
  for actor in game.actors:actor.set_physics_process(false)
  for shot in [0,1,2]:
   c.cinematic.present(shot*5+2.0);await capture("mission-%02d-outro-%d"%[mission,shot])
  print("RELIEF_CAPTURED ",mission)
 if not metrics.is_empty():
  var report=FileAccess.open(output+"/render-samples.json",FileAccess.WRITE);report.store_string(JSON.stringify(metrics,"  "));report.close()
 c.exit_campaign();game.queue_free();await frames(8);quit()
