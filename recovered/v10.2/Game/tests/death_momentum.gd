extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func ticks(n=2):
 for i in range(n):await physics_frame
func victim(character=0):
 var v=NestActor.new();v.game=game;v.faction=1;v.character_choice=character;game.add_child(v);game.actors.append(v);v.respawn();v.set_physics_process(false);v.set_process(false);v.position=Vector3(600,80.02,600);v.rotation=Vector3.ZERO;v.update_visual(0);return v
func kill(v,origin=Vector3(600,81.8,603)):
 v.shield=0;v.take_damage(1,"head","bullet",true,game.player,game.next_event(),origin,"ak47",2,v.hitboxes[0].global_position)
 return game.corpses.get_child(game.corpses.get_child_count()-1)
func shot(start,finish,id):
 var w=NestWeaponCatalog.profile("ak47");game.launch_bullet(game.player,w,start,(finish-start).normalized(),0,false,id)
func screenshot(name):
 var args=OS.get_cmdline_user_args()
 if DisplayServer.get_name()=="headless" or args.is_empty():return
 DirAccess.make_dir_recursive_absolute(args[0])
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(args[0].path_join(name+".png"))
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=1;game.start_game();game.clear_screen();game.context="pause"
 var p=game.player;p.set_process(false);p.set_physics_process(false);p.position=Vector3(600,80.02,604);p.update_visual(0)
 var floor=StaticBody3D.new();var cs=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);cs.shape=box;floor.add_child(cs);game.add_child(floor);floor.position=Vector3(600,79.5,600)
 game.arena.kit.box(game,Vector3(600,79.5,600),Vector3(30,1,30),game.arena.kit.dark)
 var cam=Camera3D.new();game.add_child(cam);cam.position=Vector3(604,83.2,604);cam.look_at(Vector3(600,81,600));cam.current=true
 var v=victim();v.velocity=Vector3(2,0,0);await ticks(3);var head=v.hitboxes[0].global_position;var body=kill(v)
 check(not v.alive and game.corpses.get_child_count()==1,"Lethal hit creates one posed death body")
 check(body.hitboxes.size()==17 and body.hitboxes.all(func(a):return a.collision_layer==16 and not a.has_meta("actor")),"Corpse contours are separate from all living damage targets")
 check(body.collision_layer==0 and body.collision_mask==1,"Body collides with world without blocking players or grenades")
 check(body.angular_velocity.length()>.5,"Impact starts a physical tumble")
 check(body.skeleton.get_bone_pose(0).is_equal_approx(v.skeleton.get_bone_pose(0)),"Body starts from the actual visible skeleton pose")
 v.die(p,"bullet");check(game.corpses.get_child_count()==1,"Repeated death cannot duplicate bodies")
 await ticks(2)
 check(body.linear_velocity.x>1.8 and body.linear_velocity.z<-.5,"Death inherits movement plus the killing bullet direction")
 check(v.hitboxes.all(func(a):return a.collision_layer==0),"Death disables every living hitbox")
 var side=body.hitboxes[0].global_position;var velocity_before=body.linear_velocity.x
 shot(side+Vector3.RIGHT*3,side-Vector3.RIGHT*3,7000000);await ticks(2)
 check(body.linear_velocity.x<velocity_before-.2,"Later bullet contact changes actual physical momentum")
 await screenshot("death-momentum-start")
 var first=body.global_transform;await create_timer(.45).timeout
 check(body.global_position.distance_to(first.origin)>.25 and not body.global_basis.is_equal_approx(first.basis),"Body moves and rotates during its death animation")
 await screenshot("death-momentum-fall")
 await create_timer(1).timeout
 check(is_instance_valid(body) and body.age<3,"Body remains visible before three seconds")
 await screenshot("death-momentum-ground")
 await create_timer(1.65).timeout;await process_frame
 check(not is_instance_valid(body),"Body and its collision areas disappear after three seconds")
 # Freeze a new body only in this fixture to exercise repeatable shot geometry.
 v.respawn();v.position=Vector3(600,80.02,600);v.rotation=Vector3.ZERO;v.velocity=Vector3.ZERO;v.update_visual(0);body=kill(v);body.freeze=true;body.set_physics_process(false);await ticks(2)
 head=body.hitboxes[0].global_position;var start=head+Vector3(0,0,3);var finish=head-Vector3(0,0,8)
 check(game.trace(start,finish,5,p.ray_exclusions()).is_empty(),"Corpse never obstructs an ordinary living-player hit query")
 var before=body.applied_impacts.size();var health=v.health;var kills=p.kills;shot(start,finish,7000016)
 check(body.applied_impacts.size()==before+1,"Post-death bullet contact adds a physical impulse")
 shot(start,finish,7000016);check(body.applied_impacts.size()==before+1,"One shot ID cannot apply its impulse twice")
 check(v.health==health and p.kills==kills,"Shooting a corpse cannot deal health damage or award another kill")
 var alive=victim(1);alive.shield=0;alive.helmet_hp=0;alive.position=Vector3(600,80.02,595);alive.update_visual(0);await ticks(3)
 var aim=alive.hitboxes[0].global_position;shot(start,aim,7000032)
 check(not alive.alive,"A corpse in the bullet path cannot protect a living target")
 var annu=game.corpses.get_child(game.corpses.get_child_count()-1)
 check(annu.spec.character==1 and annu.hitboxes.size()==17 and annu.skeleton.get_bone_count()==alive.skeleton.get_bone_count(),"Annu deaths retain their own model, rig and body contours")
 # A world wall ends the segment before any cosmetic body contact.
 var wall=StaticBody3D.new();var sh=CollisionShape3D.new();var b=BoxShape3D.new();b.size=Vector3(3,4,.2);sh.shape=b;wall.add_child(sh);game.add_child(wall);wall.position=Vector3(600,81,601.5);await ticks(2)
 before=body.applied_impacts.size();shot(start,finish,7000048)
 check(body.applied_impacts.size()==before,"Cover blocks corpse impulses as well as living hits")
 var count=game.corpses.get_child_count();game.spawn_death_body(v,"bullet");check(game.corpses.get_child_count()==count,"Processed life IDs cannot spawn duplicate bodies")
 game.receive_death_body(body.spec,game.match_session+1,game.round_number);check(game.corpses.get_child_count()==count,"Stale-session death messages are ignored")
 game.clear_effects();await process_frame;check(game.corpses.get_child_count()==0,"Round cleanup removes all remaining death bodies")
 print("DEATH MOMENTUM: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
