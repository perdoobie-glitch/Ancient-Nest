class_name NestSavannahCanyon
extends RefCounted
# Static distant landform: one opaque material, no collisions, lights or ticks.
const SEGMENTS=144
const PROFILE=[Vector2(0,-7),Vector2(7,-.8),Vector2(9,2.8),Vector2(15,3.2),Vector2(17,10),Vector2(20,11),Vector2(22,17),Vector2(29,17.8),Vector2(31,27),Vector2(35,28.2),Vector2(38,37),Vector2(46,38.5),Vector2(49,46),Vector2(66,47),Vector2(82,39),Vector2(97,-7)]
const COLORS=["b78060","d2a078","a86149","d5a17b","e4ba91","a96247","e1b188","ae644c","e5b895","bd7857","e9c7a4","b97858","dfb38a","c9926e","9b674e"]
static func point(ring:int,sector:int)->Vector3:
 var angle=float(sector%SEGMENTS)*TAU/SEGMENTS
 var ridge=sin(angle*3+.6)*6+sin(angle*7+1.1)*6+sin(angle*13)*1.2
 var radius=80+ridge+PROFILE[ring].x
 var erosion=sin(angle*23+.4)*2.6+sin(angle*41)*.65
 radius+=erosion*(.4 if ring in [0,3,7,11,13,15] else 1.6)
 var height=PROFILE[ring].y
 if height>0:
  var plateau=smoothstep(.2,.78,.5+.5*sin(angle*3+.5))
  var massif=.48+.48*plateau+.075*sin(angle*7+1.8)
  height=height*massif*1.8+sin(angle*9+.3)*minf(1.2,height*.035)
 return Vector3(cos(angle)*radius,height,sin(angle)*radius)
static func build(a:NestArena)->void:
 var material=StandardMaterial3D.new()
 material.resource_name="Savannah canyon shared sandstone"
 material.albedo_texture=load("res://assets/savannah/canyon_rock.png")
 material.albedo_color=Color(.62,.62,.62)
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.roughness=1.0
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ring in range(PROFILE.size()-1):
  st.set_smooth_group(ring)
  for sector in range(SEGMENTS):
   var color=Color(COLORS[ring])
   color=color.lerp(Color("b77a57"),(.5+.5*sin(float(sector)*.19))*.065)
   var points=[point(ring,sector),point(ring,sector+1),point(ring+1,sector),point(ring+1,sector+1)]
   for index in [0,2,1,1,2,3]:
    var p:Vector3=points[index]
    var angle=(float(sector)+float(index%2))*TAU/SEGMENTS
    var terrace=absf(PROFILE[ring+1].y-PROFILE[ring].y)<2
    st.set_uv(Vector2(p.x,p.z)*.09 if terrace else Vector2(angle*96,p.y*1.5)*.10)
    st.set_color(color);st.add_vertex(p)
 st.generate_normals();st.index()
 var mesh=MeshInstance3D.new();mesh.name="SavannahLayeredCanyon";mesh.mesh=st.commit();mesh.material_override=material
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;a.add_child(mesh)
 a.set_meta("savannah_canyon_triangles",SEGMENTS*(PROFILE.size()-1)*2)
 a.set_meta("savannah_canyon_static",true)
static func trim(a:NestArena,paint:Material)->void:
 # Flush bands on existing structures: no new cover, colliders or navigation.
 var k=a.kit
 for side in [-1,1]:
  for z in [-26,-18,-10]:
   k.box(a,Vector3(38*side,1.1,z),Vector3(1.035,.12,1.535),k.gold)
   k.box(a,Vector3(38*side,4.7,z),Vector3(1.035,.055,1.535),k.gold)
   k.box(a,Vector3(38*side,3.25,z),Vector3(1.025,.55,1.525),paint)
  # Matching inset markings retain fair visual treatment at both spawn courts.
  var z=22 if side==-1 else -24
  k.box(a,Vector3(0,3.43,z),Vector3(12.05,.06,.86),k.gold)
  for x in [-4.5,4.5]:
   k.box(a,Vector3(x,1.7,z),Vector3(.14,1.4,.84),paint)
