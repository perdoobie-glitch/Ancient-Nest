class_name NestBombEnclosures
extends RefCounted
# Coordinates precede the existing uniform arena scale. Keep floor slabs and
# objective positions intact; add collision and navigation exclusions together.
static func build(a) -> void:
 var root=Node3D.new();root.name="BombSiteEnclosures";a.add_child(root)
 # A: a rear sanctuary wall and offset return leave west and south entries.
 wall(a,root,Vector3(19.65,7,0),Vector2(.5,7.5),4.1)
 wall(a,root,Vector3(15.8,7,-3.75),Vector2(8.2,.5),4.1)
 wall(a,root,Vector3(18.1,7,3.75),Vector2(3.6,.5),3.5)
 # Covered west approach uses the existing gap north of the x=10 bearing wall.
 wall(a,root,Vector3(7.8,7,-3.75),Vector2(8,.5),3.5)
 wall(a,root,Vector3(6.65,7,-.9),Vector2(6,.5),3.5)
 roof(a,root,Vector3(7.8,10.65,-2.33),Vector3(8,.3,3.35))
 # B: a split eastern wall gives access to a second, north/south side hallway.
 wall(a,root,Vector3(20.2,0,-2.15),Vector2(.5,6.3),4.2)
 wall(a,root,Vector3(20.2,0,5.3),Vector2(.5,2.6),4.2)
 wall(a,root,Vector3(16.8,0,-5.3),Vector2(7.3,.5),4.2)
 wall(a,root,Vector3(14.5,0,5.5),Vector2(6,.5),3.7)
 wall(a,root,Vector3(24,0,1.3),Vector2(.5,12),3.7)
 roof(a,root,Vector3(22.1,3.85,1.3),Vector3(4.3,.3,12))
 # Bronze bands, doorway jambs and emissive sconces use existing materials,
 # with no additional real-time lights or per-frame effects.
 for p in [Vector3(19.37,7,-2.7),Vector3(19.37,7,2.6),Vector3(20.49,0,-3.6),Vector3(20.49,0,5.6),Vector3(23.72,0,.3)]:
  a.kit.box(root,p+Vector3.UP*2.3,Vector3(.12,.5,.26),a.kit.lamp)
 for p in [Vector3(3.8,7,-3.75),Vector3(3.65,7,-.9),Vector3(24,0,-4.7),Vector3(24,0,7.3)]:
  a.kit.box(root,p+Vector3.UP*1.65,Vector3(.58,3.3,.58),a.kit.gold,true)
  a.floor_cover.append({"pos":p,"size":Vector2(.58,.58)})
 # Optional precision routes sit beside ordinary entries, never across them.
 skill_step(a,root,Vector3(5.8,7,.5),Vector2(1.6,1.5),1.2)
 skill_step(a,root,Vector3(8.9,7,.5),Vector2(1.25,1.25),2.65)
 skill_step(a,root,Vector3(25.5,0,-.5),Vector2(1.4,1.4),2.7)
 skill_step(a,root,Vector3(25.1,0,-5.6),Vector2(1.5,1.5),4.0)
 # Outboard roof lip gives standing clearance beside the middle-floor slab.
 roof(a,root,Vector3(24.8,3.875,-3.8),Vector3(1.8,.25,1.8))
static func skill_step(a,root: Node3D,pos: Vector3,size: Vector2,height: float) -> void:
 # Solid stone pedestals avoid false cover or walk-through decorative geometry.
 a.kit.box(root,pos+Vector3.UP*height*.5,Vector3(size.x,height,size.y),a.kit.stone,true)
 a.kit.box(root,pos+Vector3.UP*(height-.05),Vector3(size.x,.08,size.y),a.kit.gold)
 a.floor_cover.append({"pos":pos,"size":size})
 a.floor_surfaces.append({"pos":pos+Vector3.UP*height,"size":size})
static func wall(a,root: Node3D,pos: Vector3,size: Vector2,height: float) -> void:
 a.kit.box(root,pos+Vector3.UP*height*.5,Vector3(size.x,height,size.y),a.kit.stone,true)
 # Keep the trim inside the solid footprint so there is no visible false cover.
 a.kit.box(root,pos+Vector3.UP*(height-.12),Vector3(size.x,.18,size.y),a.kit.gold)
 a.floor_cover.append({"pos":pos,"size":size})
static func roof(a,root: Node3D,pos: Vector3,size: Vector3) -> void:
 a.kit.box(root,pos,size,a.kit.stone,true)
 a.kit.box(root,pos+Vector3.UP*.16,Vector3(size.x,.04,size.z),a.kit.gold)
 a.floor_surfaces.append({"pos":pos+Vector3.UP*size.y*.5,"size":Vector2(size.x,size.z)})
