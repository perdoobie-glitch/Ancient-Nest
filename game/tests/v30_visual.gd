extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=5):
 for i in range(n):await process_frame
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS VISUAL: "+text)
 else:failures+=1;push_error(text)
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 var error=root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")
 check(error==OK,"Saved rendered "+name)
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=2;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.set_physics_process(false)
 var p=game.player
 for i in range(game.actors.size()):
  var a=game.actors[i];a.set_physics_process(false);a.set_process(false);a.position=Vector3(120+i*4,35,120);a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.update_visual(0)
 var a=game.actors.filter(func(n):return n.character==1)[0]
 p.position=Vector3(99.15,30,100);a.position=Vector3(100.85,30,100);p.model.visible=true;a.model.visible=true;p.weapon_view.visible=false;game.hud.visible=false
 p.presentation.pose_upper_body();a.presentation.pose_upper_body()
 var k=game.arena.kit;k.box(game,Vector3(100,29.92,100),Vector3(6,.12,4),k.stone)
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(100,31.55,94.8);camera.look_at(Vector3(100,31.12,100));camera.fov=49;camera.current=true
 await capture("V30_Characters")
 p.position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation();p.camera.current=true;p.model.visible=false;p.weapon_view.visible=true;game.hud.visible=true
 p.wield_sword();game.now=p.action_until+.01;p.advance_weapon_timers();p.update_weapon_art();p.presentation.update_view_weapon(0)
 await capture("V30_Sword")
 var index=0
 for i in range(p.weapons.size()):
  if p.weapons[i].kind=="plasma_pistol":index=i
 p.slot=index;p.action_state="ready";p.update_weapon_art();p.presentation.update_view_weapon(0)
 await capture("V30_Plasma_Pistol")
 game.context="pause";game.open_game_type_settings();await frames()
 var editor=game.game_type_editor;editor.jump_to_category("Bots");await frames()
 check(editor.visible and editor.tabs.get_tab_title(editor.tabs.current_tab)=="Bots","Unified menu selects Bots tab")
 await capture("V30_Match_Settings")
 editor.hide();editor.queue_free();game.context="playing";game.hud.visible=false;p.camera.current=false
 a.position=Vector3(100,30,100);a.nu_used=true;a.perched_nu.visible=false;a.action_state="nu_launch";a.nu_launch_until=game.now+.75;a.presentation.pose_upper_body();camera.position=Vector3(100,31.55,97.0);camera.look_at(Vector3(100,31.25,100));camera.fov=50;camera.current=true
 await capture("V30_Nu_Launch")
 var bird=NestFalconArt.create();game.add_child(bird);bird.position=Vector3(100,32,97);NestFalconArt.animate(bird,.16,true,0)
 camera.position=Vector3(101.0,32.5,95.8);camera.look_at(bird.position);camera.fov=47;camera.current=true
 await capture("V30_Nu_Falcon")
 bird.queue_free();a.action_state="ready"
 p.set_character(1);p.nu_used=false;p.action_state="ready";p.cooldown=0;p.position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation();p.camera.current=true;game.hud.visible=true
 p.position=Vector3(0,42,-10);game.nu.spawn(p,p.position+Vector3.UP*2+Vector3(-.427,0,.904)*2.5,2.7,-.4)
 if is_instance_valid(game.nu.local_bird):
  game.nu.local_bird.set_physics_process(false);game.nu._process(.016);p.presentation.update_view_weapon(0)
  check(p.model.visible and not p.weapon_view.visible,"Falcon view shows the vulnerable body and hides first-person gun")
  await capture("V30_Nu_View")
 game.stop_game();game.queue_free();await frames(8)
 print("V30 VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
