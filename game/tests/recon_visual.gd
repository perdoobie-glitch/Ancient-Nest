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
 check(root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")==OK,"Saved rendered "+name)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=2;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules);game.selected_faction=1;game.clear_screen();game.start_game();game.create_hud();game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
 var p=game.player;p.position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation();game.hud.visible=true
 var radar=game.radar;radar.set_process(false);radar._refresh_contacts();game.set_hud_preferences()
 var enemies=game.actors.filter(func(a):return a.faction!=p.faction)
 var live=enemies[0];var stale=enemies[1]
 radar.contacts[live.get_instance_id()]={"actor":live,"pos":Vector3(-12,14,-12),"friend":false,"seen":game.now,"life":live.life_id,"live":true,"source":"view"}
 radar.contacts[stale.get_instance_id()]={"actor":stale,"pos":Vector3(14,0,8),"friend":false,"seen":game.now-4,"life":stale.life_id,"live":false,"source":"nu"};radar.queue_redraw()
 check(radar.size.x>radar.size.y and radar.offset_top>=125,"Annu full-map HUD is rectangular and clears the rank card")
 await capture("V30_Annu_Tactical_Map")
 p.nu_used=false;p.action_state="ready";p.cooldown=0
 var bird=game.nu.spawn(p,Vector3(0,44,-10),2.7,-.4);bird.set_physics_process(false);bird.velocity=Vector3.FORWARD*36;bird.boost_active=true;game.nu.update_flight_hud();game.nu._process(.016);p.presentation.update_view_weapon(0)
 check("3× BOOST" in game.nu.hint.text and game.nu.hint_panel.visible,"Compact Nu panel shows active boost and flight controls")
 await capture("V30_Nu_Boost_HUD")
 game.show_pause();game.open_settings("pause");await frames()
 check(game.screen.find_children("*","Label",true,false).any(func(n):return "Nu mouse sensitivity" in n.text),"Native Controls menu includes Nu sensitivity")
 await capture("V31_Nu_Controls")
 game.stop_game();game.queue_free();await frames(8)
 print("RECON VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
