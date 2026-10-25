extends SceneTree
func _initialize():call_deferred("run")
func frames(count=6):
 for i in range(count):await process_frame
func capture(file: String):
 await frames();var game=root.get_node_or_null("AncientNest")
 if game!=null and game.campaign.active and game.context=="playing":game.campaign.update_objective_ui()
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(file)
func run():
 var output=OS.get_environment("NEST_CAMPAIGN_PREVIEW");if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.shadows=false;game.prefs.apply();root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://campaign-preview-qa.json";c.menu();await capture(output+"/campaign-menu.png")
 c.begin_solo(false);c.set_process(false);game.set_physics_process(false);c.cinematic.present(8);await capture(output+"/connectuct-intro.png")
 c.state.phase="PREPARATION";c.present_phase();game.player.global_position=Vector3(-19,.1,18);game.player.rotation.y=-.5;game.player.eye.rotation.x=-.08;game.player.camera.current=true;c.cinematic.present(0);c.update_objective_ui();await capture(output+"/preparation.png")
 c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.cinematic.present(22);await capture(output+"/forest-crash.png")
 c.state.phase="CRASH_ORIENTATION";c.world.ship_root.position=Vector3.ZERO;c.world.ship_root.rotation=Vector3.ZERO;c.present_phase();game.player.global_position=Vector3(0,.2,29);game.player.rotation.y=0;game.player.eye.rotation.x=.04;game.player.camera.current=true;c.cinematic.present(0);c.update_objective_ui();await capture(output+"/crash-site-gameplay.png")
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await frames()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 print("CAMPAIGN PREVIEW: five captures saved");quit()
