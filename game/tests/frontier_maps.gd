extends SceneTree
var checks=0
var rows=[]
func _initialize():call_deferred("run")
func ok(condition: bool,message: String) -> void:
 checks+=1
 assert(condition,message)
 if not condition:push_error(message);quit(1)
func v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func run():
 var world=Node3D.new();root.add_child(world)
 for map in [3,4,5]:
  var a=NestArena.new();a.map_selection=map;world.add_child(a)
  for i in range(5):await physics_frame
  var shape=CapsuleShape3D.new();shape.radius=NestActor.BODY_RADIUS-.02;shape.height=NestActor.STAND_HEIGHT-.04
  var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=1;q.margin=0
  var space=a.get_world_3d().direct_space_state
  for team in [0,1]:
   ok(a.spawns[team].size()>=10,"Enough authored team spawn choices")
   for p in a.spawns[team]:
    q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*(NestActor.STAND_CENTER+.03))
    ok(space.intersect_shape(q,1).is_empty(),"Blocked spawn "+a.map_title()+str(p));ok(a.has_walk_support(p,.2),"Spawn unsupported")
  for p in a.pads:
   q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*(NestActor.STAND_CENTER+.04))
   ok(space.intersect_shape(q,1).is_empty(),"Pickup inside solid "+a.map_title()+str(p));ok(a.has_walk_support(p,.2),"Pickup unsupported "+a.map_title()+str(p))
  for p in a.flag_positions:
   q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*(NestActor.STAND_CENTER+.03))
   ok(space.intersect_shape(q,1).is_empty(),"Flag base obstructed");ok(a.has_walk_support(p,.2),"Flag base unsupported")
  # Upper perimeter must remain closed when a player jumps from a ship or roof.
  for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
   var edge=40.0*a.width_multiplier()*.85 if side.x!=0 else 36.0*a.length_multiplier()*.85
   var query=PhysicsRayQueryParameters3D.create(side*(edge-3)+Vector3.UP*8,side*(edge+3)+Vector3.UP*8,1)
   var hit=space.intersect_ray(query)
   ok(not hit.is_empty() and hit.collider.get_meta("frontier_boundary",false),"Competitive upper perimeter must block every side")
  var distances=[]
  for team in [0,1]:
   var values=[]
   for site in a.sites:
    var origin=Vector3.ZERO
    for spawn in a.spawns[team]:origin+=spawn
    origin/=a.spawns[team].size()
    var path=a.route(origin,site);ok(path.size()>3,"Objective disconnected")
    var distance=0.
    for i in range(1,path.size()):distance+=path[i-1].distance_to(path[i])
    values.append(distance)
    var clear=0
    for side in [Vector3(2.6,0,0),Vector3(-2.6,0,0),Vector3(0,0,2.6),Vector3(0,0,-2.6)]:
     q.transform=Transform3D(Basis.IDENTITY,site+side+Vector3.UP*(NestActor.STAND_CENTER+.04))
     if space.intersect_shape(q,1).is_empty() and a.has_walk_support(site+side,.2):clear+=1
    ok(clear>=2,"Objective needs at least two clear interaction approaches")
   distances.append(values)
  for path in a.up_routes:
   for pos in [path.start,path.end]:ok(a.has_walk_support(pos,.3),"Ramp endpoint unsupported "+str(pos))
  var first=a.route(a.spawns[0][0],a.spawns[1][0]);ok(first.size()>5,"Teams disconnected")
  var model=NestForgeMap.new(null);model.arena=a
  ok(model.map_id().contains(a.map_title().to_lower()),"Forge map identity")
  var data={"id":map,"name":a.map_title(),"paths_to_sites_m":distances,"nodes":a.nav_points.size(),"blocked_nodes":a.blocked_nav.size(),"architecture":a.batch_stats,"foliage":a.get_meta("frontier_foliage",{}),"spawns":[a.spawns[0].map(v),a.spawns[1].map(v)],"sites":a.sites.map(v),"flags":a.flag_positions.map(v),"floors":a.floor_surfaces.map(func(f):return {"position":v(f.pos),"size":[f.size.x,f.size.y]}),"nav":a.nav_points.map(v),"ramps":a.up_routes.map(func(p):return {"start":v(p.start),"end":v(p.end),"width":p.width})}
  rows.append(data);print("FRONTIER_GEOMETRY ",JSON.stringify(data))
  a.queue_free();await process_frame;await physics_frame
 for id in range(6):
  var rules=NestMatchPresets.create(2,id,1);rules.validate();ok(rules.map_selection==id,"Preset retains map ID");ok(rules.map_name==NestArena.MAP_NAMES[id],"Map name validates")
 FileAccess.open("user://frontier-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
 print("FRONTIER MAPS: ",checks," checks passed");quit()
