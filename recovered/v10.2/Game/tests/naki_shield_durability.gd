extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func hit(target,attacker,kind,region,category="bullet",raw=60.0):
 return target.take_damage(raw,region,category,true,attacker,attacker.game.next_event()*16,Vector3.ZERO,kind)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var e=NestActor.new();e.game=game;e.faction=1;game.add_child(e);game.actors.append(e);e.set_physics_process(false);e.set_process(false)
 game.fair_playing_field=true;game.fair_health_type="naki"
 for kind in ["rifle","ak47","burst","burst_scoped","sidearm","shotgun","plasma_br","plasma_auto"]:
  var config=NestWeaponCatalog.for_kind(kind)
  for region in ["torso","head"]:
   e.respawn();e.set_physics_process(false)
   var amount=float(config.damage_shield)
   if region!="head":amount*=float(config.get("body_hit_multiplier",1.0))
   elif int(config.get("plasma_headshots_to_kill",0))>0:amount=(e.health+e.shield)/float(config.plasma_headshots_to_kill)
   var strength=1.35 if region=="head" else 1.7
   var start=e.shield
   hit(e,p,kind,region)
   check(is_equal_approx(e.shield,start-amount/strength),kind+" "+region+" correct shield durability")
   check(e.health==e.tuning.health_capacity,kind+" "+region+" shield absorbs without health damage")
 e.respawn();var id=game.next_event()*16;e.take_damage(20,"torso","bullet",false,p,id,Vector3.ZERO,"rifle");var once=e.shield;e.take_damage(20,"torso","bullet",false,p,id,Vector3.ZERO,"rifle")
 check(e.shield==once,"Duplicate damage event is not applied twice")
 for region in ["torso","head"]:
  e.respawn();e.overshield=100;var base=e.shield;var health=e.health
  hit(e,p,"rifle",region)
  check(is_equal_approx(e.overshield,100-float(NestWeaponCatalog.for_kind("rifle").damage_shield)/(1.35 if region=="head" else 1.7)),region+" Naki overshield gets same durability")
  check(e.shield==base and e.health==health,region+" bonus layer does not leak into base shield")
 e.respawn();e.overshield=1;var amount=float(NestWeaponCatalog.for_kind("rifle").damage_shield)
 hit(e,p,"rifle","torso")
 check(e.overshield==0 and is_equal_approx(e.shield,100-(amount-1.7)/1.7),"Overshield spill spends raw damage once across both layers")
 e.respawn();e.shield=1;var precision_damage=(100.0+e.tuning.shield_capacity)/3.0
 hit(e,p,"plasma_br","head")
 check(e.shield==0 and is_equal_approx(e.health,100-(precision_damage-1.35)),"Precision shield spill preserves unshielded health damage")
 e.respawn();e.shield=0;hit(e,p,"rifle","torso")
 check(is_equal_approx(e.health,100-float(NestWeaponCatalog.for_kind("rifle").damage_body)/3.0),"Shieldless body bullet resistance unchanged")
 e.respawn();e.shield=0;hit(e,p,"rifle","head")
 check(not e.alive,"Shieldless headshot still finishes Naki")
 e.respawn();hit(e,p,"sniper","head")
 check(not e.alive,"Existing sniper instant-headshot exception preserved")
 for category in ["melee","explosion","heavy"]:
  e.respawn();hit(e,p,"","torso",category,60)
  check(is_equal_approx(e.shield,40),category+" shield damage unchanged")
 for kind in ["plasma_br","plasma_auto"]:
  e.respawn()
  for i in range(4):
   hit(e,p,kind,"head")
   check(e.alive if i<3 else not e.alive,kind+" shield-adjusted headshot survival "+str(i+1))
  game.fair_health_type="annu";e.respawn();hit(e,p,kind,"head")
  check(e.health==50 and e.shield==0,kind+" Annu first headshot unchanged")
  hit(e,p,kind,"head");check(not e.alive,kind+" Annu two headshots unchanged")
  game.fair_health_type="naki"
 game.fair_health_type="annu";e.respawn();e.overshield=100;hit(e,p,"rifle","torso")
 check(is_equal_approx(e.overshield,100-float(NestWeaponCatalog.for_kind("rifle").damage_shield)),"Annu overshield unchanged")
 game.fair_health_type="naki";e.respawn();hit(e,p,"rifle","torso");e.shield=0;var time=game.now
 game.now=time+4.99;e._physics_process(0);check(e.shield==0,"Naki shield recharge still waits five seconds")
 game.now=time+5.0;e._physics_process(1.5);check(is_equal_approx(e.shield,e.tuning.shield_capacity/2),"Shield recharge halfway after 1.5 seconds")
 e._physics_process(1.5);check(is_equal_approx(e.shield,e.tuning.shield_capacity),"Shield recharge full after three seconds")
 print("NAKI SHIELD DURABILITY: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
