extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=4):
 for i in range(n):await process_frame
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func run():
 root.size=Vector2i(960,600)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.start_game();game.clear_screen();game.context="pause";game.set_physics_process(false)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);await frames(6)
 var a=game.player;a.set_physics_process(false);a.global_position=Vector3(-13,7.1,0);a.rotation.y=-PI/2;a.eye.rotation.x=0
 if OS.get_environment("AN_HAND_CHARACTER")=="annu":a.set_character(1)
 var prefix="annu_" if a.character==1 else ""
 var index=0
 for kind in NestGunFeedback.STYLES:
  a.weapons[0]=NestWeaponCatalog.profile(str(kind));a.slot=0;a.action_state="ready";a.bomb_equipped=false;a.update_weapon_art();a.presentation.update_view(.016);a.presentation.pose_upper_body();await frames(3)
  check(a.weapon_art!=null and a.weapon_art.has_meta("gun_feedback"),"Weapon and unique muzzle: "+kind)
  check(a.presentation.left_hand.position.is_finite() and a.presentation.left_forearm.scale.is_finite(),"Finite support grip: "+kind)
  check(a.skeleton.get_bone_global_pose(a.skeleton.find_bone("hand_r")).origin.is_finite(),"Right hand rig: "+kind)
  a.action_state="switching";a.action_until=game.now+.2;a.presentation.update_view(.016)
  check(a.weapon_view.position.y<-.22,"Switch lowering: "+kind)
  a.action_state="ready";a.flash_until=game.now+.15;a.presentation.update_view(.016)
  await frames(2)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/workspace/work/v5-hands/%sweapon_%02d_%s.png"%[prefix,index,kind])
  index+=1
 game.mode=4;game.cs_carrier=a.net_id;a.bomb_equipped=true;a.action_state="bomb_drop";a.bomb_drop_at=game.now+.5;a.presentation.update_view(.016)
 check(a.presentation.view_bomb.visible and not a.weapon_art.visible,"First-person bomb removal hides gun")
 await frames(3)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v5-hands/"+prefix+"bomb_drop.png")
 game.queue_free();await frames();print("WEAPON REVIEW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
