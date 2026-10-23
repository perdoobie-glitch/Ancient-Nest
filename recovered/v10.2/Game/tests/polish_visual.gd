extends SceneTree
var game
var camera: Camera3D
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=5):
 for i in range(n):await process_frame
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS VISUAL: "+label)
 else:failures+=1;push_error(label)
func freeze():
 game.set_physics_process(false);game.set_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
func capture(name: String,origin: Vector3,target: Vector3):
 camera.position=origin;camera.look_at(target);camera.current=true
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")==OK,"Rendered "+name)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 await frames();var rules=GameTypeSettings.new();rules.map_selection=1;rules.mode=4;rules.bots_fill_empty_slots=true;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();freeze();game.hud.visible=false
 camera=Camera3D.new();camera.fov=68;game.add_child(camera)
 check(not game.arena.sun.shadow_enabled and root.msaa_3d==Viewport.MSAA_DISABLED,"Crossroads renders in Low mode")
 await capture("V33_Low_Crossroads",Vector3(3,2.4,14)*Vector3(.85,.85,1.1475),Vector3(-2,4,2)*Vector3(.85,.85,1.1475))
 game.stop_game();rules.map_selection=0;game.apply_game_type_settings(rules);game.start_game();freeze();game.hud.visible=false
 await capture("V33_Low_Sanctuary",Vector3(-8,12,17)*.85,Vector3(20,10,-6)*.85)
 game.stop_game();game.open_settings("lobby");game.settings_tab="Video";game.show_settings();await frames()
 check(game.screen.find_child("GraphicsQuality",true,false).selected==0,"Video menu shows Low as active")
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/V33_Low_Settings.png")==OK,"Rendered Low-mode settings menu")
 game.queue_free();await frames(8)
 print("V33 LOW VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
