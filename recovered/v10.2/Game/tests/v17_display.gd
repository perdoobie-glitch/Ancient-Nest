extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func fits(control: Control) -> bool:
 var rect=control.get_global_rect();var screen=control.get_viewport_rect()
 return rect.position.x>=-.5 and rect.position.y>=-.5 and rect.end.x<=screen.end.x+.5 and rect.end.y<=screen.end.y+.5
func motion(v: Vector2):
 var event=InputEventMouseMotion.new();event.relative=v;event.screen_relative=v;Input.parse_input_event(event)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var sizes=[Vector2i(800,600),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(3440,1440),Vector2i(3840,1080),Vector2i(5120,1440)]
 for physical in sizes:
  root.size=physical;NestDisplaySettings.apply_layout(root,0);await frames()
  var logical=root.get_visible_rect().size
  print("LAYOUT ",physical," logical ",logical)
  check(absf(logical.x/logical.y-float(physical.x)/physical.y)<.003,"Auto aspect fills "+str(physical))
  game.show_lobby();await frames()
  var lobby=game.screen.find_child("CustomLobby",true,false)
  check(lobby!=null and fits(lobby),"Lobby fits "+str(physical))
  game.open_settings("main");game.settings_tab="Video";game.show_settings();await frames()
  check(fits(game.screen.get_child(1)),"Video settings panel fits "+str(physical))
  check(game.screen.find_child("DisplayResolution",true,false)!=null and game.screen.find_child("DisplayAspectRatio",true,false)!=null,"Resolution/aspect controls are available")
 for aspect in range(1,NestDisplaySettings.ASPECTS.size()):
  NestDisplaySettings.apply_layout(root,aspect);await frames()
  var ratio=NestDisplaySettings.ASPECTS[aspect];var logical=root.get_visible_rect().size
  check(absf(logical.x/logical.y-float(ratio.x)/ratio.y)<.003,"Fixed aspect preserves "+NestDisplaySettings.ASPECT_LABELS[aspect])
 game.bot_fill=false;game.start_game();game.create_hud();game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process(false)
 var player=game.player;player.global_position=Vector3(600,100,600);player.rotation.y=0;player.eye.rotation.x=0;player.apply_aim_rotation();player.camera.global_position=player.eye.global_position
 game.clear_screen();game.current_screen="playing";game.context="playing";game.input_window_focused=true;game.prefs.values.sensitivity=2.;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 for physical in sizes:
  root.size=physical;NestDisplaySettings.apply_layout(root,0);await frames()
  var center=root.get_visible_rect().size*.5;var before=player.rotation.y;motion(Vector2(100,0))
  check(absf(wrapf(player.rotation.y-before,-PI,PI)+deg_to_rad(4.4))<.00001,"Raw-count aiming is unchanged at "+str(physical))
  check(player.camera.project_ray_normal(center).dot(-player.camera.global_basis.z)>.99999,"Camera ray stays at viewport/crosshair center "+str(physical))
  check(player.camera.keep_aspect==Camera3D.KEEP_HEIGHT and absf(player.camera.fov-game.prefs.values.fov)<.001,"Vertical FOV remains consistent "+str(physical))
  check(fits(game.hud_weapon) and fits(game.hud_chat) and game.hud_crosshair.size.is_equal_approx(root.get_visible_rect().size),"HUD corners and reticle fit "+str(physical))
 game.show_pause();game.open_settings("pause");game.settings_tab="Video";game.show_settings();await frames()
 var old=game.prefs.values.duplicate(true);game.draft.aspect_ratio=3;game.draft.resolution_width=1280;game.draft.resolution_height=720;game.apply_draft();await frames()
 check(game.display_until>0 and is_instance_valid(game.modal),"Resolution/aspect changes require Keep or Revert")
 game.revert_display();await frames();check(not NestDisplaySettings.changed(old,game.prefs.values),"Revert restores every display field")
 game.draft=game.prefs.values.duplicate(true);game.draft.aspect_ratio=4;game.apply_draft();await frames();game.display_until=Time.get_ticks_msec()/1000.0-.1;game._process(.016);await frames()
 check(not NestDisplaySettings.changed(old,game.prefs.values),"Expired confirmation restores every display field")
 game.draft=game.prefs.values.duplicate(true);game.draft.aspect_ratio=5;game.apply_draft();await frames();game.modal.confirmed.emit();await frames()
 var reloaded=NestPreferences.new();reloaded.load_saved();check(reloaded.values.aspect_ratio==5,"Confirmed aspect survives preference reload")
 reloaded.values.resolution_width=-5;reloaded.values.resolution_height=99999;reloaded.values.aspect_ratio=999;reloaded.validate()
 check(reloaded.values.resolution_width==640 and reloaded.values.resolution_height==4320 and reloaded.values.aspect_ratio==5,"Invalid display preferences are clamped")
 check(NestDisplaySettings.fit_window(Vector2i(3840,2160),Vector2i(1440,900)).x<=1440 and NestDisplaySettings.fit_window(Vector2i(3840,2160),Vector2i(1440,900)).y<=900,"Oversized window fits available desktop")
 game.stop_game();game.queue_free();await frames();print("V17 DISPLAY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
