extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var e=NestActor.new();e.game=game;e.faction=1;game.add_child(e);game.actors.append(e);e.set_physics_process(false);e.set_process(false);game.fair_playing_field=true;game.fair_health_type="annu"
 for kind in ["burst","burst_scoped"]:
  var c=NestWeaponCatalog.for_kind(kind);check(c.burst_count==3 and c.burst_rounds==3,kind+" is a three-round burst")
  e.respawn();e.set_physics_process(false)
  for hit in range(3):
   e.take_damage(30,"head","bullet",true,p,game.next_event()*16,Vector3.ZERO,kind)
   check(e.alive if hit<2 else not e.alive,kind+" Annu head hit "+str(hit+1)+" has expected survival")
  e.respawn();e.set_physics_process(false)
  for hit in range(3):e.take_damage(30,"torso","bullet",true,p,game.next_event()*16,Vector3.ZERO,kind)
  check(e.alive and e.shield==0 and e.armor>0,kind+" full body burst meets durable armour without faction shield")
  p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.ammo.assign([36]);p.reserve.assign([144]);p.slot=0;p.action_state="ready";p.action_until=0;p.cooldown=0;p.burst_left=0;p.last_shot_frame=-1;game.now+=2
  p.fire_trigger()
  for i in range(15):game.now+=1.0/60;p._physics_process(1.0/60);await process_frame
  check(p.ammo[0]==33 and p.burst_left==0,kind+" actual trigger consumes exactly three rounds")
 check(float(game.damage_rules.helmet_hp_max)==25 and float(game.damage_rules.helmet_absorb_percent)==15,"Annu helmet is weaker than body armour")
 check(float(game.damage_rules.armor_max)==100 and float(game.damage_rules.armor_absorb_percent)==50,"Existing strong body armour preserved")
 for kind in ["burst","burst_scoped"]:
  var c=NestWeaponCatalog.for_kind(kind);check(is_equal_approx(float(c.spread_half_angle_deg),.1125*1.25) and is_equal_approx(float(c.spread_scoped_deg),.140625) and is_equal_approx(NestWeaponCatalog.profile(kind).spread_half_angle_deg,.140625),kind+" hip/scoped burst spread widened 25 percent")
 var sg=NestWeaponCatalog.for_kind("shotgun");check(is_equal_approx(float(sg.spread_half_angle_deg),3.75*1.25) and is_equal_approx(NestWeaponCatalog.profile("shotgun").spread_half_angle_deg,4.6875),"Shotgun imported and runtime spread widened 25 percent")
 for model in ["naki","annu"]:
  game.fair_health_type=model;e.respawn();e.set_physics_process(false)
  var index=game.arena.pad_kinds.find("overshield");game.pad_stock[index]=1;game.take_pickup(e,index)
  check(e.overshield==100 and is_equal_approx(e.over_deadline-game.now,60),model+" pickup gives a separate 100-point layer for 60 seconds")
  var health=e.health;var shield=e.shield;var armour=e.armor
  e.take_damage(18,"torso","bullet",false,p,game.next_event()*16,Vector3.ZERO,"rifle")
  check(e.overshield<100 and e.health==health and e.shield==shield and e.armor==armour,model+" bonus layer absorbs damage before base protection")
  var expiry=e.over_deadline;game.now=expiry-.001;e._physics_process(0)
  check(e.overshield>0,model+" second shield remains before one minute")
  game.now=expiry;e._physics_process(0);check(e.overshield==0,model+" bonus layer expires exactly at one minute")
 game.fair_health_type="naki";e.respawn();e.set_physics_process(false);e.cloak_deadline=game.now+60;e.refresh_model_visibility()
 check(e.model.visible and e.cloak_meshes.size()>0,"Cloak keeps animated body available to shadow renderer")
 check(e.cloak_meshes.all(func(m):return m.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),"Cloaked meshes use shadow-only rendering")
 e.weapons.assign([NestWeaponCatalog.profile("plasma_auto")]);e.slot=0;e.art_kind="";e.update_weapon_art();await process_frame
 check(e.cloak_meshes.all(func(m):return not is_instance_valid(m) or m.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),"Switching weapons while cloaked does not expose new art")
 e.update_enemy_name_tag(.1);check(not e.enemy_name_tag.visible,"Cloak does not reveal an enemy name label")
 e.cloak_deadline=0;e.refresh_model_visibility();var restored=true
 for i in range(e.cloak_meshes.size()):
  if is_instance_valid(e.cloak_meshes[i]):restored=restored and e.cloak_meshes[i].cast_shadow==e.cloak_shadow_modes[i]
 check(restored,"Normal shadow modes restored after camo expires")
 e.cloak_deadline=game.now+60;e.refresh_model_visibility();e.alive=false;e.refresh_model_visibility();check(not e.model.visible,"Dead camouflaged body stops casting living-player shadow")
 p.overshield=100;p.over_deadline=game.now+60;game.create_hud();game._process(.016)
 check(game.hud_over.visible and game.hud_over.value==100 and game.hud_protection.text.contains("1:00"),"Second shield has its own HUD meter and one-minute countdown")
 print("V19.3 RULES: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
