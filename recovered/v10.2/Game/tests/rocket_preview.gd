extends SceneTree
func _initialize():call_deferred("run")
func frames(n=4):
 for i in range(n):await process_frame
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")
func run():
 root.size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation()
 p.weapons.assign([NestWeaponCatalog.profile("rocket")]);p.ammo.assign([2]);p.reserve.assign([6]);p.slot=0;p.update_weapon_art();p.presentation.update_view_weapon(0)
 await capture("V27_Launcher")
 p.ammo[0]=0;p.reload_weapon();game.now=p.action_until-p.reload_duration*.55;p.presentation.update_view_weapon(0)
 await capture("V27_Rocket_Reload")
 var model=NestRocketArt.create();game.add_child(model);model.position=Vector3(900,102,900)
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(900.8,102.45,900.9);camera.look_at(model.position);camera.fov=40;camera.current=true;game.hud.visible=false
 await capture("V27_Rocket_Projectile")
 game.stop_game();game.queue_free();await frames();quit()
