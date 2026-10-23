class_name NestWeaponArt
extends RefCounted
static var scenes: Dictionary = {}
static var materials: Dictionary = {}
static func create(kind: String, faction: int) -> Node3D:
	if kind=="burst":kind="burst_scoped"
	if kind=="none": return Node3D.new()
	if kind=="knife":return NestKnifeArt.create()
	if kind=="plasma_sword":return NestPlasmaSwordArt.create()
	if kind in ["smg","plasma_pistol","plasma_br","plasma_auto","plasma_smg","plasma_sniper"]:return NestReferenceArsenal.create(kind)
	if not kind in ["rifle","ak47","burst","burst_scoped","sidearm","sniper","rocket","shotgun"]: kind="rifle"
	if not scenes.has(kind): scenes[kind]=load("res://models/Weapon_"+kind+".glb")
	var model: Node3D=scenes[kind].instantiate()
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var original=mesh.mesh.surface_get_material(i)
			if original==null: continue
			var key=str(original.get_instance_id())+":"+str(faction)+":"+kind
			if not materials.has(key):
				var mat=original.duplicate()
				var name=original.resource_name.to_lower()
				var relic=kind in ["shotgun","rocket"]
				if "shell" in name or "stock" in name:mat.albedo_color=Color("c6b384") if relic else Color("8c292d")
				elif "trim" in name or "brass" in name:mat.albedo_color=Color("bc9e60")
				elif "glow" in name or "lens" in name:mat.albedo_color=Color("6fcbef") if relic else Color("da9b74")
				else:mat.albedo_color=Color("242a2d")
				materials[key]=mat
			mesh.set_surface_override_material(i,materials[key])
	model.scale=Vector3(.935,.935,1.0625) if kind=="rocket" else Vector3.ONE*.85
	if kind=="rocket":NestRocketArt.add_reload(model)
	if kind=="sniper":NestSniperCycle.add_bolt(model)
	return model
