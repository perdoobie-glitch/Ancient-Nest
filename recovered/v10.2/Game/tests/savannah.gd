extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,msg: String):
 if not ok:failures.append(msg);print("FAIL ",msg)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(2,2);game.apply_game_type_settings(rules)
 for i in range(5):await physics_frame
 var a=game.arena
 check(a.map_title()=="Savannah","map selection")
 check(game.game_type.map_selection==2,"settings validation retained Savannah")
 var points=[]
 for team in [0,1]:
  for p in a.spawns[team]:points.append({"name":"spawn "+str(team),"p":p})
 for p in a.sites:points.append({"name":"site approach","p":p+Vector3(3,.08,0)})
 for p in a.flag_positions:points.append({"name":"flag","p":p+Vector3.UP*.08})
 for p in a.pads:points.append({"name":"pickup","p":p+Vector3.UP*.08})
 for item in points:
  var p=item.p
  check(a.has_walk_support(p,.3),item.name+" supported "+str(p))
  var shape=CapsuleShape3D.new();shape.radius=NestActor.BODY_RADIUS+.03;shape.height=NestActor.STAND_HEIGHT
  var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=1;q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*NestActor.STAND_CENTER)
  var hits=game.get_world_3d().direct_space_state.intersect_shape(q)
  check(hits.is_empty(),item.name+" obstructed "+str(p)+" "+str(hits))
 for p in a.sites+a.pads:
  var path=a.route(a.spawns[0][2],p)
  check(path.size()>1,"route to "+str(p));print("ROUTE ",p," ",path.size())
 for ramp in a.up_routes:
  print("RAMP ",ramp.start," -> ",ramp.end)
 for l in a.find_children("*","Label3D",true,false):check(not l.visible or l in a.deposit_labels,"unwanted map label "+l.text)
 print("SAVANNAH ",a.nav_points.size()," nav points, ",a.floor_surfaces.size()," floor strips, ",points.size()," placements; failures=",failures.size())
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
