extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.selected_faction=1;game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.position=Vector3(110,70,110);p.action_state="ready";p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO
 var bird=game.nu.spawn(p,p.position+Vector3.UP*4+Vector3.FORWARD*4,0,0);bird.set_physics_process(false)
 check(game.prefs.values.nu_flight_assist,"Nu flight assist defaults on")
 var move=InputEventMouseMotion.new();move.screen_relative=Vector2(20,0)
 game.prefs.values.sensitivity=9;game.prefs.values.nu_sensitivity=2;var before=bird.yaw;game.nu._input(move);var normal=bird.yaw-before
 game.prefs.values.nu_sensitivity=4;before=bird.yaw;game.nu._input(move)
 check(is_equal_approx(bird.yaw-before,normal*2),"Nu sensitivity changes independently and proportionally")
 check(p.rotation.y==0 and p.eye.rotation.x==0,"Adjusting Nu steering never changes body aim")
 check(is_equal_approx(game.nu.camera.rotation.y,bird.yaw),"Nu view responds immediately with the selected sensitivity")
 game.prefs.values.nu_flight_assist=false;game.nu.read_controls(bird);check(not bird.assist_enabled,"Manual flight can be selected without assist")
 game.prefs.values.nu_flight_assist=true;game.nu.read_controls(bird);check(bird.assist_enabled,"Assist can be enabled again")
 var velocity=Vector3.FORWARD*8;var direction=-Basis.from_euler(Vector3(0,.5,0)).z
 var manual=NestNuFalcon.step_velocity(velocity,.5,0,Vector3.ZERO,1.0/60,false)
 var guided=NestNuFalcon.step_velocity(velocity,.5,0,Vector3.ZERO,1.0/60,true)
 check(guided.normalized().dot(direction)>manual.normalized().dot(direction),"Guidance makes flight direction follow aim more easily")
 check(absf(guided.y)<absf(manual.y),"Level-flight assistance reduces accidental altitude loss")
 var stall=NestNuFalcon.step_velocity(Vector3.ZERO,0,0,Vector3.ZERO,1.0/60,true)
 check(stall.y<0 and stall.z<0,"Assisted flight still has gravity and forward motion, not hover")
 var pref=NestPreferences.new();pref.values.nu_sensitivity=5.5;pref.values.nu_flight_assist=false;pref.save();var loaded=NestPreferences.new();loaded.load_saved()
 check(loaded.values.nu_sensitivity==5.5 and not loaded.values.nu_flight_assist,"Nu sensitivity and assistance survive saving and reloading")
 pref.values.nu_sensitivity=100;pref.validate();check(pref.values.nu_sensitivity==20,"Nu sensitivity is clamped to a supported range")
 game.context="pause";game.open_settings("pause");await frames()
 var labels=game.screen.find_children("*","Label",true,false)
 check(labels.any(func(n):return "Nu mouse sensitivity" in n.text) and game.screen.find_children("*","CheckButton",true,false).any(func(n):return "Nu flight assist" in n.text),"Controls menu exposes separate Nu sensitivity and flight-assist settings")
 game.nu.update_flight_hud();check("ASSIST ON" in game.nu.hint.text,"Flight HUD displays the current assist mode")
 game.stop_game();game.queue_free();await frames(8)
 print("NU EASE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
