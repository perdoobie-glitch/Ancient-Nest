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
func freeze(a: NestActor,pos: Vector3):
 a.set_physics_process(false);a.set_process(false);a.position=pos;a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.update_visual(0)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=true;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;var a=game.actors.filter(func(n):return n.character==1)[0]
 freeze(p,Vector3(120,70,110));freeze(a,Vector3(110,70,100));await physics_frame;await physics_frame
 check(a.nu_perch_area!=null and a.nu_perch_area.collision_layer==8,"Perched Nu has separate shootable body/wing/head/feet shapes")
 var point=a.perched_nu.global_transform*Vector3(0,.065,-.16)
 var start=point+Vector3.LEFT*2;var finish=point+Vector3.RIGHT*2
 var result=game.trace(start,finish,13,p.ray_exclusions())
 check(not result.is_empty() and result.collider==a.nu_perch_area,"Actual shot query reaches the perched bird before Annu's body")
 var hp=a.health;var armor=a.armor
 game.launch_bullet(p,NestWeaponCatalog.profile("sniper"),start,Vector3.RIGHT,0,false,game.next_event()*16)
 check(a.nu_used and not a.perched_nu.visible and a.nu_perch_area.collision_layer==0,"Shooting perched Nu removes it and spends that life’s ability")
 check(a.health==hp and a.armor==armor,"A sniper hit on perched Nu does not damage Annu's body")
 game.nu.toggle(a);check(a.action_state!="nu_launch" and not game.nu.birds.has(a.net_id),"Shot-down perched Nu cannot be deployed in the same life")
 a.nu_perch_area.destroy("duplicate");check(a.nu_used,"Repeated perched-bird destruction does not restore its use")
 a.respawn();freeze(a,Vector3(110,70,100));await physics_frame
 check(not a.nu_used and a.perched_nu.visible and a.nu_perch_area.collision_layer==8,"Nu returns on the shoulder and becomes usable on respawn")
 game.nu.toggle(a)
 check(not a.perched_nu.visible and a.nu_perch_area.collision_layer==0,"Launching Nu immediately removes its shoulder hurtbox")
 a.action_state="ready";a.nu_used=true
 # Exact lower-body damage uses the posed waist plane, not a static world height.
 a.respawn();freeze(a,Vector3(110,70,100));var foot=a.position+Vector3.UP*.3
 check(a.below_waist("leg",foot) and not a.below_waist("torso",a.position+Vector3.UP*1.8),"Sniper lower-body classification follows the rig waist")
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,foot)
 check(a.alive and is_equal_approx(a.health,50),"Armored Annu survives the first below-waist sniper hit with 50 health")
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,foot)
 check(not a.alive,"Second below-waist sniper hit kills armored Annu")
 a.respawn();freeze(a,Vector3(110,70,100));a.armor=0;foot=a.position+Vector3.UP*.3
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,foot)
 check(a.alive and is_equal_approx(a.health,50),"Unarmored Annu also survives one below-waist sniper hit")
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,foot)
 check(not a.alive,"Second lower-body sniper hit kills unarmored Annu")
 a.respawn();freeze(a,Vector3(110,70,100));a.armor=0;foot=a.position+Vector3.UP*.3
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",150,foot)
 check(a.alive and is_equal_approx(a.health,50),"Default two-shot lower-body damage remains consistent at long valid range")
 a.respawn();freeze(a,Vector3(110,70,100));a.armor=0
 a.take_damage(100,"torso","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,a.position+Vector3.UP*1.8)
 check(not a.alive,"Unarmored upper-body sniper damage is unchanged")
 a.respawn();freeze(a,Vector3(110,70,100))
 a.take_damage(100,"head","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,a.position+Vector3.UP*2.2)
 check(not a.alive,"Sniper headshots retain their existing instant kill")
 a.respawn();freeze(a,Vector3(110,70,100));a.armor=0;game.game_type.weapon_damage_percent["sniper"]=50
 a.take_damage(100,"leg","bullet",true,p,game.next_event()*16,p.eye.global_position,"sniper",20,a.position+Vector3.UP*.3)
 check(a.alive and is_equal_approx(a.health,75),"Custom weapon damage still scales the two-shot default rule")
 game.rewind_active=true;game.rewind_poses[a.get_instance_id()]={"waist":Vector3(0,80,0)}
 check(a.below_waist("torso",Vector3(110,79,100)),"Lag-compensated lower-body classification uses the historical waist, not current height")
 game.end_rewind()
 game.stop_game();game.queue_free();await frames(8)
 print("PERCHED NU / LOWER SNIPER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
