extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=1;game.start_game();game.clear_screen();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.weapons.assign([NestWeaponCatalog.profile("ak47")]);p.ammo.assign([30]);p.reserve.assign([90]);p.slot=0;p.action_state="ready";p.position=Vector3(600,100,600);p.reset_aim();p.reset_ak_spray();p.update_visual(0);game.now=20
 check(is_equal_approx(p.tuning.ground_speed,6.6) and is_equal_approx(p.tuning.crouch_speed,3.3) and is_equal_approx(p.tuning.air_speed_cap,9.9),"Standing, crouched and air speed limits increase by 10%")
 check(is_equal_approx(p.tuning.gravity,9.0451693*.9),"Character gravity is exactly 90% of the previous value")
 check(is_equal_approx(float(ProjectSettings.get_setting("physics/3d/default_gravity")),8.1632653*.9),"World rigid-body gravity is also reduced 10%")
 var tracer=NestTracer.new();tracer.game=game;game.effects.add_child(tracer);tracer.setup(Vector3.ZERO,Vector3.FORWARD*20,.1)
 check(is_equal_approx(tracer.initial_opacity,.125) and is_equal_approx(tracer.material.albedo_color.a,.125),"Hitscan streak opacity increases by 25%")
 var projectile=Node3D.new();game.effects.add_child(projectile);var trail=NestTracer.attach_projectile(projectile,Vector3.FORWARD,.1)
 check(is_equal_approx(trail.material.albedo_color.a,.125),"Swept projectile streak opacity also increases 25%")
 var previous=0.;var last_dir=Vector3.FORWARD
 for number in range(1,31):
  game.now=20+(number-1)*.1;p.prepare_ak_shot(number*16);var spread=p.current_spread_degrees(true)
  if number<=5:check(spread==0 and NestAKSpray.offset(number)==Vector2.ZERO,"AK shot %d retains initial precision"%number)
  elif number<=30:check(spread>previous,"AK cone grows on shot %d"%number)
  previous=spread
  var one=p.shot_directions(Vector3.FORWARD,p.eye.global_position,number*16);var two=p.shot_directions(Vector3.FORWARD,p.eye.global_position,number*16)
  check(one==two,"AK shot %d is deterministic for its event ID"%number)
  if number==30:last_dir=one[0]
 check(last_dir.angle_to(Vector3.FORWARD)>.01 and p.ak_spray_count==30,"Sustained AK fire follows a visibly displaced spray pattern")
 p.prepare_ak_shot(30*16);check(p.ak_spray_count==30,"Repeated event ID cannot advance spray twice")
 game.now=p.ak_spray_last+.999;p.advance_combat_recovery();check(p.ak_spray_count==30,"Spray does not reset before one full second")
 game.now+=.001;p.advance_combat_recovery();check(p.ak_spray_count==0,"Spray resets at one second without firing")
 p.prepare_ak_shot(1000);p.prepare_ak_shot(1016);p.ammo[0]=20;p.reload_weapon();check(p.ak_spray_count==0 and p.action_state=="reloading","Accepted reload resets AK accuracy immediately")
 p.action_state="ready";p.ammo[0]=30;p.prepare_ak_shot(1032);p.reload_weapon();check(p.ak_spray_count==1,"Rejected full-mag reload cannot reset spray")
 p.reset_ak_spray();p.prepare_ak_shot(1056,10,true);game.now=1000;p.advance_combat_recovery();p.prepare_ak_shot(1072,10.1,true)
 check(p.ak_spray_count==2,"Server uses command simulation time despite unrelated arrival clock")
 p.prepare_ak_shot(1088,11.1,true);check(p.ak_spray_count==1,"Server command clock resets after a one-second gap")
 p.prepare_ak_shot(1104,game.now,false);check(p.ak_spray_count==2,"Alternating network timing modes cannot grant an accuracy reset")
 var v=NestActor.new();v.game=game;v.faction=1;v.character_choice=0;game.add_child(v);game.actors.append(v);v.respawn();v.set_physics_process(false);v.set_process(false);v.position=Vector3(600,100,590);v.update_visual(0)
 v.take_damage(50,"torso","bullet",false,p,2000,p.eye.global_position,"ak47",0);check(is_equal_approx(v.shield,67.5),"AK body hit deals 32.5 to Naki shields, down from 50")
 v.shield=0;v.health=100;v.take_damage(50,"torso","bullet",false,p,2016,p.eye.global_position,"ak47",0);check(is_equal_approx(v.health,100-32.5/3),"Exposed Naki body resistance stacks with the 35% AK reduction")
 v.respawn();v.set_physics_process(false);v.take_damage(50,"head","bullet",false,p,2032,p.eye.global_position,"ak47",0);check(v.shield==50,"AK head damage to shields is unchanged")
 v.set_character(1);v.respawn();v.set_physics_process(false);v.armor=0;v.take_damage(50,"torso","bullet",false,p,2048,p.eye.global_position,"ak47",0);check(is_equal_approx(v.health,67.5),"Armorless Annu receives 32.5 AK body damage")
 v.position=Vector3(600,100,590);v.update_visual(0);v.last_damage=game.now;v.last_damage_origin=v.position+Vector3(0,1.8,3);v.last_impact_point=v.hitboxes[0].global_position
 var head=NestDeathBody.snapshot(v,"head","headshot");var body=NestDeathBody.snapshot(v,"body","bullet")
 check(head.impulse.length()>body.impulse.length()*1.5 and head.headshot,"Headshot killing impact has stronger directional momentum")
 var corpse=game.add_death_body(head)
 check(corpse.angular_velocity.length()>3.9 and corpse.collision_layer==0 and NestDeathBody.LIFETIME==3,"Headshot body flops quickly, stays cosmetic and retains three-second cleanup")
 print("V15 BALANCE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
