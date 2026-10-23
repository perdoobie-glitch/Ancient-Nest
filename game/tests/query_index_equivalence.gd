extends SceneTree
var a:NestArena
var checks=0
func _initialize():call_deferred("run")
func legacy_support(pos: Vector3, tolerance: float=.5) -> bool:
 # Savannah's adjacent floor strips are one continuous surface, including their seams.
 if a.map_selection==2:
  var supported_corners=true
  for offset in [Vector2(-.32,-.32),Vector2(-.32,.32),Vector2(.32,-.32),Vector2(.32,.32)]:
   var found=false
   for slab in a.floor_surfaces:
    if absf(slab.pos.y-pos.y)<=tolerance and absf(pos.x+offset.x-slab.pos.x)<=slab.size.x*.5+.001 and absf(pos.z+offset.y-slab.pos.z)<=slab.size.y*.5+.001:found=true;break
   if not found:supported_corners=false;break
  if supported_corners:return true
 for floor in a.floor_surfaces:
  if absf(floor.pos.y-pos.y)<=tolerance and absf(pos.x-floor.pos.x)<=floor.size.x*.5-.32 and absf(pos.z-floor.pos.z)<=floor.size.y*.5-.32: return true
 for path in a.up_routes:
  var start=Vector2(path.start.x,path.start.z); var delta=Vector2(path.end.x,path.end.z)-start
  var t=(Vector2(pos.x,pos.z)-start).dot(delta)/delta.length_squared()
  if t<0 or t>1: continue
  if Vector2(pos.x,pos.z).distance_to(start+delta*t)<path.width*.5-.32 and absf(pos.y-lerpf(path.start.y,path.end.y,t))<=tolerance: return true
 return false

func run():
 seed(19012)
 for map in [0,1,2]:
  a=NestArena.new();a.map_selection=map;root.add_child(a);await physics_frame
  var points=[]
  for i in range(1500):points.append(Vector3(randf_range(-a.bounds.x-4,a.bounds.x+4),randf_range(-5,23),randf_range(-a.bounds.y-4,a.bounds.y+4)))
  for floor in a.floor_surfaces:
   points.append(floor.pos)
   for sign in [-1,1]:points.append(floor.pos+Vector3(floor.size.x*.5*sign+.0005,0,0))
  for path in a.up_routes:
   for i in range(11):points.append(path.start.lerp(path.end,i/10.))
  for p in points:
   for tolerance in [.1,.5,.7,1.0]:
    assert(a.has_walk_support(p,tolerance)==legacy_support(p,tolerance),"Floor query changed: "+str(map)+" "+str(p));checks+=1
   var original=0;var distance=INF
   for i in range(a.nav_points.size()):
    if a.blocked_nav.has(i):continue
    var d=p.distance_squared_to(a.nav_points[i])
    if d<distance:distance=d;original=i
   assert(a.nearest_nav(p)==original,"Nearest navigation result changed: "+str(map)+" "+str(p));checks+=1
  print("QUERY EQUIVALENCE map=",map," checks=",checks)
  a.queue_free();await process_frame
 print("PASS exact spatial-query equivalence checks=",checks);await create_timer(.2).timeout;quit()
