class_name NestMapPolish
extends RefCounted
## Shared surface/readability pass. No movement collision or route changes.
static func apply(arena: NestArena) -> Dictionary:
 var details=Node3D.new();details.name="MapReadabilityDetails";arena.add_child(details)
 var gold=arena.kit.gold;var dark=arena.kit.dark
 var marker_count=0
 # Grounded objective rings remain readable without floating navigation paragraphs.
 for index in range(arena.sites.size()):
  var pos: Vector3=arena.sites[index]
  var ink=arena.kit.material(Color("bda46f") if index==0 else Color("7aa69d"),.25)
  for side in [-1,1]:
   arena.kit.box(details,pos+Vector3(side*2.6,.035,0),Vector3(.12,.035,2.8),ink)
   arena.kit.box(details,pos+Vector3(0,.035,side*2.6),Vector3(2.8,.035,.12),ink);marker_count+=2
 # Keep faction spawn aprons unmistakable with flush contrasting inlays.
 for team in arena.spawns:
  var points: Array=arena.spawns[team]
  if points.is_empty():continue
  # A real authored spawn is supported; averaging different floors can float.
  var center: Vector3=points[0]
  var ink=arena.kit.material(Color("598466") if int(team)==0 else Color("94534b"))
  for x in [-.6,0,.6]:arena.kit.box(details,center+Vector3(x,-.065,0),Vector3(.20,.025,1.1),ink);marker_count+=1
 for mesh in arena.find_children("*","MeshInstance3D",true,false):
  # Decals/details don't pay for shadows. Solid cover retains normal shadowing.
  if mesh.get_parent()==details:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return {"flush_inlays":marker_count,"collision_added":0,"routes_changed":0}
