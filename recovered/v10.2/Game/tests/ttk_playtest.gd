extends SceneTree
# Controlled landed-hit trials: actual weapon triggers, burst/reload state and damage layers.
# Aim/spread is intentionally bypassed here; separate ray tests measure spread.
class ControlledGame extends "res://scripts/main.gd":
 var target
 var test_region="torso"
 var test_distance=3.
 var include_flight=false
 var incoming=[]
 var shot_times=[]
 var kill_at=-1.
 var landed=0
 func launch_bullet(actor: NestActor,weapon: NestWeapon,_pos: Vector3,_direction: Vector3,pellet: int,_cosmetic: bool=false,event: int=0,_first: bool=true) -> void:
  if pellet==0:shot_times.append(now)
  incoming.append({"at":now+(test_distance/weapon.speed if include_flight and weapon.speed>0 else 0.),"weapon":weapon,"event":event,"actor":actor})
 func deliver():
  var remaining=[]
  for hit in incoming:
   if hit.at>now+.000001:remaining.append(hit);continue
   if not target.alive:continue
   var weapon=hit.weapon;landed+=1
   var damage=float(NestWeaponCatalog.for_kind(weapon.kind).get("damage_direct",weapon.damage)) if weapon.explosive else weapon.damage
   target.take_damage(damage,"torso" if weapon.explosive else test_region,"heavy" if weapon.explosive else "bullet",weapon.precision,hit.actor,hit.event,Vector3.INF,weapon.kind,test_distance)
   if not target.alive:kill_at=now
  incoming=remaining
var game
var shooter
var victim
var results=[]
func _initialize():call_deferred("run")
func reset_target(character: int):
 if victim.character!=character:victim.set_character(character)
 victim.refresh_traits();victim.alive=true;victim.life_id+=1;victim.health=victim.tuning.health_capacity;victim.shield=victim.tuning.shield_capacity if victim.damage_model()=="naki" else 0.;victim.armor=victim.tuning.armor_capacity;victim.helmet_hp=game.game_type.annu_head_armor;victim.overshield=0.;victim.last_damage=-INF;victim.regen_anchor_damage=-INF;victim.body_phase=false;victim.hit_stun_until=0;victim.action_state="ready"
func trial(definition: Dictionary,character: int,region: String,distance: float,flight: bool):
 game.now=100.;game.break_until=0;game.finished=false;game.incoming=[];game.shot_times=[];game.kill_at=-1.;game.landed=0;game.test_region=region;game.test_distance=distance;game.include_flight=flight;game.damage_events.clear()
 reset_target(character)
 var weapon=NestWeaponCatalog.profile(definition.id)
 shooter.weapons.clear();shooter.weapons.append(weapon);shooter.ammo.clear();shooter.ammo.append(weapon.magazine);shooter.reserve.clear();shooter.reserve.append(weapon.reserve);shooter.slot=0;shooter.action_state="ready";shooter.cooldown=0;shooter.burst_left=0;shooter.last_shot_frame=-1;shooter.auto_reload_at=INF;shooter.hit_stun_until=0;shooter.fire_pending_until=-INF;shooter.alive=true;shooter.health=10000;shooter.update_weapon_art();shooter.reset_aim()
 var first=-1.;var reloads=0;var last_action="ready"
 for tick in range(1801):
  game.now=100.+tick/60.
  shooter._physics_process(1./60.)
  shooter.fire_trigger()
  if first<0 and not game.shot_times.is_empty():first=game.shot_times[0]
  if shooter.action_state=="reloading" and last_action!="reloading":reloads+=1
  last_action=shooter.action_state
  if victim.damage_model()=="naki":victim.update_regeneration()
  game.deliver()
  if not victim.alive:break
  if game.weapon_falloff(definition,distance)<=0 and not weapon.explosive:break
  await process_frame
 var ttl=game.kill_at-first if game.kill_at>=0 and first>=0 else -1.
 var row={"id":definition.id,"name":definition.title,"faction":"Naki" if character==0 else "Annu","zone":"head" if region=="head" else "body","distance":distance,"projectile_flight_included":flight,"kill_seconds":snappedf(ttl,.000001),"shots_fired":game.shot_times.size(),"hits_landed":game.landed,"reloads":reloads,"fired_at":game.shot_times.map(func(t):return snappedf(t-first,.000001))}
 results.append(row)
 print("TRIAL ",JSON.stringify(row))
 for node in game.corpses.get_children():node.queue_free()
 for node in game.effects.get_children():node.queue_free()
 game.incoming.clear();await process_frame
func run():
 Engine.max_fps=0
 game=ControlledGame.new();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(1);rules.bots_fill_empty_slots=false;rules.score_to_win=100000;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false);game.context="pause"
 for actor in game.actors:actor.set_physics_process(false)
 shooter=game.player;shooter.set_character(1);shooter.refresh_traits();shooter.set_physics_process(false)
 shooter.position=Vector3(500,20.05,500)
 var floor=StaticBody3D.new();var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(30,1,30);collider.shape=shape;floor.add_child(collider);game.add_child(floor);floor.position=Vector3(500,19.5,500)
 victim=NestActor.new();victim.game=game;victim.faction=1;victim.character_choice=0;victim.username="TTK target";victim.net_id=909;victim.local_player=false;game.add_child(victim);game.actors.append(victim);victim.set_physics_process(false);victim.position=Vector3(505,20,500);game.target=victim
 await physics_frame
 for distance in [3.,10.,50.]:
  for definition in NestWeaponCatalog.data().weapons:
   if definition.get("slot","")=="grenade":continue
   for character in [0,1]:
    for region in ["torso","head"]:await trial(definition,character,region,distance,distance>3.)
 FileAccess.open("user://ttk-playtest.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 print("PASS: ",results.size()," controlled firing/damage trials")
 game.stop_game();game.queue_free();await create_timer(.2).timeout;quit()
