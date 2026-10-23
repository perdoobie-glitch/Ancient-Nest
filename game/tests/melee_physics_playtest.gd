extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func ticks(n=2):
 for i in range(n):await physics_frame
func reset(p,v,distance):
 p.respawn();v.respawn();p.position=Vector3(600,80.02,600);v.position=Vector3(600,80.02,600-distance);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim();v.update_visual(0);p.reset_physics_interpolation()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=1;game.start_game()
 var p=game.player;p.set_process(false)
 var floor=StaticBody3D.new();var cs=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,1,20);cs.shape=box;floor.add_child(cs);game.add_child(floor);floor.position=Vector3(600,79.5,600)
 var v=NestActor.new();v.game=game;v.faction=1;v.character_choice=0;game.add_child(v);game.actors.append(v);v.respawn();v.set_physics_process(false);v.set_process(false)
 for distance in [1.3,2.3,2.8,2.9]:
  reset(p,v,distance);await ticks(5);var start=p.position;p.melee();await ticks(5)
  check(v.shield==100,"Melee has no early damage at range %.1fm"%distance)
  await ticks(13)
  check(v.shield==0 and v.health==100,"Lunge contact window reaches legal target at %.1fm"%distance)
  var travelled=Vector2(p.position.x-start.x,p.position.z-start.z).length()
  check(travelled<=1.25 and travelled>.05,"Melee adds bounded four-foot lunge without teleport (%.3fm)"%travelled)
  if distance>=2.8:check(absf(travelled-1.22)<.03,"Open lunge physically travels 1.22 m")
  await ticks(35);check(v.health==100,"Single strike cannot damage again later")
 reset(p,v,4);await ticks(4);p.melee();await ticks(20);check(v.shield==100,"Melee cannot acquire an out-of-range target")
 # Full-height wall blocks both movement and contact.
 reset(p,v,1.7);var body=StaticBody3D.new();var shape=CollisionShape3D.new();var b=BoxShape3D.new();b.size=Vector3(3,4,.15);shape.shape=b;body.add_child(shape);game.add_child(body);body.position=Vector3(600,81,599.2);await ticks(4)
 var start=p.position;p.melee();await ticks(20);check(v.shield==100,"Melee cannot damage through cover");check(p.position.z>body.position.z+.25,"Lunge is stopped by collision cover")
 body.queue_free();await ticks(2)
 reset(p,v,1.3);await ticks(4);p.melee();await ticks(3);game.cancel_uncommitted_input();await ticks(18);check(v.shield==100,"Pause/focus cancellation prevents uncommitted melee contact")
 reset(p,v,1.3);await ticks(4);p.melee();p.die(null,"test");await ticks(18);check(v.shield==100,"Dying during windup prevents posthumous melee")
 game.stop_game();game.queue_free();await process_frame;print("MELEE PHYSICS PLAYTEST: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
