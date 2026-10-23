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
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var rocket=NestWeaponCatalog.profile("rocket_launcher")
 if rocket.kind!="rocket":rocket=NestWeaponCatalog.profile("rocket")
 check(is_equal_approx(rocket.speed,32.8125) and is_equal_approx(load("res://resources/rocket.tres").speed,32.8125),"Catalog and resource both use 20 percent shorter rocket travel time")
 check(is_equal_approx(NestRocketArt.LENGTH,.65) and is_equal_approx(NestRocketArt.DIAMETER,.09),"Rocket body is longer and wider")
 p.weapons.assign([rocket]);p.ammo.assign([0]);p.reserve.assign([6]);p.slot=0;p.update_weapon_art()
 check(p.weapon_art.scale.is_equal_approx(Vector3(.935,.935,1.0625)),"Launcher is 10 percent bulkier and 25 percent longer")
 check(p.weapon_art.has_meta("rocket_reload") and p.remote_art.has_meta("rocket_reload"),"First and third person have reload components")
 p.reload_weapon();check(p.action_state=="reloading" and p.reload_duration==2,"Reload keeps its established simulation duration")
 game.now=p.action_until-p.reload_duration*.55;p.presentation.update_view_weapon(0);p.presentation.pose_upper_body()
 var local=p.weapon_art.get_meta("rocket_reload");var remote=p.remote_art.get_meta("rocket_reload")
 check(local.payload.visible and absf(local.hatch.rotation.x)>.5,"Local reload opens breech and shows replacement rocket")
 check(remote.payload.visible and absf(remote.hatch.rotation.x)>.5,"Remote reload uses the same breech/payload phase")
 var before=local.payload.position;game.now=p.action_until-p.reload_duration*.33;p.presentation.update_view_weapon(0)
 check(local.payload.position.distance_to(before)>.10,"Replacement rocket moves into the launcher")
 check(p.ammo[0]==0,"Cosmetic insertion cannot grant early ammunition")
 game.now=p.action_until+.001;p.advance_weapon_timers();p.presentation.update_view_weapon(0)
 check(p.ammo[0]==2 and p.reserve[0]==4 and p.action_state=="ready","Simulation completes reload and transfers two rounds once")
 check(not local.payload.visible and absf(local.hatch.rotation.x)<.001,"Reload stows payload and closes hatch")
 var camera=p.camera.global_transform;p.presentation.animate_parts(p.weapon_art,.45)
 check(p.camera.global_transform.is_equal_approx(camera),"Reload animation never moves the aim camera")
 p.global_position=Vector3(900,100,900);p.eye.rotation=Vector3.ZERO;p.rotation=Vector3.ZERO;p.reset_physics_interpolation();p.reset_aim()
 var script=load("res://scripts/bullet.gd");var bullet=Node3D.new();bullet.set_script(script);bullet.game=game;bullet.owner_actor=p;bullet.profile=rocket;bullet.direction=Vector3.FORWARD;bullet.round_id=game.round_number;bullet.event_id=game.next_event()*16;bullet.excludes=p.ray_exclusions();bullet.position=Vector3(900,102,900);game.effects.add_child(bullet);bullet.set_physics_process(false)
 check(bullet.get_node_or_null("RocketProjectile")!=null,"In-flight rocket uses shaped body/nose/fins")
 var start=bullet.position;bullet._physics_process(1.0/60)
 check(absf(start.distance_to(bullet.position)-32.8125/60)<.0001,"Actual swept projectile advances at the new speed")
 var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,3,.03);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=Vector3(900,102,899.7);await physics_frame
 check(bullet.resolve_hit(Vector3(900,102,900),Vector3(900,102,899)),"Swept flight hits a thin wall crossed between positions")
 bullet.queue_free();game.stop_game();game.queue_free();await frames(8)
 print("ROCKET V27: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
