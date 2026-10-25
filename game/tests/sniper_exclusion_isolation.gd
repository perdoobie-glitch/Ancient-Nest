extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.running=true;game.context="pause";game.mode=1;game.finished=false;game.break_until=0
 var actors=[]
 for team in [0,1]:
  var actor=NestActor.new();actor.game=game;actor.faction=team;actor.character_choice=0;actor.net_id=team+1;game.add_child(actor)
  actor.set_process(false);actor.set_physics_process(false);game.actors.append(actor);actors.append(actor)
 var shooter=actors[0];var target=actors[1]
 shooter.global_position=Vector3(100,30,100);target.global_position=Vector3(100,30,90)
 target.health=100;target.shield=1000;target.overshield=0
 await physics_frame
 var origin=shooter.eye.global_position;var direction=(target.hitboxes[0].global_position-origin).normalized()
 var before=target.shield
 game.launch_bullet(shooter,NestWeaponCatalog.profile("sniper_rifle"),origin,direction,0,false,16)
 check(target.shield<before,"First sniper shot damages target")
 check(target.hitboxes.all(func(area):return area.get_rid() not in shooter.ray_exclusions()),"Sniper penetration cannot poison shooter's cached exclusions")
 var after_sniper=target.shield
 game.launch_bullet(shooter,NestWeaponCatalog.profile("assault_rifle"),origin,direction,0,false,32)
 check(target.shield<after_sniper,"Rifle still damages the same target after sniper penetration")
 game.running=false;game.queue_free();await process_frame;quit(1 if failures else 0)
