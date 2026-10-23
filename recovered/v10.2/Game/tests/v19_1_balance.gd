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
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false);game.context="playing"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var enemy=NestActor.new();enemy.game=game;enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.set_physics_process(false);enemy.set_process(false)
 game.fair_playing_field=true
 for kind in ["plasma_br","plasma_auto"]:
  var c=NestWeaponCatalog.for_kind(kind);var w=NestWeaponCatalog.profile(kind)
  check(is_equal_approx(w.speed,30.0 if kind=="plasma_br" else 22.5),kind+" travels at one-quarter previous speed")
  check(is_equal_approx(float(c.damage_body),19.125 if kind=="plasma_br" else 5.1) and is_equal_approx(float(c.damage_shield),12.75 if kind=="plasma_br" else 4.08),kind+" current plasma body and shield damage matches the v20 update2 nerf")
  check(w.max_range/w.speed<6.0,kind+" still reaches full configured range within existing lifetime")
  for model in ["naki","annu"]:
   game.fair_health_type=model;enemy.respawn();enemy.set_physics_process(false)
   var before=enemy.health+enemy.shield
   var id=game.next_event()*16
   enemy.take_damage(w.damage,"head","bullet",w.precision,p,id,Vector3.ZERO,kind)
   check(enemy.alive and is_equal_approx(enemy.health+enemy.shield,(before*.5 if model=="annu" else before-(before/3.0)/1.35)),kind+" "+model+" survives first head impact with expected remaining pool")
   var after=enemy.health+enemy.shield
   enemy.take_damage(w.damage,"head","bullet",w.precision,p,id,Vector3.ZERO,kind)
   check(is_equal_approx(enemy.health+enemy.shield,after),kind+" duplicate head event cannot count twice")
   enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
   if model=="naki":
    check(enemy.alive,kind+" Naki survives second distinct head impact")
    enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
    check(enemy.alive,kind+" stronger Naki head shields preserve third-hit survival")
    enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
   check(not enemy.alive,kind+" "+model+" dies on current shield-adjusted final head impact")
   enemy.respawn();enemy.set_physics_process(false);before=enemy.shield if model=="naki" else enemy.health
   enemy.take_damage(w.damage,"torso","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
   check(enemy.alive,kind+" "+model+" body hit retains normal protection rules")
  game.fair_health_type="naki";enemy.respawn();enemy.overshield=enemy.tuning.shield_capacity*2
  enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
  enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
  check(enemy.alive,kind+" headshots do not bypass overshield")
  # Body-to-head combination: drain normal shields without a precision hit.
  enemy.respawn();enemy.set_physics_process(false)
  var body_hits=0
  while enemy.shield>0 and enemy.alive and body_hits<100:
   enemy.take_damage(w.damage,"torso","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind);body_hits+=1
  check(enemy.alive and enemy.shield==0 and body_hits>1,kind+" normal body hits drain Naki shields without killing")
  enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
  check(not enemy.alive,kind+" one head impact finishes body-drained Naki")
  game.fair_health_type="annu";enemy.respawn();enemy.set_physics_process(false);body_hits=0
  while enemy.health>enemy.tuning.health_capacity/2.0 and enemy.alive and body_hits<100:
   enemy.take_damage(w.damage,"torso","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind);body_hits+=1
  check(enemy.alive,kind+" body-weakened Annu survives until finishing headshot")
  enemy.take_damage(w.damage,"head","bullet",w.precision,p,game.next_event()*16,Vector3.ZERO,kind)
  check(not enemy.alive,kind+" one head impact finishes sufficiently body-weakened Annu")
 var ambient=game.get_node("WaterfallAmbience")
 p.respawn();p.set_physics_process(false);p.global_position=Vector3(200,10,200);p.velocity=Vector3.ZERO
 check(is_equal_approx(ambient.target_gain(),.05),"Waterfall base gain is 5 percent")
 p.velocity=Vector3(0,-15,0);p.global_position.y=-8;var mid=ambient.target_gain();p.global_position.y=-17;var low=ambient.target_gain()
 check(mid>.05 and low>mid and low<=.28,"Waterfall grows smoothly louder as falling player approaches void floor")
 p.global_position.y=-8;p.velocity=Vector3.UP*5
 check(is_equal_approx(ambient.target_gain(),.05),"Jumping upward does not trigger death-fall swell")
 game.context="pause";check(ambient.target_gain()==0,"Waterfall is silent during pause")
 game.context="menu";check(ambient.target_gain()==0,"Waterfall is silent in main menu")
 check(ambient.voice.stream.loop,"Waterfall stream is imported as a loop")
 var tex=load("res://assets/v19_panorama.jpg")
 check(tex.get_width()<=768 and tex.get_height()<=384,"Panorama imported at lower resolution")
 var world=game.arena.find_children("*","WorldEnvironment",true,false)[0]
 check(world.environment.fog_enabled and world.environment.fog_density<.002,"Lightweight depth fog enabled without volumetric pass")
 print("V19.3 BALANCE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
