class_name NestArenaQueryIndex
extends RefCounted
# Exact broad-phase only: final floor/nearest tests retain the authored geometry.
const CELL:float=8.0
var floors:Dictionary={}
var navigation:Dictionary={}
var point_count:int=0
var floor_count:int=0
var ready:bool=false
var low:Vector2i
var high:Vector2i
func cell(p:Vector3)->Vector2i:return Vector2i(floori(p.x/CELL),floori(p.z/CELL))
func rebuild(points:Array[Vector3],surfaces:Array[Dictionary],merge_strips:bool=false)->void:
 floors.clear();navigation.clear();point_count=points.size();floor_count=surfaces.size();ready=false
 var query_surfaces=merge_floors(surfaces) if merge_strips else surfaces
 for slab in query_surfaces:
  var half:Vector2=slab.size*.5
  var first=Vector2i(floori((slab.pos.x-half.x-.001)/CELL),floori((slab.pos.z-half.y-.001)/CELL))
  var last=Vector2i(floori((slab.pos.x+half.x+.001)/CELL),floori((slab.pos.z+half.y+.001)/CELL))
  for x in range(first.x,last.x+1):
   for z in range(first.y,last.y+1):
    var key=Vector2i(x,z)
    if not floors.has(key):floors[key]=[]
    floors[key].append(slab)
 for i in range(points.size()):
  var key=cell(points[i])
  if not navigation.has(key):navigation[key]=[]
  navigation[key].append(i)
  if i==0:low=key;high=key
  else:low=low.min(key);high=high.max(key)
 ready=true
func floor_at(p:Vector3,tolerance:float,inset:float)->bool:
 for slab in floors.get(cell(p),[]):
  if absf(slab.pos.y-p.y)<=tolerance and absf(p.x-slab.pos.x)<=slab.size.x*.5-inset and absf(p.z-slab.pos.z)<=slab.size.y*.5-inset:return true
 return false
func nearest(p:Vector3,points:Array[Vector3],ignored:Dictionary={})->int:
 var origin=cell(p);var best=0;var distance=INF
 # Distant/airborne editor queries are rare; the original exact scan is bounded and cheaper there.
 if origin.x<low.x-2 or origin.x>high.x+2 or origin.y<low.y-2 or origin.y>high.y+2:
  for i in range(points.size()):
   if ignored.has(i):continue
   var d=p.distance_squared_to(points[i])
   if d<distance:distance=d;best=i
  return best
 var limit=maxi(maxi(absi(origin.x-low.x),absi(origin.x-high.x)),maxi(absi(origin.y-low.y),absi(origin.y-high.y)))
 for radius in range(limit+1):
  for x in range(origin.x-radius,origin.x+radius+1):
   for z in range(origin.y-radius,origin.y+radius+1):
    if radius>0 and absi(x-origin.x)!=radius and absi(z-origin.y)!=radius:continue
    for i in navigation.get(Vector2i(x,z),[]):
     if ignored.has(i):continue
     var d=p.distance_squared_to(points[i])
     if d<distance or (d==distance and i<best):distance=d;best=i
  var edge=minf(minf(p.x-(origin.x-radius)*CELL,(origin.x+radius+1)*CELL-p.x),minf(p.z-(origin.y-radius)*CELL,(origin.y+radius+1)*CELL-p.z))
  # Unsearched points lie outside this XZ square; vertical distance cannot make them closer.
  if distance<edge*edge:break
 return best

func merge_floors(surfaces:Array[Dictionary])->Array[Dictionary]:
 var groups={};var result:Array[Dictionary]=[]
 for slab in surfaces:
  var key=Vector3(slab.pos.x,slab.pos.y,slab.size.x)
  if not groups.has(key):groups[key]=[]
  groups[key].append(slab)
 for key in groups:
  var strips=groups[key];strips.sort_custom(func(a,b):return a.pos.z-a.size.y*.5<b.pos.z-b.size.y*.5)
  var first=float(strips[0].pos.z-strips[0].size.y*.5);var last=float(strips[0].pos.z+strips[0].size.y*.5)
  for i in range(1,strips.size()+1):
   if i<strips.size() and strips[i].pos.z-strips[i].size.y*.5<=last+.000001:
    last=maxf(last,strips[i].pos.z+strips[i].size.y*.5);continue
   result.append({"pos":Vector3(key.x,key.y,(first+last)*.5),"size":Vector2(key.z,last-first)})
   if i<strips.size():first=strips[i].pos.z-strips[i].size.y*.5;last=strips[i].pos.z+strips[i].size.y*.5
 return result
func segment_on_floor(start:Vector3,finish:Vector3)->bool:
 for slab in floors.get(cell(start),[]):
  if absf(slab.pos.y-start.y)>.5 or absf(slab.pos.y-finish.y)>.5:continue
  var half:Vector2=slab.size*.5-Vector2.ONE*.32
  if absf(start.x-slab.pos.x)<=half.x and absf(start.z-slab.pos.z)<=half.y and absf(finish.x-slab.pos.x)<=half.x and absf(finish.z-slab.pos.z)<=half.y:return true
 return false
