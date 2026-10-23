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
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")
func rows():return game.scoreboard.content.get_children().filter(func(c):return c.has_meta("actor"))
func run():
 root.size=Vector2i(1280,720)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=0;rules.max_players_per_team=5;rules.bots_fill_empty_slots=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
 var p=game.player;p.ammo[0]=24;p.reserve[0]=96;p.global_position=Vector3(10,17,-17);p.rotation.y=2.7;p.eye.rotation.x=-.08;p.reset_physics_interpolation();p.camera.global_position=p.eye.global_position;p.apply_aim_rotation()
 game.scores.assign([12,9]);game.round_number=5;game.deadline=game.now+84
 var index=0
 for a in game.actors:
  a.kills=8-index%5;a.deaths=3+index%3;a.assists=2;a.delivered=3-index%3;a.detonations=1 if index%3==0 else 0;index+=1
 game.reference_hud.refresh();game.scoreboard.visible=true;game.scoreboard.refresh(true);await frames()
 check(game.reference_hud.left_score.text=="12" and game.reference_hud.right_score.text=="9" and game.reference_hud.clock_label.text=="1:24","Top strip uses live team scores and time")
 check(game.reference_hud.ammo.text=="24 / 96","Ammo uses actual magazine and reserve")
 check(not game.hud_top.visible and not game.hud_weapon.visible,"Legacy text does not overlap new HUD")
 check(rows().size()==10,"Every participant appears once")
 check(rows().all(func(row):return row.get_child(0).get_child_count()==7),"Extraction rows have aligned player/K/D/A/gold/bombs/ping columns")
 check(game.scoreboard.content.find_children("RankEmblem","TextureRect",true,false).size()==10,"Rank badges remain in player rows")
 check(game.scoreboard.ping_for(game.actors.filter(func(a):return not a.local_player)[0])=="—","Bots have no fabricated ping")
 var first=rows()[0];var actor=first.get_meta("actor");var row=first.get_child(0)
 check(row.get_child(1).text==str(actor.kills) and row.get_child(4).text==str(actor.delivered) and row.get_child(5).text==str(actor.detonations),"Row columns route each statistic to its correct field")
 var original_name=actor.username
 actor.username="Name [color=red] literal";game.scoreboard.refresh(true)
 check(rows().any(func(r):return r.get_meta("actor")==actor and r.find_child("PlayerName",true,false).text.contains(actor.username)),"Player names remain literal text")
 check(game.scoreboard.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.reference_hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"HUD cannot capture mouse input")
 actor.username=original_name;game.scoreboard.refresh(true)
 Input.action_press("scoreboard");await frames();check(game.scoreboard.visible,"Held scoreboard action opens the rendered panel")
 await capture("V26_Reference_Scoreboard")
 for resolution in [Vector2i(640,360),Vector2i(1920,1080),Vector2i(2560,1080)]:
  root.size=resolution;await frames(5);game.scoreboard.refresh(true);await frames(3)
  var rect=game.scoreboard.get_global_rect();check(rect.position.x>=0 and rect.end.x<=root.get_visible_rect().size.x+1,"Scoreboard stays within %s"%str(resolution))
  var fits=true
  for item in rows():
   var h=item.get_child(0)
   fits=fits and h.get_global_rect().end.x<=rect.end.x+1
  check(fits,"Stat columns fit without horizontal overflow at %s"%str(resolution))
 root.size=Vector2i(1280,720);await frames()
 for mode in [1,2,3,4]:
  game.mode=mode;game.scoreboard.refresh(true);await frames()
  var wanted=7 if mode==3 else 5
  check(rows().size()==10 and rows().all(func(r):return r.get_child(0).get_child_count()==wanted),"Mode %d uses meaningful aligned stat columns"%mode)
 game.mode=1;p.kills=20;game.reference_hud.refresh();check(game.reference_hud.left_name.text=="LEADER" and game.reference_hud.right_score.text=="20","Slayer shows leader versus personal score")
 p.ammo[0]=0;p.action_state="reloading";game.reference_hud.refresh();check(game.reference_hud.ammo.text.begins_with("0 /") and game.reference_hud.weapon_status.text.contains("RELOADING"),"Empty/reloading state is visible")
 p.traits.settings.infinite_ammo=2;game.reference_hud.refresh();check(game.reference_hud.ammo.text=="∞ / ∞","Infinite-ammunition rules display correctly")
 p.traits.settings.infinite_ammo=0;p.ammo[0]=24;p.action_state="ready";game.mode=0;Input.action_release("scoreboard");game.scoreboard.visible=false;game.reference_hud.refresh()
 await capture("V26_Reference_InGame_HUD")
 game.stop_game();game.queue_free();await frames(8)
 print("REFERENCE HUD: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
