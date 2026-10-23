extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func wall(pos: Vector3) -> StaticBody3D:
 var body=StaticBody3D.new();body.collision_layer=1
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(5,6,.12);collision.shape=shape;body.add_child(collision);game.add_child(body);body.position=pos;return body
func place(actor: NestActor,pos: Vector3):
 actor.set_physics_process(false);actor.set_process(false);actor.position=pos;actor.rotation=Vector3.ZERO;actor.eye.rotation=Vector3.ZERO;actor.reset_physics_interpolation();actor.reset_aim();actor.update_visual(0)
func bullet(owner: NestActor, start: Vector3, end: Vector3):
 var shot=load("res://scripts/bullet.gd").new();shot.game=game;shot.owner_actor=owner;shot.profile=NestWeaponCatalog.profile("sniper");shot.direction=(end-start).normalized();shot.excludes=owner.ray_exclusions();shot.event_id=game.next_event()*16;shot.round_id=game.round_number;shot.position=start;game.effects.add_child(shot);shot.resolve_hit(start,end);return shot
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=2;rules.bots_fill_empty_slots=true;rules.bots_stand_still=true;rules.bots_dont_shoot=true;rules.bullet_impact_debug=true;rules.starting_primary="sniper_rifle";game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.set_physics_process(false);await frames()
 for i in range(game.actors.size()):place(game.actors[i],Vector3(900+i*10,100,900))
 var p=game.player
 check(p.character==0 and p.weapons.size()==3 and p.weapons[2].kind=="plasma_sword","Only Naki receives the green sword in its loadout")
 var annu=game.actors.filter(func(a):return a.character==1)[0]
 check(not annu.weapons.any(func(w):return w.kind=="plasma_sword"),"Annu cannot acquire a default sword")
 check(p.belt_sword!=null and annu.perched_nu!=null,"Naki belt sword and Annu perched falcon attach to the rig")
 var green_trim=false
 for mesh in p.model.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var m=mesh.get_active_material(surface)
   if m is StandardMaterial3D and "trim" in m.resource_name:green_trim=green_trim or m.albedo_color.g>m.albedo_color.r
 check(green_trim,"Naki trim is green instead of yellow/brass")
 var pistol=NestWeaponArt.create("plasma_pistol",0)
 check(pistol.name=="NakiPlasmaPistol" and NestWeaponCatalog.profile("plasma_pistol").plasma,"Green reference-style plasma pistol has its own artwork and projectile profile");pistol.free()
 p.accuracy_penalty=100;p.traits.settings.spread_percent=300
 check(p.current_spread_degrees()==0,"Sniper stays zero-spread with extreme bloom and custom spread")
 check(NestReticle.SNIPER_RING_SCALE==.225,"Sniper ring is half the previous scale")
 var intent=annu.bot_intent(.016)
 check(intent.move==Vector2.ZERO and not intent.jump,"Stationary bot toggle prevents movement and jumps")
 var ammo_before=annu.ammo.duplicate();game.now+=3;annu.bot_intent(.1)
 check(annu.ammo==ammo_before,"No-shoot bot toggle preserves ammunition")
 # Two aligned enemies, with an independent body behind a solid wall.
 var a=annu;var b=game.actors.filter(func(n):return n!=p and n!=a)[0];b.faction=1
 place(p,Vector3(900,100,900));place(a,Vector3(900,100,895));place(b,Vector3(900,100,890))
 var start=Vector3(900,100+NestActor.EYE_HEIGHT,900);var finish=start+Vector3.FORWARD*25
 await physics_frame;await physics_frame
 var hp_a=a.health+a.shield;var hp_b=b.health+b.shield
 var shot=bullet(p,start,finish)
 check(a.health+a.shield<hp_a and b.health+b.shield<hp_b,"One sniper ray damages two lined-up distinct players")
 check(shot.penetration_count==2,"Anatomy hulls cannot multiply damage within one target")
 check(game.effects.get_children().filter(func(n):return n is NestImpactDebug).size()==1,"Only the first contact gets a tiny red debug block")
 shot.queue_free();a.respawn();b.respawn();place(a,Vector3(900,100,895));place(b,Vector3(900,100,890));var barrier=wall(Vector3(900,102,892.5));await physics_frame;await physics_frame
 hp_b=b.health+b.shield;shot=bullet(p,start,finish)
 check(b.health+b.shield==hp_b,"Sniper penetration stops at cover before the next player")
 shot.queue_free();barrier.queue_free();await physics_frame
 # F draws for .6 s, then slices .7 s, and cannot damage through walls.
 a.respawn();place(a,p.position+Vector3.FORWARD*1.4);p.action_state="ready";p.cooldown=0;p.slot=0;game.now+=2;p.melee()
 check(is_equal_approx(p.sword_draw,.6/1.15) and is_equal_approx(p.action_until-game.now,1.3/1.15),"Unwielded sword uses fifteen percent faster draw and slice")
 var life=a.life_id;var health=a.health;game.now=p.melee_contact_at-.01;p.advance_melee_contact()
 check(a.health==health and a.alive,"Sword cannot hit before its contact phase")
 game.now=p.melee_contact_at+.001;p.advance_melee_contact()
 check(not a.alive and a.life_id==life,"Sword contact kills its legal target")
 a.set_character(0);a.respawn();place(a,p.position+Vector3.FORWARD*1.4);a.faction=1;p.action_state="ready";p.cooldown=0;p.melee();game.now=p.melee_contact_at+.001;p.advance_melee_contact()
 check(not a.alive and a.shield==0,"Sword kills a fully shielded Naki with one legal contact")
 p.action_state="ready";p.cooldown=0;p.wield_sword();game.now=p.action_until+.001;p.advance_weapon_timers();p.melee()
 check(p.weapons[p.slot].kind=="plasma_sword" and p.sword_draw==0 and is_equal_approx(p.action_until-game.now,.7/1.15),"Wielded sword starts the faster slice without drawing again")
 p.action_state="ready";p.cooldown=0;game.nu.toggle(p)
 check(not p.nu_used and not game.nu.birds.has(p.net_id),"Naki cannot deploy Nu")
 a.set_character(1);a.respawn();place(a,Vector3(930,110,930));a.action_state="ready";a.cooldown=0;game.nu.toggle(a)
 check(a.nu_used and a.action_state=="nu_launch" and is_equal_approx(a.nu_launch_until-game.now,1.5),"Annu launch is one use per life and lasts 1.5 seconds")
 game.now=a.nu_launch_until-.01;game.nu._physics_process(.016)
 check(not game.nu.birds.has(a.net_id),"Nu is not released before the launch animation finishes")
 game.now=a.nu_launch_until+.001;game.nu._physics_process(.016)
 check(game.nu.birds.has(a.net_id),"Nu launches after 1.5 seconds")
 var bird=game.nu.birds.get(a.net_id)
 if bird!=null:
  bird.set_physics_process(false)
  check(bird.visual!=null and NestFalconArt.WINGSPAN==1.05,"Nu uses falcon-scale body and articulated wings")
  check(NestNuFalcon.step_velocity(Vector3.ZERO,0,0,Vector3.ZERO,.1).y<0,"Nu falls without sufficient speed or flapping")
  check(NestNuFalcon.step_velocity(Vector3.FORWARD*10,0,0,Vector3(1,0,1),.1).y>NestNuFalcon.step_velocity(Vector3.FORWARD*10,0,0,Vector3.ZERO,.1).y,"Flapping increases lift under the flight simulation")
  check(game.nu.blocked(a),"Controlling Nu locks body movement/combat while leaving its hitboxes active")
  var body=a.position;a.controlled=Vector3.ZERO;a.external=Vector3.ZERO;a.movement_step(Vector2(1,-1),true,0,0,1.0/60)
  check(Vector2(a.position.x-body.x,a.position.z-body.z).length()<.001,"Flight controls cannot move or jump the owner's body")
  check(not a.fire_trigger() and game.interaction_for(a).is_empty(),"Nu cannot fire body weapons or perform objectives")
  # Spot a target in open air, then insert cover.
  place(p,bird.position+Vector3.FORWARD*8-Vector3.UP*NestActor.EYE_HEIGHT);p.faction=0;a.faction=1;bird.yaw=0;bird.pitch=0;await physics_frame
  bird.update_spots();check(p.net_id in bird.spots,"Nu spots a visible enemy ahead")
  check(p.net_id in game.nu.visible_enemy_ids(a) and p.net_id not in game.nu.visible_enemy_ids(p),"Nu sightings are restricted to its owning team")
  barrier=wall(bird.position+Vector3.FORWARD*4);await physics_frame;await physics_frame;bird.update_spots()
  check(p.net_id not in bird.spots,"Walls immediately prevent new Nu enemy spotting")
  barrier.queue_free();await physics_frame
  var query=game.trace(bird.position+Vector3.BACK*2,bird.position+Vector3.FORWARD*2,8)
  check(not query.is_empty() and query.collider.has_meta("nu"),"Nu has a bullet-query hurtbox")
  bird.destroy("shot")
  check(not game.nu.birds.has(a.net_id) and a.alive and not game.nu.blocked(a),"Shot-down Nu disappears and unlocks its living owner")
  game.nu.toggle(a);check(not game.nu.birds.has(a.net_id) and a.action_state!="nu_launch","Nu cannot be launched twice in the same life")
 a.respawn();check(not a.nu_used,"Respawn restores one Nu use")
 place(a,Vector3(110,70,110));a.action_state="ready";a.cooldown=0;game.nu.toggle(a);game.now=a.nu_launch_until+.001;game.nu._physics_process(.016)
 bird=game.nu.birds.get(a.net_id)
 if bird!=null:
  bird.set_physics_process(false);bird.velocity=Vector3.FORWARD*20
  barrier=wall(bird.position+Vector3.FORWARD*.5);await physics_frame;await physics_frame
  bird._physics_process(1.0/60)
  check(not game.nu.birds.has(a.net_id),"Swept falcon volume dies against nearby structure during flight")
  barrier.queue_free();await physics_frame
 a.respawn();place(a,Vector3(110,70,110));a.action_state="ready";a.cooldown=0;game.nu.toggle(a);game.now=a.nu_launch_until+.001;game.nu._physics_process(.016)
 check(game.nu.birds.has(a.net_id),"A fresh life can deploy another Nu")
 a.die(p,"test")
 check(not game.nu.birds.has(a.net_id),"Owner death removes Nu and its spotting immediately")
 a.respawn();a.action_state="ready";a.cooldown=0
 game.game_type.nu_enabled=false;game.nu.toggle(a);check(not a.nu_used and not game.nu.birds.has(a.net_id),"Host Nu toggle prevents deployment")
 # One themed tabbed editor holds all match rules and test controls.
 game.context="pause";game.open_game_type_settings();await frames()
 var editor=game.game_type_editor
 check(editor!=null and editor.controls.has("bots_stand_still") and editor.controls.has("bots_dont_shoot") and editor.controls.has("bullet_impact_debug") and editor.controls.has("nu_enabled"),"Unified settings contains bot testing, impact markers and Nu controls")
 check(editor.tabs.get_tab_count()>5 and editor.weapon_controls.size()>5 and editor.find_child("ApplyMatchRestart",true,false)!=null,"The same menu contains weapon damage tabs and Apply & Restart")
 editor.hide();editor.queue_free();game.stop_game();game.queue_free();await frames(8)
 print("V30 FEATURES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
