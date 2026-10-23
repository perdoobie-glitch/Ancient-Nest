extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=2):
 for i in range(n):await process_frame
func box(pos,size):
 var body=StaticBody3D.new();var shape=CollisionShape3D.new();var mesh=BoxShape3D.new();mesh.size=size;shape.shape=mesh;body.add_child(shape);game.add_child(body);body.global_position=pos;return body
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.selected_faction=0;game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(100,30,100);p.rotation.y=0;p.eye.rotation.x=0;p.reset_physics_interpolation();p.reset_aim()
 var enemy=NestActor.new();enemy.game=game;enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.set_character(1);enemy.respawn();enemy.set_physics_process(false);enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);await physics_frame
 var weapon=NestWeaponCatalog.profile("rifle");var origin=p.eye.global_position;var target=enemy.hitboxes[1].global_position;var shield=enemy.armor;var hp=enemy.health
 game.launch_bullet(p,weapon,origin,(target-origin).normalized(),0,false,game.next_event()*16)
 check(enemy.health<hp and enemy.armor<shield,"Rifle hitscan applies anatomical damage synchronously")
 check(weapon.speed==0 and NestWeaponCatalog.profile("sniper").speed==0 and NestWeaponCatalog.profile("ak47").speed==0,"Precision firearms are hitscan")
 enemy.respawn();enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);await physics_frame
 var short=weapon.duplicate();short.max_range=3;hp=enemy.health;game.launch_bullet(p,short,origin,(enemy.hitboxes[1].global_position-origin).normalized(),0,false,game.next_event()*16)
 check(enemy.health==hp,"Hitscan cannot damage beyond maximum range")
 var own=p.shield;game.launch_bullet(p,weapon,p.hitboxes[1].global_position,Vector3.RIGHT,0,false,game.next_event()*16)
 check(p.shield==own,"Shooter body and all owned hitboxes are excluded")
 var wall=box(Vector3(100,31,99.7),Vector3(3,3,.08));await physics_frame
 var aim=p.resolve_shot_aim(100);hp=enemy.health;game.launch_bullet(p,weapon,aim.origin,aim.direction,0,false,game.next_event()*16)
 check(aim.origin.z>99.74 and enemy.health==hp,"Camera-origin shot stays on the near side and hits the wall under the crosshair")
 var beams=game.effects.get_children().filter(func(node):return node is MeshInstance3D and node.get_script()!=null and node.get_script().resource_path.ends_with("tracer.gd"))
 check(not beams.is_empty(),"Hitscan creates a visible tracer for its resolved ray")
 wall.queue_free();await frames(3)
 var fast=weapon.duplicate();fast.speed=1000;fast.max_range=15;hp=enemy.health;game.launch_bullet(p,fast,origin,(enemy.hitboxes[1].global_position-origin).normalized(),0,false,game.next_event()*16)
 await physics_frame;await physics_frame;check(enemy.health<hp,"Fast projectile sweep contacts a target crossed within one physics tick")
 enemy.respawn();enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);await physics_frame
 fast.max_range=3;hp=enemy.health;game.launch_bullet(p,fast,origin,(enemy.hitboxes[1].global_position-origin).normalized(),0,false,game.next_event()*16)
 await physics_frame;await physics_frame;check(enemy.health==hp,"Swept projectile segment is clipped to its remaining range")
 p.eye.rotation.x=0;p.rotation.y=.8;p.apply_aim_rotation();var direction=p.aim_direction();var ray=p.resolve_shot_aim(100)
 check(ray.aim_point.distance_to(p.camera.global_position+direction*p.camera.global_position.distance_to(ray.aim_point))<.001,"Rapid raw camera turn and shot query share the same current ray")
 enemy.respawn();enemy.global_position=Vector3(100,30,90);enemy.update_visual(.016);await physics_frame
 var head=enemy.hitboxes[0].global_position;var offset=head-p.eye.global_position
 p.rotation.y=atan2(-offset.x,-offset.z);p.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());p.reset_aim()
 var sniper=NestWeaponCatalog.profile("sniper").duplicate();sniper.spread_degrees=0;p.weapons.assign([sniper]);p.ammo.assign([4]);p.reserve.assign([12]);p.slot=0;p.action_state="ready";p.cooldown=game.now;p.burst_left=0
 await frames(2);var before=p.resolve_shot_aim(400);var emitted=[]
 p.shot_fired.connect(func(_id,_time,_origin,directions):emitted.append(directions[0]))
 p.fire_trigger()
 check(not enemy.alive and emitted.size()==1 and emitted[0].is_equal_approx(before.direction) and p.aim_direction().dot(emitted[0])<.9999,"Hit query uses pre-shot aim and recoil changes only the subsequent view")
 game.stop_game();game.queue_free();await frames(6);print("COMBAT GEOMETRY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
