class_name NestGunFeedback
extends RefCounted
const STYLES={
 "rifle":["ffc85e",5,.075,.16],"ak47":["ff792e",4,.065,.23],
 "burst":["fff0b0",3,.055,.18],"burst_scoped":["a9dcff",6,.04,.20],
 "sidearm":["ffe69a",4,.045,.10],"sniper":["ff9b35",3,.032,.31],
 "shotgun":["ffb265",8,.11,.12],"rocket":["d6f7ad",6,.10,.27],
 "plasma_pistol":["35ed89",2,.025,.11],"plasma_br":["52ed72",2,.065,.19],"plasma_auto":["52ed72",3,.052,.12],"plasma_smg":["52ed72",3,.04,.10],"plasma_sniper":["7aff98",2,.04,.30],"smg":["ffc47c",4,.055,.12]}
static var kit: NestKit
static var mats: Dictionary={}
static func prepare(root: Node3D, kind: String) -> void:
 if root==null or kind in ["none","plasma_sword"] or root.has_meta("gun_feedback"):return
 if kit==null:kit=NestKit.new()
 var style=STYLES.get(kind,STYLES.rifle)
 if not mats.has(kind):
  var m=kit.material(Color(style[0]));m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.emission_enabled=true;m.emission=Color(style[0]);m.emission_energy_multiplier=2.5;mats[kind]=m
 # Plasma uses its visible rear stock face. Long ballistic stocks extend off
 # screen, so their displays mount on the receiver side. Bounds run once per art.
 var rear=AABB(Vector3.ZERO,Vector3.ZERO);var found=false;var receiver_left=-.10
 for item in root.find_children("*","MeshInstance3D",true,false):
  var box=(root.global_transform.affine_inverse()*item.global_transform)*item.get_aabb()
  if not found or box.end.z>rear.end.z:rear=box;found=true
  if box.position.z<=-.06 and box.end.z>=-.06 and box.position.y<=.055 and box.end.y>=.055:receiver_left=minf(receiver_left,box.position.x)
 var plasma=kind.begins_with("plasma")
 var mount_angle=0.0 if plasma else -.65
 var normal=Basis(Vector3.UP,mount_angle)*Vector3.BACK
 var mount=Vector3(rear.get_center().x,rear.get_center().y,rear.end.z+.012) if plasma else Vector3(receiver_left-.045,.055,-.06)
 var plate=kit.box(root,mount,Vector3(.066,.038,.009),kit.dark);plate.rotation.y=mount_angle;plate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var number=Label3D.new();number.name="GunAmmoCounter";number.position=mount+normal*.006;number.rotation.y=mount_angle;number.pixel_size=.00085;number.font_size=32;number.outline_size=2;number.modulate=Color("b8f1bd");number.outline_modulate=Color("101915");number.shaded=false;number.no_depth_test=false;number.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(number)
 var flash=Node3D.new();flash.name="UniqueMuzzle_"+kind;root.add_child(flash)
 flash.position.z={"plasma_pistol":-.39,"sidearm":-.15,"sniper":-.65,"ak47":-.52,"rocket":-.39,"burst_scoped":-.47,"plasma_br":-.50,"plasma_auto":-.50}.get(kind,-.43)
 if kind.begins_with("plasma"):
  for i in range(int(style[1])):
   var mesh=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=float(style[2])*.6;torus.outer_radius=float(style[2]);torus.rings=16;torus.ring_segments=4;mesh.mesh=torus;mesh.material_override=mats[kind];mesh.rotation.x=PI*.5;mesh.position.z=-i*.035;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;flash.add_child(mesh)
 else:
  for i in range(int(style[1])):
   var angle=TAU*i/int(style[1]);var ray=kit.box(flash,Vector3(sin(angle)*float(style[2])*.45,cos(angle)*float(style[2])*.45,-float(style[3])*.25),Vector3(.014,.014,float(style[3])),mats[kind]);ray.rotation=Vector3(cos(angle)*.4,sin(angle)*.4,angle);ray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var center=kit.sphere(flash,Vector3(0,0,-.025),.025,mats[kind]);center.scale.z=2.0;center.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 flash.visible=false;root.set_meta("gun_feedback",{"ammo":number,"flash":flash,"last_ammo":-1,"kind":kind})
static func update(root: Node3D, actor, age: float, local: bool=false) -> void:
 if root==null or not root.has_meta("gun_feedback"):return
 var f: Dictionary=root.get_meta("gun_feedback");var count=actor.ammo[actor.slot]
 if count!=int(f.last_ammo):f.ammo.text=str(count);f.last_ammo=count
 f.ammo.visible=actor.alive and (local or actor.game.now>=actor.cloak_deadline)
 f.flash.visible=actor.alive and ((local and actor.flash_render_pending) or (age>=0 and age<(.065 if local else .12)))
 if not f.flash.visible:return
 f.flash.rotation.z=sin(age*110)*.24 if age>=0 else 0
 f.flash.scale=Vector3.ONE*(.8+.2*cos(age*95))*(1.0 if local else 1.8) if age>=0 else Vector3.ONE
