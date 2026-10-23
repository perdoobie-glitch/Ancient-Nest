extends SceneTree
var game
var checks=0
var failures=0
var results=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=2):
 for i in range(n):await process_frame
func fits(control: Control) -> bool:
 var r=control.get_global_rect();var s=control.get_viewport_rect();return r.position.x>=-.5 and r.position.y>=-.5 and r.end.x<=s.end.x+.5 and r.end.y<=s.end.y+.5
func snap(name: String):
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/v17/"+name+".png")
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 root.grab_focus();game.show_lobby();root.size=Vector2i(800,600);NestDisplaySettings.apply_layout(root,0);await frames(3)
 check(fits(game.screen.find_child("CustomLobby",true,false)),"Native 4:3 lobby fits");await snap("v17-lobby-4x3")
 game.open_settings("main");game.settings_tab="Video";game.show_settings();await frames();check(fits(game.screen.get_child(1)),"Native Video settings fit and display controls render");await snap("v17-video-options")
 game.bot_fill=false;game.start_game();game.create_hud();game.clear_screen();game.current_screen="playing";game.context="playing";game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(7,14.05,14)*.85;p.rotation.y=0;p.eye.rotation.x=0;p.apply_aim_rotation();p.camera.global_position=p.eye.global_position;p.reset_physics_interpolation()
 game.hud.visible=true;game.input_window_focused=true;game.prefs.values.sensitivity=2.;game.capture_mouse()
 for size in [Vector2i(800,600),Vector2i(960,600),Vector2i(960,540),Vector2i(1260,540),Vector2i(1280,360)]:
  root.size=size;NestDisplaySettings.apply_layout(root,0);await frames(3)
  var logical=root.get_visible_rect().size
  check(absf(logical.x/logical.y-float(size.x)/size.y)<.003,"Native viewport follows "+str(size))
  var before=p.rotation.y;var event=InputEventMouseMotion.new();event.relative=Vector2(100,0);event.screen_relative=Vector2(100,0);event.position=Vector2(size)*.5;Input.parse_input_event(event)
  check(absf(wrapf(p.rotation.y-before,-PI,PI)+deg_to_rad(4.4))<.00001,"Native raw mouse sensitivity holds "+str(size))
  check(p.camera.project_ray_normal(logical*.5).dot(-p.camera.global_basis.z)>.99999,"Native aim and crosshair center align "+str(size))
  check(fits(game.hud_weapon) and fits(game.radar),"Native HUD remains inside viewport "+str(size))
  results.append({"window":size,"logical":logical,"mode":"Auto"})
  if size.x==1260:await snap("v17-ultrawide-game")
 root.size=Vector2i(1260,540);NestDisplaySettings.apply_layout(root,0)
 p.weapons[0]=NestWeaponCatalog.profile("sniper");p.ammo[0]=4;p.scope_level=1
 for i in range(15):p.update_aim(.033);await process_frame
 game.hud_crosshair._process(.016);await frames();check(game.hud_crosshair.scope_mask.visible,"Ultrawide sniper overlay renders")
 check(game.hud_crosshair.scope_material.get_shader_parameter("viewport_size").is_equal_approx(game.hud_crosshair.size),"Scope shader uses current logical aspect")
 await snap("v17-ultrawide-scope")
 p.scope_level=0;root.size=Vector2i(1280,720);NestDisplaySettings.apply_layout(root,1);await frames(3)
 check(absf(root.get_visible_rect().size.x/root.get_visible_rect().size.y-4.0/3)<.001,"Forced 4:3 uses an undistorted 4:3 viewport")
 game.show_pause();await frames();await snap("v17-forced-4x3-pause")
 game.open_settings("pause");game.settings_tab="Video";game.show_settings();await frames()
 var old=game.prefs.values.duplicate(true);game.draft=old.duplicate(true);game.draft.fullscreen=true;game.draft.aspect_ratio=0;game.apply_draft();await frames(3)
 check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Native borderless fullscreen applies")
 game.revert_display();await frames(3)
 check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and not NestDisplaySettings.changed(old,game.prefs.values),"Native revert restores window mode, size and aspect preferences")
 FileAccess.open("/workspace/work/v17/native-layouts.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 game.stop_game();game.queue_free();await frames(3);print("V17 NATIVE DISPLAY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
