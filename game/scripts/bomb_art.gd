class_name NestBombArt
extends RefCounted
static func create(kit: NestKit) -> Node3D:
 var root=Node3D.new();root.name="YellowBombBackpack"
 var yellow=kit.material(Color("e3b72b"));var strap=kit.material(Color("463f27"))
 kit.box(root,Vector3.ZERO,Vector3(.36,.46,.18),yellow)
 kit.box(root,Vector3(0,-.09,-.11),Vector3(.28,.16,.08),yellow)
 for x in [-.13,.13]:kit.box(root,Vector3(x,0,.105),Vector3(.035,.49,.035),strap)
 kit.box(root,Vector3(0,.06,-.102),Vector3(.13,.09,.025),kit.dark)
 kit.box(root,Vector3(0,.06,-.12),Vector3(.09,.035,.01),kit.lamp)
 return root
