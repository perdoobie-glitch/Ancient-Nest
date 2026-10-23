extends SceneTree
var game
var checks=0
var failures=0
var target: NestActor
var shooter: NestActor
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: ",message)
 else:failures+=1;push_error("FAIL: "+message)
func reset(character: int):
 target.set_character(character);target.respawn();target.set_physics_process(false);target.set_process(false)
 target.health=100000;target.shield=0;target.overshield=0;target.armor=0;target.helmet_hp=0
func hit(kind: String,region: String,distance: float=0):
 var before=target.health+target.shield+target.overshield+target.armor+target.helmet_hp
 target.take_damage(98765,region,"bullet",true,shooter,game.next_event()*16,Vector3.INF,kind,distance)
 return before-target.health-target.shield-target.overshield-target.armor-target.helmet_hp
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.lobby_network.set_process(false);game.lobby_network=null
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.clear_screen();game.start_game();game.set_physics_process(false)
 shooter=game.player;shooter.set_physics_process(false);shooter.set_process(false);shooter.position=Vector3(600,80,600)
 target=NestActor.new();target.game=game;target.faction=1;game.add_child(target);game.actors.append(target);target.position=Vector3(600,80,590)
 for entry in NestWeaponCatalog.data().weapons:
  var config=NestWeaponCatalog.definition(entry.id)
  if config.get("explosive",false) or config.kind in ["frag_grenade","plasma_grenade"]:continue
  var base=float(config.get("damage_body",config.damage))
  check(float(config.head_multiplier)==2 and float(config.body_hit_multiplier)==1,entry.title+" exposes 1x/2x data")
  for character in [0,1]:
   reset(character);check(absf(hit(config.kind,"torso")-base)<.02,entry.title+" body = base vs "+str(character))
   reset(character);check(absf(hit(config.kind,"head")-base*2)<.02,entry.title+" head = 2x vs "+str(character))
   reset(character)
   if character==0:target.shield=10000
   else:target.armor=10000
   check(absf(hit(config.kind,"torso")-base)<.02,entry.title+" body energy conserved through defense "+str(character))
   reset(character)
   if character==0:target.shield=10000
   else:target.helmet_hp=10000
   check(absf(hit(config.kind,"head")-base*2)<.02,entry.title+" head energy conserved through defense "+str(character))
  reset(0);target.shield=5;target.overshield=3
  check(absf(hit(config.kind,"head")-base*2)<.02,entry.title+" excess head damage crosses both shields")
  reset(0);var end=float(config.falloff_end_m);var factor=game.weapon_falloff(config,end)
  check(absf(hit(config.kind,"head",end)-base*factor*2)<.02,entry.title+" falloff applied once to head")
  reset(0);check(hit(config.kind,"head",float(config.max_effective_range_m)+1)==0,entry.title+" out-of-range hit does no damage")
 reset(0);target.health=100;var plasma=NestWeaponCatalog.for_kind("plasma_smg");hit("plasma_smg","head")
 check(target.alive and is_equal_approx(target.health,100-float(plasma.damage_body)*2),"Exposed Naki head does not trigger hidden instant kill")
 reset(1);target.health=100;hit("plasma_smg","head");hit("plasma_smg","head")
 check(target.alive,"No fixed two-plasma-headshots kill exception")
 reset(1);var upper=hit("sniper","torso");reset(1);var lower=hit("sniper","leg")
 check(is_equal_approx(upper,lower),"Sniper legs and torso use same body multiplier")
 reset(0);game.game_type.weapon_damage_percent["smg"]=50.0
 check(absf(hit("smg","head")-14)<.02,"Explicit weapon damage override applies once after 2x head")
 game.game_type.weapon_damage_percent.clear()
 reset(0);var id=game.next_event()*16;target.take_damage(14,"torso","bullet",false,shooter,id,Vector3.INF,"smg",0);var hp=target.health
 target.take_damage(14,"torso","bullet",false,shooter,id,Vector3.INF,"smg",0)
 check(target.health==hp,"Duplicate hit still rejected")
 check(game.game_type.naki_body_shield_strength==1 and game.game_type.naki_head_shield_strength==1,"Default shield strengths are neutral")
 var legacy=GameTypeSettings.new();legacy.naki_body_shield_strength=1.7;legacy.naki_head_shield_strength=1.35;legacy.validate()
 check(legacy.naki_body_shield_strength==1 and legacy.naki_head_shield_strength==1,"Historical saved default shield factors migrate once")
 legacy.naki_body_shield_strength=1.7;legacy.validate()
 check(legacy.naki_body_shield_strength==1.7,"Explicit post-migration trait editing remains supported")
 var custom=GameTypeSettings.new();custom.naki_body_shield_strength=2.5;custom.validate()
 check(custom.naki_body_shield_strength==2.5,"Migration preserves distinct custom shield strength")
 game.stop_game();game.queue_free();await process_frame;await process_frame
 print("POLISHED DAMAGE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
