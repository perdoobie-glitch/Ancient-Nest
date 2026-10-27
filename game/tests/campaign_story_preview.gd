extends SceneTree
# Focused rendered framing review. This fixture does not write ordinary saves.
var game
var output=""
func _initialize():call_deferred("run")
func frames(count=5):
 for i in range(count):await process_frame
func capture(name: String):
 await frames(5);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func run():
 output=OS.get_environment("NEST_CAMPAIGN_PREVIEW")
 if output.is_empty() or OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.master=0;game.prefs.apply()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://story-preview.json";c.begin_solo(false);c.guide.voice_supported=false
 game.set_physics_process(false);c.set_process(false)
 var camera=Camera3D.new();game.add_child(camera);camera.far=1800;camera.fov=68
 var selected=OS.get_environment("NEST_STORY_MISSIONS").split(",",false)
 for mission in [2,4,5,6,8,9]:
  if not selected.is_empty() and str(mission) not in selected:continue
  c.journey.start_standalone(mission)
  for actor in game.actors:actor.set_physics_process(false)
  await frames()
  for shot in range(3):
   c.cinematic.present(shot*5+2.0);await capture("mission-%02d-intro-%d"%[mission,shot])
  if mission in [5,6]:
   c.journey.finish_cinematic();c.cinematic.present(0);c.world.set_stage(3)
   camera.current=true;game.hud.visible=false
   var p=c.world.stage_center(1)
   camera.position=p+Vector3(4,4,18);camera.look_at(p+Vector3(24,3,-7));await capture("mission-%02d-machinery"%mission)
   var deck=c.world.raised_cache_sites[1];camera.position=deck+Vector3(8,4,7);camera.look_at(deck+Vector3(-2,1,-1));await capture("mission-%02d-service-deck"%mission)
  c.state.chapter_stage=c.state.chapter_stage_count-1;c.state.chapter_expected=0;c.state.chapter_spawned.clear();c.state.chapter_enemies.clear();c.state.chapter_defeated.clear();c.state.chapter_flags={"objective":true};c.state.chapters_completed=mission;c.world.set_stage(c.state.chapter_stage)
  game.player.global_position=c.world.locations["objective"+str(c.state.chapter_stage)]+Vector3(0,.25,2)
  c.journey._finish_presentation()
  for actor in game.actors:actor.set_physics_process(false)
  await frames()
  for shot in range(3):
   c.cinematic.present(shot*5+2.0);await capture("mission-%02d-outro-%d"%[mission,shot])
  if mission==9:c.cinematic.present(14.9);await capture("mission-09-ship-departure")
  print("STORY_CAPTURED ",mission)
 c.exit_campaign();game.queue_free();await frames(8);quit()
