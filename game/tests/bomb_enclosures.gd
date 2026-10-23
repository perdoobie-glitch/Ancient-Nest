extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func ray_area(site: Vector3,exclude: Array[RID]) -> float:
 var area=0.0
 for offset in [Vector3(-2.8,0,0),Vector3(0,0,2.8),Vector3(0,0,-2.8)]:
  var origin=site+offset*.85+Vector3.UP*1.55
  for i in range(180):
   var direction=Vector3(sin(i*TAU/180),0,cos(i*TAU/180))
   var hit=game.trace(origin,origin+direction*10.2,1,exclude)
   var distance=10.2 if hit.is_empty() else origin.distance_to(hit.position)
   area+=distance*distance
 return area/540.0
func walk(points: Array,name: String):
 var p=game.player;p.respawn();p.set_physics_process(false);p.global_position=points[0]*.85+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
 for index in range(1,points.size()):
  var target: Vector3=points[index]*.85;var direction=(target-p.global_position);direction.y=0
  var yaw=atan2(-direction.x,-direction.z)
  for frame in range(300):
   var remaining=Vector2(target.x-p.global_position.x,target.z-p.global_position.z).length()
   if remaining<.22:break
   p.movement_step(Vector2(0,-1),false,0,yaw,1.0/60);await physics_frame
  p.controlled=Vector3.ZERO;p.velocity=Vector3.ZERO
  check(p.alive and p.is_on_floor() and Vector2(target.x-p.global_position.x,target.z-p.global_position.z).length()<.3,name+" waypoint "+str(index)+" reached: "+str(p.global_position))
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=0;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 game.player.set_physics_process(false)
 await physics_frame;await physics_frame
 var a=game.arena;var new_root=a.get_node("BombSiteEnclosures");var exclude: Array[RID]=[]
 for body in new_root.find_children("*","StaticBody3D",true,false):exclude.append(body.get_rid())
 check(exclude.size()>=16,"New walls, roofs and doorway jambs all have world collision")
 var metrics=[]
 for i in range(2):
  var before=ray_area(a.sites[i],exclude);var after=ray_area(a.sites[i],[]);var reduction=1-after/before
  metrics.append({"site":"A" if i==0 else "B","baseline_radial_area_proxy":before,"enclosed_radial_area_proxy":after,"reduction":reduction})
  print("OPENNESS ",metrics[-1]);check(reduction>=.35,"Site %d radial visible-area proxy reduced by at least 35%%"%i)
 # Real capsule traversals in both directions, including each alternate site door.
 var routes=[
  {"name":"A covered west entry","points":[Vector3(2.5,7,-2.3),Vector3(11.8,7,-2.3),Vector3(13.3,7,-1.5)]},
  {"name":"A south entry","points":[Vector3(13.2,7,3.4),Vector3(14.6,7,3.4),Vector3(15,7,2.7)]},
  {"name":"B side hall","points":[Vector3(22,0,8.4),Vector3(22,0,2.5),Vector3(19,0,2.5),Vector3(17.5,0,2.7)]},
  {"name":"B north entry","points":[Vector3(22,0,-6.5),Vector3(22,0,-2),Vector3(22,0,2.5)]},
  {"name":"B west entry","points":[Vector3(11.5,0,-4),Vector3(13.3,0,-2.2)]}]
 for path in routes:
  await walk(path.points,path.name)
  var reverse=path.points.duplicate();reverse.reverse();await walk(reverse,path.name+" reverse")
 for i in range(2):
  for offset in [Vector3(-2.8,0,0),Vector3(0,0,2.8)]:
   var pos=a.sites[i]+offset*.85
   var q=PhysicsShapeQueryParameters3D.new();var capsule=CapsuleShape3D.new();capsule.height=1.85;capsule.radius=.32;q.shape=capsule;q.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.96);q.collision_mask=1
   check(game.get_world_3d().direct_space_state.intersect_shape(q).is_empty(),"Bomb interaction standing pocket remains clear "+str(i)+" "+str(offset))
   game.player.global_position=pos;game.player.faction=game.attacking_faction
   check(not game.interaction_for(game.player).is_empty(),"Bomb remains interactable from approach "+str(i))
 for faction in a.spawns:
  for pos in a.spawns[faction]:
   for site in a.sites:check(not a.route(pos,site).is_empty(),"Bot graph connects spawn to bomb site")
 # New walls block world hitscan at standing height; open doorway remains clear.
 for line in [[Vector3(18,8.6,0),Vector3(21,8.6,0)],[Vector3(18,1.6,-2),Vector3(22,1.6,-2)]]:
  check(not game.trace(line[0]*.85,line[1]*.85,1).is_empty(),"Enclosure stops world hitscan")
 check(game.trace(Vector3(19,1.6,2.5)*.85,Vector3(23,1.6,2.5)*.85,1).is_empty(),"B hallway doorway passes world hitscan")
 var file=FileAccess.open("/workspace/work/v17_2/openness-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 print("BOMB ENCLOSURES: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
