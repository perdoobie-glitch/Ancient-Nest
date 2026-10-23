class_name NestRoundMap
extends RefCounted
# Requested targeted changes. Existing floor plans and remaining routes stay intact.
static func build(a: NestArena) -> void:
 var k=a.kit
 var wall=Node3D.new();wall.name="EastRampOuterWall";a.add_child(wall)
 var points=PackedVector3Array()
 for z in [-6.25,6.25]:
  var base=9.0+(z+6.0)*5.0/12.0-.12
  for y in [base,base+3.0]:
   for x in [48.95,49.30]:points.append(Vector3(x,y,z))
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in [[0,2,3,1],[4,5,7,6],[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]:
  for index in [0,1,2,0,2,3]:surface.add_vertex(points[face[index]])
 surface.generate_normals();var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=k.stone;wall.add_child(mesh)
 var body=StaticBody3D.new();body.name="SolidOuterRampWall";var collision=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=points;collision.shape=shape;body.add_child(collision);wall.add_child(body)
 # A bronze cap follows the incline, with vertical supports at its ends.
 k.branch(wall,Vector3(49.12,12.9,-6.2),Vector3(49.12,18.1,6.2),.065,k.gold)
 for z in [-6.1,6.1]:
  var base=9+(z+6)*5/12
  k.box(wall,Vector3(49.12,base+1.45,z),Vector3(.5,3.1,.38),k.stone,true)
 # Low asymmetric cover and jumpable masonry on supported top-floor decks.
 var top=Node3D.new();top.name="TopFloorCoverDetails";a.add_child(top)
 NestSanctuaryLayout.wall(a,Vector3(28,14,3.3),Vector2(5,.5),1.3)
 NestSanctuaryLayout.wall(a,Vector3(-26.3,14,-19.0),Vector2(.5,3.0),1.65)
 NestSanctuaryLayout.cover(a,Vector3(37,14,7),Vector2(2.2,1.2))
 k.box(top,Vector3(-25.1,14.325,-19.0),Vector3(1.4,.65,1.7),k.stone,true)
 k.box(top,Vector3(-25.1,14.67,-19.0),Vector3(1.46,.05,1.76),k.gold)
 a.floor_cover.append({"pos":Vector3(-25.1,14,-19.0),"size":Vector2(1.4,1.7)})
 a.floor_surfaces.append({"pos":Vector3(-25.1,14.65,-19.0),"size":Vector2(1.4,1.7)})
 for pos in [Vector3(25.8,14.7,3.0),Vector3(30.2,14.7,3.0),Vector3(-25.2,15.,-25.82),Vector3(-21.8,15.,-25.82)]:
  k.box(top,pos,Vector3(.14,.35,.12),k.lamp)

 # Glass partitions have solid collision and clear passages around their ends.
 var glass=k.material(Color(.32,.67,.78,.30));glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=.2;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 for spec in [[Vector3(32.5,14,11.5),Vector2(4.5,.22)],[Vector3(35,14,5),Vector2(3.4,.22)]]:
  var pos: Vector3=spec[0];var size: Vector2=spec[1]
  k.box(top,pos+Vector3.UP*1.5,Vector3(size.x,3.0,size.y),glass,true)
  for side in [-1,1]:k.box(top,pos+Vector3(side*size.x*.5,1.5,0),Vector3(.13,3.15,.3),k.gold,true)
  k.box(top,pos+Vector3.UP*3.04,Vector3(size.x+.1,.13,.3),k.gold)
  a.floor_cover.append({"pos":pos,"size":size})
 # Bottom-floor wedge ramps lead to broad low cover decks, with open approaches.
 a.floor_at(-25,1.2,10,Vector2(4.5,4.2))
 a.up_route("BOTTOM WEST LOW RAMP",Vector3(-25,0,17),Vector3(-25,1.2,12),3.2)
 a.up_route("BOTTOM WEST RETURN RAMP",Vector3(-25,0,5.5),Vector3(-25,1.2,8),3.2)
 a.floor_at(29,1.1,-10,Vector2(4.5,4.0))
 a.up_route("BOTTOM EAST LOW RAMP",Vector3(29,0,-17),Vector3(29,1.1,-12),3.2)
