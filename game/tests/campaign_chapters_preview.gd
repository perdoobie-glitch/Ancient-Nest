extends SceneTree
var game
func _initialize():call_deferred("run")
func frames(count=5):
 for i in range(count):await process_frame
func capture(path: String):
 await frames(8)
 if game!=null and game.campaign.active and game.hud.visible:
  game.campaign.update_objective_ui();game.campaign.guide.update(true)
  await frames(2)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run():
 var output=OS.get_environment("NEST_CAMPAIGN_PREVIEW")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.shadows=true;game.prefs.apply()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://preview-chapters.json"
 c.menu();await capture(output+"/campaign-menu.png")
 NestCampaignUI.mission_select(c);await capture(output+"/mission-select.png")
 c.selected_mission=2;c.begin_solo(false)
 game.set_physics_process(false);c.set_process(false)
 var camera=Camera3D.new();game.add_child(camera);camera.far=1400;camera.fov=70
 for index in range(2,10):
  if index!=2:c.journey.start_standalone(index)
  for actor in game.actors:actor.set_physics_process(false)
  c.cinematic.present(0);c.update_objective_ui();c.guide.update(true)
  camera.current=false;game.player.camera.current=true
  var start=game.player.global_position
  var target=c.world.locations.get("objective0",start+Vector3(0,0,-40))
  var direction=(target-start-Vector3.UP*1.5).normalized()
  game.player.rotation.y=atan2(-direction.x,-direction.z);game.player.eye.rotation.x=asin(direction.y);game.player.apply_aim_rotation()
  await capture(output+"/mission-%02d-player.png"%index)
  if index==2:
   c.journey.motorcycles.interact(game.player,"bike:mount:1");c.journey.motorcycles.visual_update();game.player.update_visual(1.0/60);game.player.camera.current=true
   await capture(output+"/mission-02-mounted.png")
  game.hud.visible=false;camera.current=true
  camera.position=start+Vector3(46,48,45);camera.look_at(start.lerp(target,.65))
  await capture(output+"/mission-%02d-overview.png"%index)
  if index==9:
   var end=c.world.locations.get("objective2",target)
   camera.position=Vector3(32,12,-12);camera.look_at(Vector3(0,10,-55))
   await capture(output+"/mission-09-core.png")
  print("CAPTURED mission ",index)
 c.exit_campaign();game.queue_free();await frames();quit()
