extends SceneTree
func _initialize():call_deferred("run")
func frames(n=4):
 for i in range(n):await process_frame
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")
func run():
 root.size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation()
 p.melee();game.now+=.18;p.presentation.update_view_weapon(0)
 await capture("V26_Knife_FirstPerson")
 var v=NestActor.new();v.game=game;v.character_choice=0;v.faction=1;game.add_child(v);game.actors.append(v);v.set_physics_process(false);v.set_process(false)
 v.global_position=Vector3(800,100,800);v.action_state="melee";v.action_until=game.now+.8-.18;v.update_visual(0);v.skeleton.force_update_all_bone_transforms()
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(800,101.6,796.4);camera.look_at(Vector3(800,101.35,800));camera.fov=42;camera.current=true;game.hud.visible=false
 await capture("V26_Knife_ThirdPerson")
 game.stop_game();game.queue_free();await frames();quit()
