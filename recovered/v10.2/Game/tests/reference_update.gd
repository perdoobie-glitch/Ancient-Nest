extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func equip(p: NestActor,kind: String) -> void:
 p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.slot=0;p.ammo.assign([p.weapons[0].magazine]);p.reserve.assign([p.weapons[0].reserve]);p.action_state="ready";p.action_until=0;p.cooldown=game.now;p.burst_left=0;p.clear_local_input();p.suppressed_actions.clear()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 check(game.arena.map_selection==0,"Fresh project begins on Sanctuary")
 check(game.screen.find_child("SanctuaryMenuArtwork",true,false)!=null,"Main menu uses supplied Sanctuary artwork")
 var original_tick=int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
 check(original_tick==60,"Multiplayer physics remains fixed at 60 Hz")
 var stats=game.arena.get_meta("sanctuary_polish",{})
 print("SANCTUARY CLEANUP ",JSON.stringify(stats))
 check(int(stats.get("labels_hidden",0))>10,"Floating development-style route labels are removed")
 check(game.arena.kit.restrained_architecture,"Sanctuary uses reduced repetitive surface trim")
 for id in ["falcon_smg","viper_pulse_smg","plasma_sniper"]:
  var d=NestWeaponCatalog.definition(id);var profile=NestWeaponCatalog.profile(id)
  check(not d.is_empty() and profile.kind==d.kind,"Registry, loadout and runtime agree for "+id)
  check(NestWeaponCatalog.choices("primary").any(func(w):return w.id==id),"New weapon selectable as primary: "+id)
  check(NestWeaponCatalog.choices("secondary").any(func(w):return w.id==id),"New weapon selectable as secondary: "+id)
  check(not profile.shot_sounds.is_empty() and profile.reload_sound!=null,"Existing compatible sound/reload assets resolve: "+id)
  var model=NestWeaponArt.create(profile.kind,0);check(model.find_children("*","MeshInstance3D",true,false).size()>=3,"New 3D weapon geometry exists: "+id);model.free()
 check(NestWeaponCatalog.for_kind("plasma_br").burst_count==3,"Triad carbine uses exactly three rounds per burst")
 check(NestWeaponCatalog.profile("sniper").spread_half_angle_deg==0 and NestWeaponCatalog.profile("plasma_sniper").spread_half_angle_deg==0,"Sniper variants retain zero cone spread")
 check(NestWeaponCatalog.profile("smg").speed==0 and NestWeaponCatalog.profile("plasma_smg").speed>0,"Conventional SMG is hitscan; energy SMG is swept projectile")
 game.show_play_menu();check(game.current_screen=="play","Play menu opens actual game actions")
 game.show_armory();await process_frame;game.armory_select("plasma_smg")
 check(game.armory_info.text.contains("Viper Pulse SMG"),"Armory previews the selected live weapon")
 game.armory_select("knife");check(game.armory_info.text.contains("Talon Knife"),"Talon combat knife is represented in the armory")
 game.show_main();check(game.current_screen=="main","New screens can return to main menu")
 game.bot_fill=false;game.mode=1;game.selected_faction=0;game.fair_playing_field=false;game.clear_screen();game.start_game();game.set_physics_process(false)
 var p: NestActor=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(600,80,600);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim()
 var target=NestActor.new();target.game=game;target.faction=1;game.add_child(target);game.actors.append(target);target.set_character(1);target.respawn();target.set_physics_process(false);target.set_process(false);target.position=Vector3(600,80,590);target.update_visual(0)
 await physics_frame
 check(target.health==100 and target.shield==0 and target.armor==100,"Annu keeps health/armor without default shields")
 p.set_character(0);p.respawn();p.set_physics_process(false);p.position=Vector3(600,80,600)
 check(p.health==100 and p.shield==100,"Naki keeps rechargeable shield and hidden health")
 # Independent expected torso damage for the new conventional SMG: 14, half absorbed.
 target.last_damage=-INF;target.take_damage(14,"torso","bullet",false,p,game.next_event()*16,Vector3.INF,"smg",0)
 check(is_equal_approx(target.health,93) and is_equal_approx(target.armor,93),"Falcon body hit uses 14 damage through Annu's 50% armor absorption")
 var event=game.next_event()*16;target.take_damage(14,"torso","bullet",false,p,event,Vector3.INF,"smg",0);var hp=target.health;target.take_damage(14,"torso","bullet",false,p,event,Vector3.INF,"smg",0)
 check(target.health==hp,"Duplicate new-weapon damage event is rejected")
 var wall=StaticBody3D.new();wall.position=Vector3(600,81,595);var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,5,.3);shape.shape=box;wall.add_child(shape);game.add_child(wall);await physics_frame
 for kind in ["smg","plasma_smg","plasma_sniper"]:
  target.respawn();target.set_physics_process(false);target.position=Vector3(600,80,590);target.update_visual(0);await physics_frame
  equip(p,kind);var profile=p.weapons[0];var start=Vector3(600,81.1,600);var health=target.health
  game.launch_bullet(p,profile,start,Vector3.FORWARD,0,false,game.next_event()*16)
  for i in range(55):await physics_frame
  check(target.health==health,"Solid wall blocks new weapon: "+kind)
 wall.queue_free();await physics_frame;await physics_frame
 for kind in ["smg","plasma_smg","plasma_sniper"]:
  target.respawn();target.set_physics_process(false);target.position=Vector3(600,80,590);target.update_visual(0);await physics_frame
  equip(p,kind);var profile=p.weapons[0];var start=Vector3(600,81.1,600);var hp_before=target.health
  game.launch_bullet(p,profile,start,Vector3.FORWARD,0,false,game.next_event()*16)
  for i in range(55):await physics_frame
  check(target.health<hp_before,"Unobstructed new weapon registers actual hit: "+kind)
  p.ammo[0]=0;p.action_state="ready";p.cooldown=game.now
  var fired_before=p.accepted_shots;p.fire_trigger()
  check(p.ammo[0]==0 and p.accepted_shots==fired_before,"Empty weapon cannot fire or create negative ammo: "+kind)
  p.reload_weapon();game.now=p.action_until;p.advance_weapon_timers()
  check(p.ammo[0]==profile.magazine,"Reload transfers full magazine at simulation deadline: "+kind)
 for team in game.arena.spawns.values():
  for spawn in team:
   var query=PhysicsShapeQueryParameters3D.new();var cap=CapsuleShape3D.new();cap.height=NestActor.STAND_HEIGHT;cap.radius=NestActor.BODY_RADIUS;query.shape=cap;query.transform=Transform3D(Basis.IDENTITY,spawn+Vector3.UP*NestActor.STAND_CENTER);query.collision_mask=1
   check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Standing capsule clear at Sanctuary spawn "+str(spawn))
 game.stop_game();game.queue_free();for i in range(5):await process_frame
 print("REFERENCE UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
