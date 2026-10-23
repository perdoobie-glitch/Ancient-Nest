extends SceneTree
func _initialize():call_deferred("run")
func support(points:PackedVector3Array,direction:Vector3,basis:Basis)->float:
 var best=-INF
 for point in points:best=maxf(best,(basis*point).dot(direction))
 return best
func run():
 var rng=RandomNumberGenerator.new();rng.seed=1011001
 var checks=0;var max_error=0.;var raw_total=0;var compact_total=0
 for radius in [.8,2.35]:
  for height in [.24,2.3]:
   for basis in [Basis.from_scale(Vector3(1.1475,.85,.85)),Basis.from_scale(Vector3(.85,.85,1.1475)),Basis.from_scale(Vector3(1.1475,.85,.85))*Basis.from_euler(Vector3(.2,.7,.1))]:
    var cylinder=CylinderShape3D.new();cylinder.radius=radius;cylinder.height=height
    var original=PackedVector3Array();var mesh=cylinder.get_debug_mesh()
    for surface in range(mesh.get_surface_count()):original.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
    var compact=NestArena.stretched_cylinder_points(cylinder,basis)
    assert(compact.size()<=256 and compact.size()>=128)
    raw_total+=original.size();compact_total+=compact.size()
    for sample in range(96):
     var direction=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
     var error=absf(support(original,direction,basis)-support(compact,direction,basis))
     max_error=maxf(max_error,error)
     assert(error<=NestArena.STRETCHED_CYLINDER_ERROR_M+.00001,"Collider exceeded world-space approximation budget")
     checks+=1
 var giant=CylinderShape3D.new();giant.radius=100
 assert(NestArena.stretched_cylinder_points(giant,Basis.IDENTITY).size()>256,"Oversized geometry keeps legacy representation")
 print("STRETCHED COLLIDERS: ",checks," support checks; max error ",max_error,"m; raw points ",raw_total," -> ",compact_total)
 call_deferred("quit")
