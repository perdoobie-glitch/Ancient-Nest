class_name NestCampaignShip
extends RefCounted
var w
var origin: Vector3
var white: Material
var gold: Material
var plasma: Material
func _init(world,at: Vector3):
 w=world;origin=at
 white=w.kit.material(Color("eee9d8"),.28);white.roughness=.36
 gold=w.kit.material(Color("c9a352"),.78);gold.roughness=.28
 plasma=w.kit.material(Color("237f59"),.35);plasma.emission_enabled=true;plasma.emission=Color("33df91");plasma.emission_energy_multiplier=.8;plasma.roughness=.2;plasma.cull_mode=BaseMaterial3D.CULL_DISABLED;gold.cull_mode=BaseMaterial3D.CULL_DISABLED
func point(z: float,angle: float,inflate=0.0) -> Vector3:
 var taper=clampf((z+15)/6,.035,1.0)
 return origin+Vector3(cos(angle)*(6+inflate)*taper,.25+sin(angle)*(4.8+inflate)*taper,z)
func patch(z0: float,z1: float,a0: float,a1: float,material: Material,inflate=0.0,solid=false):
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows=8;var columns=16
 for row in range(rows):
  for col in range(columns):
   var za=lerpf(z0,z1,float(row)/rows);var zb=lerpf(z0,z1,float(row+1)/rows)
   var aa=lerpf(a0,a1,float(col)/columns);var ab=lerpf(a0,a1,float(col+1)/columns)
   var a=point(za,aa,inflate);var b=point(zb,aa,inflate);var c=point(za,ab,inflate);var d=point(zb,ab,inflate)
   for vertex in [a,b,c,b,d,c]:
    tool.set_uv(Vector2(vertex.x,vertex.z)*.1);tool.set_smooth_group(0);tool.add_vertex(vertex)
 tool.generate_normals();var mesh=tool.commit();var node=w.kit.mesh(w.scene_root,mesh,Vector3.ZERO,material);node.set_meta("keep_mesh",true);node.name="CurvedHullPanel"
 if solid:
  node.create_trimesh_collision();var body=node.get_child(0);body.collision_layer=1;body.collision_mask=2;body.reparent(w.scene_root,true);body.get_child(0).shape.backface_collision=true
 return node
func ellipsoid(p: Vector3,size: Vector3,material: Material):
 var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=32;shape.rings=12
 var node=w.kit.mesh(w.scene_root,shape,origin+p,material);node.scale=size;return node
func solid_ellipsoid(node: MeshInstance3D):
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;w.scene_root.add_child(body);body.position=node.position;body.rotation=node.rotation
 var shape=ConvexPolygonShape3D.new();var points=PackedVector3Array()
 for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:points.append(vertex*node.scale)
 shape.points=points;var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
func build():
 # Continuous lofted pressure hull, pointed nose and an open rear boarding hatch.
 white.cull_mode=BaseMaterial3D.CULL_DISABLED
 patch(-15,9.2,0,PI,white,0,true)
 # Slim gold strakes follow the curvature, rather than rectangular exterior panels.
 for angle in [.13,PI-.13,.95,PI-.95]:patch(-14,9.25,angle-.035,angle+.035,gold,.025)
 patch(-9.1,-8.7,0,PI,gold,.035)
 patch(8.85,9.2,0,PI,gold,.045)
 # Segmented green plasma glass remains opaque to avoid transparency sorting cost.
 for side in [0,1]:
  var angle=.42 if side==0 else PI-.72
  for z in [-7,-3,1,5]:patch(z,z+2.5,angle,angle+.30,plasma,.06)
 patch(-13,-9.2,.62,PI-.62,plasma,.045)
 for side in [-1,1]:
  # Swept, tapered lenticular wings: smooth profiles with gold leading surfaces.
  var wing=ellipsoid(Vector3(side*12,.8,-2.5),Vector3(6,.48,4.7),white);wing.rotation.y=side*-.22;solid_ellipsoid(wing)
  w.floor_cover.append({"position":origin+Vector3(side*12,.8,-2.5),"size":Vector3(12,1,12)})
  var trim=ellipsoid(Vector3(side*12,.91,-4.8),Vector3(5.5,.13,1.1),gold);trim.rotation.y=side*-.22
  ellipsoid(Vector3(side*8,1.1,-7.3),Vector3(1.25,1.05,4.6),white)
  ellipsoid(Vector3(side*8,1.1,-11.6),Vector3(.85,.72,.3),plasma)
  ellipsoid(Vector3(side*8,1.1,-10.9),Vector3(1.30,1.1,.3),gold)
 # Conservative footprints under the shell exclude routes through its side walls.
 for side in [-1,1]:w.floor_cover.append({"position":origin+Vector3(side*6,1.8,0),"size":Vector3(.6,3.6,18)})
 w.floor_cover.append({"position":origin+Vector3(0,1,-12),"size":Vector3(9,2,6)})
 w.set_meta("curved_ship",true)
