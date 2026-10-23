extends SceneTree
var game
func _initialize():call_deferred("run")
func frames(n=5):
 for i in range(n):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.bot_fill=false;game.start_game();game.clear_screen();game.context="pause";game.set_physics_process(false);game.set_process(false)
 DisplayServer.window_set_size(Vector2i(1280,800));root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 var a=game.player;a.set_physics_process(false);a.set_process(false);a.global_position=Vector3(-13,7.1,0);a.rotation.y=-PI/2;a.eye.rotation.x=0;a.set_character(1)
 for kind in ["sniper","plasma_sniper"]:
  a.weapons[0]=NestWeaponCatalog.profile(kind);a.slot=0;a.ammo[0]=4;a.action_state="ready";a.bomb_equipped=false;a.update_weapon_art();a.last_shot_kind=kind;a.flash_until=100.15
  for step in [0,1,2,3]:
   game.now=100+([.04,.36,.68,1.38][step]);a.presentation.update_view(.016);a.presentation.pose_upper_body();await frames();await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/workspace/work/v6-sniper/%s_%d.png"%[kind,step])
 game.stop_game();game.queue_free();await create_timer(.4).timeout;quit()
