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
func wall(pos: Vector3,size: Vector3) -> StaticBody3D:
 var body=StaticBody3D.new();var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision);game.add_child(body);body.global_position=pos;return body
func equip(p,kind):
 p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.ammo.assign([30]);p.reserve.assign([90]);p.slot=0;p.action_state="ready";p.cooldown=game.now;p.burst_left=0;p.aim_punch=Vector2.ZERO;p.reset_aim()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);var service=game.lobby_network;service.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(100,30,100);p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.reset_aim()
 var enemy=NestActor.new();enemy.game=game;enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.respawn();enemy.set_physics_process(false);enemy.set_process(false);enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016)
 await physics_frame;var head=enemy.hitboxes[0].global_position;var offset=head-p.eye.global_position
 p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.reset_aim();equip(p,"sniper")
 var cover=wall(Vector3(100.3,p.eye.global_position.y-.3,99.4),Vector3(.35,3,1.8));await physics_frame
 check(not game.trace(p.eye.global_position,p.muzzle_position(),1,p.ray_exclusions()).is_empty(),"Reproduced: offset muzzle is obstructed by side cover")
 check(game.trace(p.camera.global_position,p.camera.global_position+p.aim_direction()*5,1,p.ray_exclusions()).is_empty(),"Reproduced: crosshair ray is clear beside the same cover")
 for kind in ["sniper","ak47","rifle","burst","shotgun","plasma_br","plasma_auto","rocket"]:
  equip(p,kind);var aim=p.resolve_shot_aim(100)
  check(aim.origin.is_equal_approx(p.camera.global_position) and aim.direction.is_equal_approx(p.aim_direction()),kind+" starts on the current view ray despite blocked gun")
 equip(p,"sniper");var aim=p.resolve_shot_aim(100);var directions=p.shot_directions(p.aim_direction(),aim.origin,160,p.eye.global_position+Vector3(.1,0,0))
 check(directions[0].is_equal_approx(p.aim_direction()),"Server/client spread direction cannot reconverge from a different origin")
 check(p.fire_trigger() and not enemy.alive,"Actual sniper shot hits the visible target beside a blocked muzzle")
 enemy.respawn();enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);equip(p,"plasma_br");var hp=enemy.health;var armor=enemy.armor
 aim=p.resolve_shot_aim(100);game.launch_bullet(p,p.weapons[0],aim.origin,aim.direction,0,false,game.next_event()*16)
 for i in range(80):await physics_frame
 check(enemy.health<hp or enemy.armor<armor,"Actual swept plasma projectile clears side cover from the crosshair")
 var front=wall(Vector3(100,p.eye.global_position.y,99.6),Vector3(2,3,.08));await physics_frame
 enemy.respawn();enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);equip(p,"sniper");hp=enemy.health;aim=p.resolve_shot_aim(100);p.fire_trigger()
 check(enemy.health==hp and not game.trace(aim.origin,aim.origin+aim.direction*3,1,p.ray_exclusions()).is_empty(),"Wall directly under crosshair still stops actual gunfire")
 var original=p.camera.global_position;p.camera.global_position=original+Vector3(0,0,-1);aim=p.resolve_shot_aim(100)
 check(aim.origin.z>99.64,"Camera correction cannot place shot origin through a solid wall")
 p.camera.global_position=original;front.queue_free();cover.queue_free();game.stop_game();game.queue_free();await frames(8)
 print("CROSSHAIR ORIGIN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
