class_name NestReferenceSkin
extends RefCounted
## Shared reference-inspired finishes. No collision or per-frame work.
static var finishes: Dictionary = {}
static var grain: Texture2D
static var weave: Texture2D
# Immutable geometry shared between characters; each instance owns its visibility.
static var detail_templates: Dictionary = {}

static func finish(kind: String) -> StandardMaterial3D:
 if finishes.has(kind):return finishes[kind]
 var m=StandardMaterial3D.new();m.resource_name="reference_"+kind
 var colors={"ivory":"dde3d9","graphite":"171d22","uniform":"22272a","olive":"49452b","crimson":"8e1820","green":"4be36f","gold":"c69a42","red":"b62329","face":"b68869","glass":"101b20"}
 m.albedo_color=Color(colors[kind]);m.roughness=.65
 if kind in ["ivory","graphite","gold","red"]:
  m.metallic=.35 if kind!="gold" else .78;m.roughness=.34 if kind!="gold" else .27
 if kind in ["green","glass"]:
  m.metallic=.35;m.roughness=.22
 if kind=="green":
  m.emission_enabled=true;m.emission=Color("19dc65");m.emission_energy_multiplier=.65
 if kind not in ["green","glass","face"]:
  var fabric=kind in ["uniform","olive","crimson"]
  m.albedo_texture=surface_grain(fabric)
  m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*(10 if fabric else 4)
 finishes[kind]=m
 return m

static func surface_grain(fabric: bool) -> Texture2D:
 if fabric and weave!=null:return weave
 if not fabric and grain!=null:return grain
 # Generate the two tiny shared textures synchronously during loading.
 # No background texture-generation jobs survive into combat or teardown.
 var noise=FastNoiseLite.new();noise.seed=341 if fabric else 781;noise.frequency=.25 if fabric else .08;noise.fractal_octaves=2
 var values=noise.get_seamless_image(128,128)
 var pixels=Image.create(128,128,false,Image.FORMAT_RGB8)
 var minimum=.76 if fabric else .88
 for y in range(128):
  for x in range(128):
   var brightness=lerpf(minimum,1.0,values.get_pixel(x,y).r)
   pixels.set_pixel(x,y,Color(brightness,brightness,brightness))
 var texture=ImageTexture.create_from_image(pixels)
 if fabric:weave=texture
 else:grain=texture
 return texture

static func apply(model: Node3D, character: int) -> void:
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  for surface in range(mesh.mesh.get_surface_count()):
   var original=mesh.mesh.surface_get_material(surface)
   if not original is StandardMaterial3D:continue
   var name=original.resource_name.to_lower();var kind=""
   if "armor_ivory" in name:kind="ivory"
   elif "armor_charcoal" in name:kind="graphite"
   elif "undersuit" in name:kind="graphite"
   elif "uniform" in name:kind="uniform"
   elif "cloth_olive" in name:kind="olive"
   elif "cloth_crimson" in name:kind="crimson"
   elif "trim" in name or "brass" in name:kind="green" if character==0 else "red"
   elif "visor" in name:kind="green"
   elif "glass" in name:kind="glass"
   elif "face" in name:kind="face"
   if kind!="":
    var replacement=finish(kind)
    # Keep material names for the existing trim/cloak presentation code.
    var key=str(original.get_instance_id())+"/"+kind
    if not finishes.has(key):
     var named=replacement.duplicate();named.resource_name=original.resource_name;named.cull_mode=original.cull_mode;finishes[key]=named
    mesh.set_surface_override_material(surface,finishes[key])
 if model.has_meta("reference_skin_details"):return
 var skeletons=model.find_children("*","Skeleton3D",true,false)
 if skeletons.is_empty():return
 model.set_meta("reference_skin_details",true)
 var skeleton: Skeleton3D=skeletons[0]
 if detail_templates.has(character):
  for bone in detail_templates[character]:
   var detail_root=mount(skeleton,bone)
   for entry in detail_templates[character][bone]:
    var detail=MeshInstance3D.new();detail.mesh=entry.mesh;detail.transform=entry.transform
    detail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;detail_root.add_child(detail)
  return
 if character==0:
  var chest=mount(skeleton,"chest")
  # Gold borders follow the armor, green inlays retain the faction's identity.
  for side in [-1.0,1.0]:
   line(chest,Vector3(side*.035,1.405,-.162),Vector3(side*.155,1.405,-.162),"gold",.008)
   line(chest,Vector3(side*.155,1.405,-.162),Vector3(side*.201,1.335,-.171),"gold",.008)
   line(chest,Vector3(side*.201,1.335,-.171),Vector3(side*.171,1.215,-.171),"gold",.008)
   var arm=mount(skeleton,"upperarm_"+("r" if side>0 else "l"))
   gem(arm,Vector3(side*.29,1.419,-.108),.019)
   var head=mount(skeleton,"head")
   line(head,Vector3(side*.077,1.85,-.146),Vector3(side*.052,1.79,-.149),"gold",.006)
  gem(chest,Vector3(0,1.302,-.179),.023)
  var waist=mount(skeleton,"pelvis");gem(waist,Vector3(0,.966,-.166),.012)
 else:
  var chest=mount(skeleton,"chest")
  for side in [-1.0,1.0]:
   # Red segmented harness panels and shoulder marks match the cover palette.
   line(chest,Vector3(side*.135,1.392,-.18),Vector3(side*.081,1.189,-.18),"red",.012)
   for row in range(3):
    line(chest,Vector3(side*.065,1.30-row*.045,-.183),Vector3(side*.115,1.30-row*.045,-.183),"graphite",.009)
   var arm=mount(skeleton,"upperarm_"+("r" if side>0 else "l"))
   line(arm,Vector3(side*.255,1.429,-.112),Vector3(side*.323,1.40,-.112),"red",.01)
   line(arm,Vector3(side*.277,1.40,-.117),Vector3(side*.327,1.375,-.117),"red",.006)

 # Only combine opaque trim on the same bone with the same material. Skinned
 # bodies, moving weapons, shields and hitboxes are outside these roots.
 var template: Dictionary={}
 for attachment in skeleton.get_children():
  if not String(attachment.name).begins_with("CoverSkin_"):continue
  var detail_root=attachment.get_child(0)
  NestRigidBatch.build(detail_root)
  var entries: Array=[]
  for detail in detail_root.get_children():
   if detail is MeshInstance3D:entries.append({"mesh":detail.mesh,"transform":detail.transform})
  template[String(detail_root.get_meta("skin_bone"))]=entries
 detail_templates[character]=template

static func mount(skeleton: Skeleton3D, bone: String) -> Node3D:
 # Multiple ornaments on the same bone share one attachment and transform.
 var existing=skeleton.get_node_or_null("CoverSkin_"+bone)
 if existing!=null:return existing.get_child(0)
 var attachment=BoneAttachment3D.new();attachment.name="CoverSkin_"+bone;attachment.bone_name=bone;skeleton.add_child(attachment)
 var root=Node3D.new();root.set_meta("skin_bone",bone);attachment.add_child(root)
 root.transform=skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse()
 return root

static func line(parent: Node3D, a: Vector3, b: Vector3, kind: String, radius: float) -> void:
 a=fitted_position(parent,a);b=fitted_position(parent,b)
 var mesh=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=6;shape.rings=1;shape.material=finish(kind);mesh.mesh=shape
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);mesh.position=(a+b)*.5
 mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

static func gem(parent: Node3D, position: Vector3, radius: float) -> void:
 position=fitted_position(parent,position)
 var rim=MeshInstance3D.new();var ring=CylinderMesh.new();ring.top_radius=radius*1.32;ring.bottom_radius=radius*1.32;ring.height=.008;ring.radial_segments=12;ring.material=finish("gold");rim.mesh=ring;parent.add_child(rim);rim.position=position;rim.rotation.x=PI*.5;rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var gem=MeshInstance3D.new();var stone=SphereMesh.new();stone.radius=radius;stone.height=radius*2;stone.radial_segments=8;stone.rings=4;stone.material=finish("green");gem.mesh=stone;parent.add_child(gem);gem.position=position+Vector3(0,0,-.007);gem.scale.z=.45;gem.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func fitted_position(parent: Node3D, point: Vector3) -> Vector3:
 var bone=String(parent.get_meta("skin_bone",""));var p=point
 if bone in ["pelvis","spine_01","chest"]:
  p.x*=.96-.14*exp(-pow((p.y-1.055)/.13,2))-.065*exp(-pow((p.y-1.36)/.16,2))
  p.z*=.96-.06*exp(-pow((p.y-1.08)/.11,2))
 elif bone.begins_with("upperarm_"):
  var side=1.0 if bone.ends_with("_r") else -1.0;var t=clampf((1.42-p.y)/.27,0,1);var center=side*(.25+.11*t)
  p.x=center+(p.x-center)*.82-side*.012*exp(-pow((p.y-1.42)/.12,2));p.z*=.86
 return p
