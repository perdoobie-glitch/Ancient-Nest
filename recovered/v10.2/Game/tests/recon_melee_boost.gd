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
func wall(pos: Vector3) -> StaticBody3D:
 var body=StaticBody3D.new();body.collision_layer=1
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(8,8,.2);collision.shape=shape;body.add_child(collision);game.add_child(body);body.position=pos;return body
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=2;rules.bots_fill_empty_slots=true;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules);game.selected_faction=1;game.clear_screen();game.start_game();game.create_hud();game.set_physics_process(false)
 for i in range(game.actors.size()):
  var a=game.actors[i];a.set_physics_process(false);a.set_process(false);a.position=Vector3(130+i*10,70,130);a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.update_visual(0)
 var p=game.player;var enemy=game.actors.filter(func(a):return a.faction!=p.faction)[0]
 p.position=Vector3(110,70,110);p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.camera.global_position=p.eye.global_position;p.apply_aim_rotation();p.camera.current=true
 enemy.position=p.position+Vector3.FORWARD*12;enemy.velocity=Vector3.ZERO;enemy.update_visual(0);game.context="playing";game.now=100
 var radar=game.radar;radar._refresh_contacts();var id=enemy.get_instance_id()
 check(radar.tactical!=null,"Annu selects the tactical map instead of Naki's motion radar")
 check(radar.contacts.has(id) and radar.contacts[id].live,"A stationary enemy visible on screen appears immediately")
 check(radar.tactical.footprints.size()>30 and radar.tactical.world_rect.size.x>60,"Map geometry covers the whole arena rather than a short radar radius")
 var glass=wall(p.position+Vector3.FORWARD*6+Vector3.UP*2);glass.set_meta("surface_material","glass");await physics_frame;await physics_frame
 check(game.vision_clear(p.camera.global_position,enemy.position+Vector3.UP*1.5),"Transparent glass transmits Annu/Nu sight while keeping physical collision")
 var opaque=wall(p.position+Vector3.FORWARD*9+Vector3.UP*2);await physics_frame;await physics_frame
 check(not game.vision_clear(p.camera.global_position,enemy.position+Vector3.UP*1.5),"Opaque cover behind glass still blocks spotting")
 glass.queue_free();opaque.queue_free();await physics_frame;await physics_frame
 var seen=radar.contacts[id].pos;var barrier=wall(p.position+Vector3.FORWARD*6+Vector3.UP*2);await physics_frame;await physics_frame
 game.now=101;enemy.position+=Vector3.RIGHT*2;radar._refresh_contacts()
 check(not radar.contacts[id].live and radar.contacts[id].pos==seen,"Cover freezes the last-seen contact instead of tracking through a wall")
 game.now=109.99;radar._refresh_contacts();check(radar.contacts.has(id),"Annu retains the last sighting for ten seconds")
 game.now=110.01;radar._refresh_contacts();check(not radar.contacts.has(id),"Unseen contacts expire after ten seconds")
 barrier.queue_free();await physics_frame;await physics_frame
 game.now=111;radar._refresh_contacts();check(radar.contacts.has(id) and radar.contacts[id].pos==enemy.position,"Seeing the enemy again updates its map position")
 p.rotation.y=PI;p.apply_aim_rotation();game.now=116;radar._refresh_contacts()
 check(not radar.contacts[id].live and radar.contacts[id].seen==111,"An enemy behind the camera is last-seen rather than freshly detected")
 p.rotation.y=0;p.apply_aim_rotation();game.now=117;radar._refresh_contacts();p.rotation.y=PI;p.apply_aim_rotation();game.now=122;radar._refresh_contacts()
 check(radar.contacts.has(id) and radar.contacts[id].seen==117,"A fresh sighting resets the ten-second memory window")
 # A server Nu sighting reaches the team map even outside the player's view.
 game.now=123;game.record_nu_sighting(p.faction,enemy);radar._refresh_contacts()
 check(radar.contacts[id].source=="nu" and radar.contacts[id].seen==123,"Nu reports refresh the owning team's map")
 var nu_position=radar.contacts[id].pos;enemy.position+=Vector3.RIGHT*4;game.now=128;radar._refresh_contacts()
 check(radar.contacts[id].pos==nu_position and radar.contacts[id].seen==123,"Old Nu reports cannot track a moving enemy or extend the timer")
 game.now=133.01;radar._refresh_contacts();check(not radar.contacts.has(id),"Nu memory expires ten seconds after the real sighting")
 game.now=134;game.record_nu_sighting(1-p.faction,enemy);radar._refresh_contacts();check(not radar.contacts.has(id),"Opposing-team Nu reports are never added to this map")
 game.now=135;game.record_nu_sighting(p.faction,enemy);radar._refresh_contacts();enemy.life_id+=1;radar._refresh_contacts();check(not radar.contacts.has(id),"A respawn invalidates a prior-life contact")
 p.set_character(0);enemy.position=p.position+Vector3.FORWARD*40;enemy.velocity=Vector3.ZERO;radar._refresh_contacts()
 check(not radar.contacts.has(id),"Naki still uses range and motion detection, without Annu memory")
 enemy.position=p.position+Vector3.FORWARD*10;enemy.velocity=Vector3.RIGHT;radar._refresh_contacts();check(radar.contacts.has(id),"Naki's original moving-enemy radar still works")
 check(is_equal_approx(game.damage_rules.melee_range_m,3*.83) and is_equal_approx(game.damage_rules.melee_hit_range_m,2.1*.83),"Sword and knife target/contact ranges are reduced by seventeen percent")
 p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;enemy.position=p.position+Vector3.RIGHT*15
 check(is_equal_approx(p.melee_lunge().length(),1.22*.83),"Maximum sword lunge is reduced by seventeen percent")
 p.set_character(1);check(is_equal_approx(p.melee_lunge().length(),1.22*.83),"Annu knife uses the same reduced lunge cap")
 check(is_equal_approx(game.damage_rules.melee_reach_padding_scale,.83),"The extra contact-height allowance is scaled too")
 check(is_equal_approx(game.damage_rules.melee_cooldown_seconds,.8/1.15) and is_equal_approx(game.damage_rules.melee_windup_seconds,.12/1.15),"Knife cooldown/contact timing is fifteen percent faster")
 p.action_state="ready";p.cooldown=0;game.now+=1;p.melee();check(is_equal_approx(p.action_until-game.now,.8/1.15),"Actual Annu knife uses the faster animation duration")
 p.action_state="ready";p.cooldown=0
 # Physical flight uses exactly 3x the normalized velocity, swept through cover.
 p.nu_used=false;p.action_state="ready";p.cooldown=0;p.position=Vector3(110,70,110);p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO
 var bird=game.nu.spawn(p,p.position+Vector3.UP*4+Vector3.FORWARD*4,0,0);bird.set_physics_process(false)
 Input.action_press("nu_boost");var expected=NestNuFalcon.step_velocity(Vector3.FORWARD*10,0,0,Vector3.ZERO,1.0/60,true)
 bird.velocity=Vector3.FORWARD*10;bird._physics_process(1.0/60)
 check(bird.boost_active and bird.velocity.is_equal_approx(expected*3),"Holding boost gives exactly three times the normal flight speed")
 game.nu.update_flight_hud();check("3× BOOST" in game.nu.hint.text and "3× speed" in game.nu.hint.text and "Space flap" in game.nu.hint.text,"Compact flight HUD displays boost mode and controls")
 Input.action_release("nu_boost");var unboosted=NestNuFalcon.step_velocity(bird.velocity/3,0,0,Vector3.ZERO,1.0/60,true);bird._physics_process(1.0/60)
 check(not bird.boost_active and bird.velocity.is_equal_approx(unboosted),"Releasing boost restores normal speed without stacking")
 Input.action_press("nu_boost");game.context="pause";bird._physics_process(1.0/60)
 check(not bird.boost_active,"Pause suppresses boost and active flight controls")
 Input.action_release("nu_boost");game.context="playing";Input.action_press("nu_boost");bird.velocity=Vector3.FORWARD*20
 barrier=wall(bird.position+Vector3.FORWARD*.7);await physics_frame;await physics_frame;bird._physics_process(1.0/60)
 check(not game.nu.birds.has(p.net_id),"Boosted swept flight still collides with nearby cover")
 Input.action_release("nu_boost");barrier.queue_free()
 var sniper=NestWeaponCatalog.profile("sniper")
 check(is_equal_approx(sniper.interval,60.0/44) and is_equal_approx(load("res://resources/sniper.tres").interval,sniper.interval),"Sniper catalog and resource have ten percent faster fire rate (44 RPM)")
 p.weapons.assign([sniper]);p.ammo.assign([4]);p.reserve.assign([12]);p.slot=0;p.action_state="ready";p.cooldown=0;p.burst_left=0;game.now=200;await frames()
 check(p.fire_trigger(),"Sniper first eligible shot fires immediately")
 game.now=200+sniper.interval-.01;await frames();check(not p.fire_trigger() and p.ammo[0]==3,"Sniper cannot fire before its shorter cooldown")
 game.now=200+sniper.interval+.001;await frames();check(p.fire_trigger() and p.ammo[0]==2,"Sniper fires its next round at the ten percent faster cadence")
 var rocket=NestWeaponCatalog.profile("rocket")
 check(is_equal_approx(rocket.speed,32.8125) and is_equal_approx(load("res://resources/rocket.tres").speed,rocket.speed),"Rocket profile/resource reduce travel time by twenty percent")
 check(is_equal_approx(100.0/rocket.speed,(100.0/26.25)*.8) and NestWeaponCatalog.for_kind("rocket").splash_radius_m==8.0,"Rocket keeps exact travel-time and twenty-five percent radius ratios")
 var far=game.actors.filter(func(a):return a.faction!=p.faction and a!=enemy)[0]
 p.position=Vector3(100,70,100);enemy.position=Vector3(117,70,110);far.position=Vector3(118.1,70,110);enemy.update_visual(0);far.update_visual(0)
 var before=enemy.health+enemy.shield;var far_before=far.health+far.shield
 await physics_frame;game.explode(Vector3(110,70+NestActor.STAND_CENTER,110),p,game.next_event()*16,240,false,"rocket")
 check(enemy.health+enemy.shield<before,"Rocket blast reaches a target seven meters away, beyond the old radius")
 check(far.health+far.shield==far_before,"Rocket blast still excludes targets beyond the new eight-meter radius")
 game.stop_game();game.queue_free();await frames(8)
 print("RECON MELEE BOOST: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
