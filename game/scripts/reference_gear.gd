class_name NestReferenceGear
extends RefCounted
static var materials: Dictionary={}
static func apply(actor: NestActor) -> void:
 apply_trim(actor.model,actor.character)
 if actor.skeleton==null:return
 var skeleton=actor.skeleton
 var attachment=BoneAttachment3D.new();attachment.bone_name="pelvis" if actor.character==0 else "clavicle_l";skeleton.add_child(attachment)
 var rest=skeleton.get_bone_global_rest(skeleton.find_bone(attachment.bone_name))
 if actor.character==0:
  actor.belt_sword=NestPlasmaSwordArt.create(false);attachment.add_child(actor.belt_sword)
  actor.belt_sword.transform=rest.affine_inverse()*Transform3D(Basis.from_euler(Vector3(-PI*.43,0,.12)),Vector3(.29,.92,.06))
  # An ivory sheath and green hilt make the belt sword readable at rest.
  var kit=actor.game.arena.kit
  kit.box(actor.belt_sword,Vector3(0,0,-.30),Vector3(.065,.047,.48),NestPlasmaSwordArt.shell)
  kit.box(actor.belt_sword,Vector3(0,.026,-.30),Vector3(.014,.012,.44),NestPlasmaSwordArt.green)
 else:
  actor.perched_nu=NestFalconArt.create(true);attachment.add_child(actor.perched_nu)
  actor.perched_nu.transform=rest.affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(-.27,1.58,.055))
  actor.nu_perch_area=NestNuPerch.new();actor.nu_perch_area.owner_actor=actor;actor.perched_nu.add_child(actor.nu_perch_area)

 if actor.belt_sword!=null:NestRigidBatch.build(actor.belt_sword)
 if actor.perched_nu!=null:NestRigidBatch.build(actor.perched_nu)

static func apply_trim(model: Node3D, character: int) -> void:
 NestReferenceSkin.apply(model,character)
