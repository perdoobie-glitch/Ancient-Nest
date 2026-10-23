class_name NestCharacterCatalog
extends RefCounted
static var entries: Array=[]
static func all() -> Array:
 if entries.is_empty():entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")).characters
 return entries
static func by_id(id: String) -> Dictionary:
 for entry in all():
  if entry.id==id:return entry
 return {}
static func by_index(index: int) -> Dictionary:
 for entry in all():
  if int(entry.index)==index:return entry
 return all()[0]
static func valid_index(index: int) -> bool:
 return all().any(func(entry):return int(entry.index)==index)

static var anatomy_cache: Dictionary={}
static func hitboxes(index: int) -> Array:
 var id=String(by_index(index).id)
 if not anatomy_cache.has(id):
  var document=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+id+"_hitboxes.json"))
  for part in document.regions:
   var shape=ConvexPolygonShape3D.new();var points=PackedVector3Array()
   for point in part.points:points.append(Vector3(point[0],point[1],point[2]))
   shape.points=points
   var planes: Array[Plane]=[]
   for plane in part.planes:planes.append(Plane(Vector3(plane[0],plane[1],plane[2]),-float(plane[3])))
   shape.set_meta("hull_planes",planes)
   shape.set_meta("minimum",Vector3(part.minimum[0],part.minimum[1],part.minimum[2]))
   shape.set_meta("maximum",Vector3(part.maximum[0],part.maximum[1],part.maximum[2]))
   part["shape"]=shape
  anatomy_cache[id]=document.regions
 return anatomy_cache[id]
