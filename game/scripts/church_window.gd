class_name NestChurchWindow
extends RefCounted
# Original pointed-arch stained glass. Geometry and convex glazing share outline.
const HALF_WIDTH=3.4
const SILL=20.8
const SPRING=35.0
static func outline() -> PackedVector2Array:
 var h=HALF_WIDTH;var points=PackedVector2Array([Vector2(-h,SILL),Vector2(h,SILL)])
 for i in range(13):
  var angle=float(i)/12*PI/3
  points.append(Vector2(-h+2*h*cos(angle),SPRING+2*h*sin(angle)))
 for i in range(11,-1,-1):
  var angle=float(i)/12*PI/3
  points.append(Vector2(h-2*h*cos(angle),SPRING+2*h*sin(angle)))
 return points
static func palette(k: NestKit) -> Array[Material]:
 var result: Array[Material]=[]
 for color in [Color(.10,.29,.43,.68),Color(.10,.39,.33,.66),Color(.25,.20,.37,.66),Color(.52,.34,.12,.66),Color(.40,.16,.18,.66),Color(.15,.35,.39,.66)]:
  var mat=k.material(color,.1);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=.24;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  result.append(mat)
 return result
static func build(parent: Node3D, k: NestKit, colors: Array[Material], variant: int) -> void:
 var edge=outline();var top=SPRING+sqrt(3.0)*HALF_WIDTH
 # Shared clipped cells prevent layered glass overdraw and leave a pointed crown.
 for row in range(7):
  for col in range(4):
   var x0=-HALF_WIDTH+col*HALF_WIDTH*.5;var x1=x0+HALF_WIDTH*.5
   var y0=lerpf(SILL,top,float(row)/7);var y1=lerpf(SILL,top,float(row+1)/7)
   var pieces=Geometry2D.intersect_polygons(edge,PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)]))
   for piece in pieces:
    if piece.size()<3:continue
    var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var vertices=PackedVector3Array();var normals=PackedVector3Array();var ids=PackedInt32Array()
    for v in piece:vertices.append(Vector3(v.x,v.y,0));normals.append(Vector3.FORWARD)
    for i in range(1,piece.size()-1):ids.append_array(PackedInt32Array([0,i,i+1]))
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=ids
    var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    k.mesh(parent,mesh,Vector3.ZERO,colors[(row*2+col+variant)%colors.size()])
 var body=StaticBody3D.new();body.name="SolidStainedGlass";body.collision_layer=1;body.collision_mask=2;body.set_meta("surface_material","concrete");parent.add_child(body)
 var shape=ConvexPolygonShape3D.new();var points=PackedVector3Array()
 for v in edge:
  for z in [-.06,.06]:points.append(Vector3(v.x,v.y,z))
 shape.points=points;var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
 # Bronze tracery follows the curved outer frame. The glazing blocks the inset leads.
 for i in range(edge.size()):
  var start=edge[i];var finish=edge[(i+1)%edge.size()];var delta=finish-start
  var beam=Node3D.new();parent.add_child(beam);beam.position=Vector3((start.x+finish.x)*.5,(start.y+finish.y)*.5,0);beam.rotation.z=atan2(delta.y,delta.x)
  k.box(beam,Vector3.ZERO,Vector3(delta.length()+.04,.16,.28),k.gold,true)
 for col in range(1,4):
  var x=-HALF_WIDTH+col*HALF_WIDTH*.5;var cap=SPRING+sqrt(4*HALF_WIDTH*HALF_WIDTH-pow(absf(x)+HALF_WIDTH,2))
  k.box(parent,Vector3(x,(SILL+cap)*.5,.075),Vector3(.065,cap-SILL,.15),k.dark)
 for row in range(1,7):
  var y=lerpf(SILL,top,float(row)/7);var width=HALF_WIDTH if y<=SPRING else sqrt(4*HALF_WIDTH*HALF_WIDTH-pow(y-SPRING,2))-HALF_WIDTH
  k.box(parent,Vector3(0,y,.075),Vector3(width*2,.055,.15),k.dark)
