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
func key(code,pressed,echo=false):
 var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;e.echo=echo;Input.parse_input_event(e)
func click(pressed):
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e)
func motion(value):
 var e=InputEventMouseMotion.new();e.screen_relative=value;e.relative=value*2;Input.parse_input_event(e)
func run():
 root.size=Vector2i(800,500)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);root.size=Vector2i(800,500);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.selected_faction=0;game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true
 game.set_physics_process(false);var p=game.player
 for i in range(10):await physics_frame
 p.set_physics_process(false);game.prefs.values.sensitivity=2.0
 check(Engine.get_version_info().major==4 and Engine.get_version_info().minor==6,"Runtime is Godot 4.6; screen_relative is supported")
 check(InputEventMouseMotion.new().get_property_list().any(func(v):return v.name=="screen_relative"),"screen_relative property verified on runtime")
 check(p.camera.top_level and p.camera.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Local camera cannot inherit interpolated player rotation")
 p.view_correction=Vector3(0,2.5,0);p._process(.016)
 check(p.camera.global_position.distance_to(p.eye.global_position)<=.50001,"Reconciliation camera offset stays inside authoritative shot-origin validation")
 p.view_correction=Vector3.ZERO;p.reset_aim()
 var before=p.rotation.y;motion(Vector2(100,0))
 check(absf(wrapf(p.rotation.y-before,-PI,PI)+deg_to_rad(4.4))<.00001,"Mouse counts update yaw synchronously before another frame")
 check((-p.camera.get_camera_transform().basis.z).dot(-p.eye.global_basis.z)>.99999,"Render camera rotation matches input immediately without a physics tick")
 p.rotation.y=0;p.eye.rotation.x=0;p.apply_aim_rotation();motion(Vector2(0,-100000))
 check(p.eye.rotation.x<=deg_to_rad(89)+.00001,"Pitch clamps without flipping")
 game.prefs.values.invert_y=true;p.eye.rotation.x=0;motion(Vector2(0,-10));check(p.eye.rotation.x<0,"Configured inversion works synchronously")
 game.prefs.values.invert_y=false;p.eye.rotation.x=0;p.apply_aim_rotation()
 var aim=p.resolve_shot_aim(100)
 check(aim.aim_point.distance_to(p.camera.global_position+(-p.camera.global_basis.z)*p.camera.global_position.distance_to(aim.aim_point))<.001,"Shot convergence uses the current visible camera ray")
 p.weapons[0]=NestWeaponCatalog.profile("magnum");p.ammo[0]=12;p.cooldown=game.now+.05
 var ammo=p.ammo[0];click(true);click(false);check(p.ammo[0]==ammo,"Cooldown prevents an early duplicate shot")
 game.now+=.06;await frames(2);check(p.ammo[0]==ammo-1,"Brief released fire press survives until cooldown ends")
 check(p.weapon_art.get_meta("gun_feedback").flash.visible,"Local muzzle flash updates while fixed physics is disabled")
 game.now+=.5;await frames(2);check(p.ammo[0]==ammo-1,"Released semiautomatic press is consumed exactly once")
 click(true);var single=p.ammo[0];game.now+=.5;click(true);await frames(2);check(p.ammo[0]==single,"Duplicate press without release cannot refire a semiautomatic weapon");click(false)
 ammo+=p.ammo[0]-(ammo-1)
 p.cooldown=game.now+.5;click(true);click(false);game.now+=.2;await frames(2);game.now+=.4;await frames(2)
 check(p.ammo[0]==ammo-1,"Expired fire intent does not fire much later")
 p.cooldown=game.now+.05;click(true);click(false);game.show_pause();game.now+=.1;game.resume_game();await frames(2)
 check(p.ammo[0]==ammo-1,"Pause cancels buffered shots")
 key(KEY_W,true);check(p.gameplay_move().y<-.9,"Forward key enters movement intent")
 game.show_pause();game.resume_game();key(KEY_W,true,true)
 check(p.gameplay_move()==Vector2.ZERO,"Held-key repeats cannot restart movement after pause")
 key(KEY_W,false);key(KEY_W,true);check(p.gameplay_move().y<-.9,"Release then fresh press restores movement")
 game.show_pause();game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN);game.resume_game()
 key(KEY_W,true);check(p.gameplay_move().y<-.9,"Fresh nonrepeat press recovers even when release happened outside the window")
 key(KEY_W,false)
 game.open_chat();game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.context=="pause" and not game.input_window_focused and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED,"Focus loss during chat releases capture and pauses input")
 var yaw=p.rotation.y;motion(Vector2(100,0));check(p.rotation.y==yaw,"Unfocused mouse movement cannot rotate the player")
 game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN);game.resume_game()
 var blocker=Button.new();game.hud.add_child(blocker);blocker.grab_focus();game.make_hud_passthrough(blocker);game.capture_mouse()
 check(blocker.mouse_filter==Control.MOUSE_FILTER_IGNORE and blocker.focus_mode==Control.FOCUS_NONE and root.gui_get_focus_owner()==null,"Read-only HUD cannot consume mouse or keyboard focus")
 p.set_physics_process(true);var feet=p.global_position
 key(KEY_W,true)
 for i in range(10):await physics_frame
 key(KEY_W,false)
 check(Vector2(p.global_position.x-feet.x,p.global_position.z-feet.z).length()>.1,"Forward input produces collision-simulated movement")
 for i in range(14):await physics_frame
 check(Vector2(p.controlled.x,p.controlled.z).length()<.01,"Released movement stops through the existing braking simulation")
 # Deliberately let idle frames occur between a quick key tap and a slow physics tick.
 Engine.physics_ticks_per_second=10;p.set_physics_process(true)
 for i in range(25):await physics_frame
 await process_frame;var start=p.global_position.y;key(KEY_SPACE,true);key(KEY_SPACE,false)
 await frames(4);await physics_frame;await physics_frame
 check(p.global_position.y>start+.3 and p.controlled.y>0,"Sub-tick jump tap survives idle frames and reaches collision simulation")
 var deadline=Time.get_ticks_msec()+2500
 while not p.is_on_floor() and Time.get_ticks_msec()<deadline:await physics_frame
 await physics_frame;check(p.is_on_floor() and absf(p.controlled.y)<.01,"Released jump does not repeat after landing")
 Engine.physics_ticks_per_second=60
 game.stop_game();game.queue_free();await frames(8)
 print("INPUT RELIABILITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
