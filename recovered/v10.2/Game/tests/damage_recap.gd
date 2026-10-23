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
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.current_screen="playing";game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
 var p=game.player;var e=game.actors.filter(func(a):return a!=p)[0];e.username="Red [Enemy]";e.global_position=Vector3(100,100,100)
 # Controlled energy changes isolate counting: pellets share one shot group.
 var before={"health":p.health,"shield":p.shield,"over":p.overshield,"armor":p.armor,"helmet":p.helmet_hp}
 p.shield-=5;p.record_damage_exchange(e,before,160,"bullet","head");before.shield=p.shield;p.shield-=5;p.record_damage_exchange(e,before,161,"bullet")
 var exchange=p.damage_received[e.combat_key()]
 check(exchange.hits==2 and exchange.shots==1,"Two shotgun pellets count as two hits from one landed shot")
 before.shield=p.shield;p.shield-=5;p.record_damage_exchange(e,before,176,"bullet");check(exchange.shots==2 and exchange.hits==3,"Next discharge counts as a new shot")
 check(exchange.get("head_hits",0)==1 and exchange.get("body_hits",0)==2,"Head and body pellets count separately")
 check(e.damage_given[p.combat_key()].head_hits==1 and e.damage_given[p.combat_key()].body_hits==2,"Outgoing head/body counts mirror victim records")
 check(e.damage_given[p.combat_key()].shots==2,"Outgoing shot count mirrors incoming count")
 p.last_damage_weapon="sniper";p.last_damage_region="head"
 p.death_recap=p.make_death_recap(e,"headshot")
 check(p.death_recap.final_weapon=="Sniper Rifle" or p.death_recap.final_weapon.to_lower().contains("sniper"),"Finishing weapon uses catalog display name")
 check(p.death_recap.final_hit=="headshot" and p.death_recap.final_kind=="sniper","Finishing hit type and weapon kind captured")
 check(not p.death_recap.taken.has("contacts"),"Internal shot deduplication data excluded from network recap")
 # Display fixture remains derived from the same authoritative recap format.
 p.death_recap.given={"normalized":43,"shots":2,"hits":3,"head_hits":1,"body_hits":2};p.death_recap.taken={"normalized":100,"shots":4,"hits":5,"head_hits":2,"body_hits":3};p.alive=false;game._process(0)
 check(game.hud_recap_panel.visible and game.hud_recap_panel.anchor_right==1,"Damage recap appears in top-right on death")
 check(game.hud_recap_panel.offset_bottom<game.hud_kill_notice.offset_top and game.hud_kill_notice.offset_bottom<game.hud_feed.offset_top,"Recap stacks above highlighted kill notice and feed")
 check(game.hud_death_recap.get_theme_font_size("normal_font_size")==13,"Damage recap uses compact type")
 check(game.hud_death_recap.text.contains("#8fd6a1") and game.hud_death_recap.text.contains("You dealt: 43/100 · 2 shots hit / 3 hits"),"Outgoing damage is green with landed-shot and hit counts")
 check(game.hud_death_recap.text.contains("#f28c8c") and game.hud_death_recap.text.contains("You took: 100/100 · 4 shots hit / 5 hits"),"Incoming damage is red and normalized out of 100")
 check(game.hud_death_recap.text.contains("Head: 1 · Body: 2[/color]") and game.hud_death_recap.text.contains("Head: 2 · Body: 3[/color]"),"Head/body breakdown stays inside outgoing green and incoming red spans")
 check(game.hud_death_recap.get_parsed_text().contains("Red [Enemy]") and game.hud_death_recap.get_parsed_text().contains("Headshot"),"Names cannot inject markup and final headshot is readable")
 check(game.hud_recap_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.hud_death_recap.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Recap does not capture mouse input")
 game.receive_kill_notice("Other opponent",999,1,game.match_session,game.round_number);game._process(0)
 if DisplayServer.get_name()!="headless":
  await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("/workspace/work/v24/screenshots/V24_Death_Damage_Recap.png")==OK,"Rendered compact death recap with kill notice below")
 p.respawn();game._process(0);check(not game.hud_recap_panel.visible and game.hud_kill_notice.offset_top==35,"Respawn hides recap and restores compact kill-feed placement")
 p.last_damage_weapon="sniper";p.death_recap=p.make_death_recap(e,"melee");check(p.death_recap.final_weapon=="Knife","Knife cannot inherit a stale finishing gun")
 p.last_damage_weapon="frag_grenade";p.death_recap=p.make_death_recap(e,"explosion");check(p.death_recap.final_weapon=="Frag Grenade" and p.death_recap.final_hit=="explosion","Grenade explosion is identified correctly")
 p.alive=false;p.death_recap=p.make_death_recap(null,"Fall");game._process(0);check(game.hud_death_recap.get_parsed_text()=="Eliminated: Fall","Environment death clears opponent exchange and final gun")
 p.respawn();p.shield=0;p.health=1;p.armor=0;p.helmet_hp=0
 p.take_damage(1000,"head","bullet",true,e,game.next_event()*16,Vector3.INF,"sniper")
 check(not p.alive and p.death_recap.final_kind=="sniper" and p.death_recap.final_hit=="headshot","Real lethal damage captures the actual finishing gun and headshot")
 check(p.death_recap.taken.head_hits==1 and p.death_recap.taken.get("body_hits",0)==0,"Actual lethal headshot is included in head/body totals")
 check(p.death_recap.taken.shots==1 and p.death_recap.taken.hits==1,"Real lethal contact includes the finishing shot once")
 game.stop_game();game.queue_free();await frames();print("DAMAGE RECAP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
