extends SceneTree
var game
var folder="/workspace/work/v20_update/test-images/"
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,msg: String):
 checks+=1
 if ok:print("PASS: "+msg)
 else:failures+=1;push_error("FAIL: "+msg)
func capture(name: String):
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder+name+".png")==OK,"Rendered "+name)
func equip(a,kind: String,ammo: int=36):
 a.weapons.assign([NestWeaponCatalog.profile(kind)]);a.ammo.assign([ammo]);a.reserve.assign([144]);a.slot=0;a.action_state="ready";a.action_until=0;a.cooldown=0;a.burst_left=0;a.art_kind="";a.update_weapon_art();a.presentation.update(.016)
func run():
 DirAccess.make_dir_recursive_absolute(folder)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false);game.set_process(false);game.context="playing";game.clear_screen();game.current_screen="review"
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(5,14,6)*.85;p.rotation.y=-PI*.6;p.eye.rotation.x=0;p.reset_physics_interpolation();p.reset_aim();p.camera.global_transform=p.eye.global_transform;p.camera.current=true
 game.create_hud();game.hud.visible=true
 for kind in ["ak47","sniper","rocket"]:
  equip(p,kind);game._process(.016);p.presentation.update_view_weapon(0);await capture("Ammo_Counter_"+kind)
 equip(p,"plasma_br");game._process(.016);p.presentation.update_view_weapon(0)
 await capture("Plasma_Gun_Counter_36")
 p.ammo[0]=35;p.flash_until=game.now+.15;p.presentation.update_view_weapon(0);await capture("Plasma_Firing_Counter_35")
 p.flash_until=-INF;p.reload_weapon();game.now=p.action_until-p.reload_duration*.65;p.presentation.update_view_weapon(0);await capture("Plasma_Pack_From_Hip")
 game.now=p.action_until-p.reload_duration*.35;p.presentation.update_view_weapon(0);await capture("Plasma_Pack_Seated")
 p.action_state="ready";p.grenade_kind=1;p.throw_grenade();game.now=p.throw_started+.16;p.presentation.update_view_weapon(0);await capture("First_Person_Throw_Windup")
 game.now=p.throw_started+.20;p.advance_weapon_timers();p.presentation.update_view_weapon(0);await capture("First_Person_Throw_Release")
 # Isolated lit test platform: avoids changing the actual map to stage visibility tests.
 p.global_position=Vector3(200,30,200);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim();p.camera.global_transform=p.eye.global_transform;p.reset_physics_interpolation()
 game.arena.kit.box(game,Vector3(200,29.85,194),Vector3(24,.2,24),game.arena.kit.material(Color("74796c")))
 var e=NestActor.new();e.game=game;e.faction=1;e.username="EnemyUsername";game.add_child(e);game.actors.append(e);e.set_physics_process(false);e.set_process(false);e.global_position=Vector3(200,30,193);e.reset_physics_interpolation();e.update_visual(.016)
 p.camera.look_at(e.global_position+Vector3.UP*1.55*NestActor.SIZE);e.update_enemy_name_tag(.2);game.hud.visible=false
 check(e.enemy_name_tag.visible,"Reticle-near enemy label eligible in native renderer");await capture("Enemy_Name_Near_Reticle")
 p.camera.rotate_y(.18);e.update_enemy_name_tag(.1);check(not e.enemy_name_tag.visible,"Turning away hides red label");await capture("Enemy_Name_Hidden_Off_Aim")
 p.camera.look_at(e.global_position+Vector3.UP*1.55*NestActor.SIZE);e.update_enemy_name_tag(.2)
 # Film third-person grenade wind-up with a separate camera.
 p.camera.current=false;game.menu_camera.current=true;game.menu_camera.global_position=e.global_position+Vector3(2.3,1.8,3.2);game.menu_camera.look_at(e.global_position+Vector3.UP*1.35);game.menu_camera.fov=62
 e.action_state="throwing";e.action_until=game.now+.75;e.throw_started=game.now;e.throw_kind=1;game.now+=.16;e.update_visual(.016);await capture("Remote_Throw_Windup")
 game.now=e.throw_started+.23;e.update_visual(.016);await capture("Remote_Throw_Followthrough")
 var blast=NestBlastFX.new();game.effects.add_child(blast);blast.position=e.global_position+Vector3(1,0,0);blast.set_process(false);blast._process(.35);await capture("Rocket_Frag_Explosion_Smoke")
 print("V20 VISUAL: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
