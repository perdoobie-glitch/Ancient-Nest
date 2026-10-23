extends SceneTree
var a:NestArena
class TraceWorld extends Node3D:
 func trace(start:Vector3,finish:Vector3,mask:int=1,excludes:Array=[])->Dictionary:
  var q=PhysicsRayQueryParameters3D.create(start,finish,mask);var excluded:Array[RID]=[];excluded.assign(excludes);q.exclude=excluded;return get_world_3d().direct_space_state.intersect_ray(q)
func _initialize():call_deferred("run")
func support(p:Vector3)->bool:
 if a.map_selection==2:
  var all_corners=true
  for offset in [Vector2(-.32,-.32),Vector2(-.32,.32),Vector2(.32,-.32),Vector2(.32,.32)]:
   var found=false
   for floor in a.floor_surfaces:
    if absf(floor.pos.y-p.y)<=.5 and absf(p.x+offset.x-floor.pos.x)<=floor.size.x*.5+.001 and absf(p.z+offset.y-floor.pos.z)<=floor.size.y*.5+.001:found=true;break
   if not found:all_corners=false;break
  if all_corners:return true
 for floor in a.floor_surfaces:
  if absf(floor.pos.y-p.y)<=.5 and absf(p.x-floor.pos.x)<=floor.size.x*.5-.32 and absf(p.z-floor.pos.z)<=floor.size.y*.5-.32:return true
 for path in a.up_routes:
  var start=Vector2(path.start.x,path.start.z);var delta=Vector2(path.end.x,path.end.z)-start;var t=(Vector2(p.x,p.z)-start).dot(delta)/delta.length_squared()
  if t>=0 and t<=1 and Vector2(p.x,p.z).distance_to(start+delta*t)<path.width*.5-.32 and absf(p.y-lerpf(path.start.y,path.end.y,t))<=.5:return true
 return false
func legacy(world,start,finish)->bool:
 if absf(start.y-finish.y)>.4:return false
 var count=ceili(start.distance_to(finish)/.5)
 for i in range(1,count+1):
  if not support(start.lerp(finish,float(i)/count)):return false
 for height in [.55,1.45]:
  if not world.trace(start+Vector3.UP*height,finish+Vector3.UP*height,1,[]).is_empty():return false
 return true
func run():
 seed(19013);var world=TraceWorld.new();root.add_child(world);var checks=0
 for map in [0,1,2]:
  a=NestArena.new();a.map_selection=map;world.add_child(a);await physics_frame;await physics_frame
  for i in range(400):
   var floor=a.floor_surfaces[randi()%a.floor_surfaces.size()];var start=floor.pos+Vector3(randf_range(-floor.size.x*.5,floor.size.x*.5),.08,randf_range(-floor.size.y*.5,floor.size.y*.5));var finish=start+Vector3(randf_range(-8,8),0,randf_range(-8,8))
   assert(a.walk_segment_clear(world,start,finish,[])==legacy(world,start,finish),"Shortcut result changed map="+str(map)+" "+str(start)+" -> "+str(finish));checks+=1
  a.queue_free();await process_frame
 print("PASS collision/support shortcut equivalence ",checks," segments across three maps")
 world.queue_free();await create_timer(.2).timeout;quit()
