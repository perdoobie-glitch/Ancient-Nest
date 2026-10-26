extends SceneTree
func _initialize():call_deferred("run")
func frames(count=6):
 for i in range(count):await process_frame
func viewpoint(actor: NestActor,position: Vector3,target: Vector3):
 actor.global_position=position;var direction=(target-position-Vector3.UP*1.7).normalized();actor.rotation.y=atan2(-direction.x,-direction.z);actor.eye.rotation.x=asin(direction.y);actor.apply_aim_rotation();actor.reset_physics_interpolation()
func capture(file: String):
 await frames();var game=root.get_node_or_null("AncientNest")
 if game!=null and game.campaign.active:
  if game.context=="playing":game.campaign.update_objective_ui()
  game.campaign.guide.update(true)
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(file)
func run():
 var output=OS.get_environment("NEST_CAMPAIGN_PREVIEW");if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.shadows=true;game.prefs.apply();root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var c=game.campaign;c.save_store.path="user://campaign-preview-qa.json";c.menu();await capture(output+"/campaign-menu.png")
 c.begin_solo(false);c.set_process(false);game.set_physics_process(false);c.cinematic.present(8);await capture(output+"/connectuct-intro.png")
 c.cinematic.present(50);await capture(output+"/connectuct-atmosphere.png")
 for time in [28,72,92,112]:c.cinematic.present(time);await capture(output+"/intro-%03d.png"%time)
 c.state.phase="PREPARATION";c.present_phase();game.player.global_position=Vector3(-19,.1,18);game.player.rotation.y=-.5;game.player.eye.rotation.x=-.08;game.player.camera.current=true;c.cinematic.present(0);c.update_objective_ui();await capture(output+"/preparation.png")
 c.state.practice[str(c.local_slot)]={"look":true,"walk":true,"jump":true};await capture(output+"/tutorial-active-equipment.png")
 viewpoint(game.player,Vector3(30,.2,20),Vector3(43,3,-20));await capture(output+"/connectuct-hangar.png")
 viewpoint(game.player,Vector3(-35,.2,16),Vector3(-45,3,31));await capture(output+"/connectuct-freight.png")
 viewpoint(game.player,Vector3(28,20,12),Vector3(-2,.5,-20));await capture(output+"/landing-pad-base.png")
 viewpoint(game.player,Vector3(0,42,60),Vector3(0,0,-20));await capture(output+"/expanded-base.png")
 c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.cinematic.present(22);await capture(output+"/forest-crash.png")
 c.state.phase="CRASH_ORIENTATION";c.world.ship_root.position=Vector3.ZERO;c.world.ship_root.rotation=Vector3.ZERO;c.present_phase();game.player.global_position=Vector3(0,.2,29);game.player.rotation.y=0;game.player.eye.rotation.x=.04;game.player.camera.current=true;c.cinematic.present(0);c.update_objective_ui();await capture(output+"/crash-site-gameplay.png")
 for view in [{"name":"forest-west","position":Vector3(-25,2,29),"target":Vector3(-7,5,-4)},{"name":"forest-east","position":Vector3(25,2,28),"target":Vector3(9,5,-10)},{"name":"forest-valley","position":Vector3(12,28,36),"target":Vector3(0,12,-60)}]:
  viewpoint(game.player,view.position,view.target);await capture(output+"/"+str(view.name)+".png")
 game.hud.visible=false
 for view in [{"name":"ship-stern","position":Vector3(18,8,32),"target":Vector3(0,2,8)},{"name":"ship-nose","position":Vector3(-19,6,-16),"target":Vector3(0,2,4)},{"name":"maze-bridge","position":Vector3(-40,.3,40),"target":Vector3(-63,2,40)},{"name":"maze-clearing","position":Vector3(-20,.3,68),"target":Vector3(-20,2,54)},{"name":"maze-overview","position":Vector3(10,160,14),"target":Vector3(10,0,10)}]:
  viewpoint(game.player,view.position,view.target);await frames();game.hud.visible=false;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+str(view.name)+".png")
 if not c.world.maze.vertical_sites.is_empty():
  var garden=c.world.maze.vertical_sites[0];viewpoint(game.player,garden.entry+Vector3(4,1,4),garden.steps[2]+Vector3.UP);await frames();game.hud.visible=false;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/climbing-garden.png")
 var spot=c.world.maze.checkpoints[0];var enemy=c.make_actor(-9920,false,0,"Preview defender",spot+Vector3.UP*.25);enemy.die(game.player,"bullet");viewpoint(game.player,spot+Vector3(4,.3,6),spot+Vector3.UP)
 for i in range(8):game.input_window_focused=true;await physics_frame
 game.hud.visible=false;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/bot-weapon-release.png")
 for i in range(90):game.input_window_focused=true;await physics_frame
 game.hud.visible=false;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/bot-weapon-settled.png")
 var metrics={"cells":c.world.maze.cells.size(),"edges":c.world.maze.edges.size(),"spine_cells":c.world.maze.spine.size(),"maze":c.world.maze.stats,"nav_nodes":c.world.nav_points.size(),"batch":c.world.batch_stats}
 var report=FileAccess.open(output+"/expanded-metrics.json",FileAccess.WRITE);report.store_string(JSON.stringify(metrics," "));report.close()
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await frames()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 print("CAMPAIGN PREVIEW: captures saved");quit()
