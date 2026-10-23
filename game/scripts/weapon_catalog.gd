class_name NestWeaponCatalog
extends RefCounted
static var document: Dictionary = {}
static var profiles: Dictionary = {}
static var definition_cache: Dictionary={}
static var kind_cache: Dictionary={}
static var missing_feedback: Dictionary = {}
static func data() -> Dictionary:
	if document.is_empty(): document = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	return document
static func definition(id: String) -> Dictionary:
	if id=="battle_rifle":id="battle_rifle_scoped" # migrate older saved loadouts
	if definition_cache.has(id):return definition_cache[id]
	for item in data().weapons:
		if item.id == id:
			var result: Dictionary = definition(item.inherits).duplicate(true) if item.has("inherits") else {}
			result.merge(item, true)
			result.make_read_only();definition_cache[id]=result
			return result
	return {}
static func for_kind(kind: String) -> Dictionary:
	if kind=="burst":kind="burst_scoped"
	if kind_cache.has(kind):return kind_cache[kind]
	for item in data().weapons:
		if item.kind == kind:
			kind_cache[kind]=definition(item.id);return kind_cache[kind]
	return {}
static func choices(slot: String) -> Array:
	return data().weapons.filter(func(item): return item.slot == slot or (slot == "secondary" and item.slot == "primary"))
static func profile(id_or_kind: String) -> NestWeapon:
	if profiles.has(id_or_kind): return profiles[id_or_kind]
	if id_or_kind=="plasma_sword":
		var sword=NestWeapon.new();sword.kind="plasma_sword";sword.title="Nexus Blade";sword.damage=100000;sword.magazine=1;sword.reserve=0;sword.automatic=false;sword.interval=.7;profiles[id_or_kind]=sword;return sword
	var config = definition(id_or_kind)
	if config.is_empty(): config = for_kind(id_or_kind)
	var result = NestWeapon.new()
	if config.is_empty():
		result.kind="none"; result.title="Unarmed"; result.magazine=0; result.reserve=0; result.automatic=false; result.damage=0
	else:
		for property in ["kind","title","damage","magazine","reserve","interval","spread_degrees","spread_half_angle_deg","reload_seconds","speed","precision","automatic","pellets","max_range","explosive","plasma"]:
			if config.has(property): result.set(property, config[property])
		result.spread_half_angle_deg=NestWeaponAccuracy.cone(config)
		if config.has("plasma_color"):result.plasma_color=Color(config.plasma_color)
		if config.has("fire_rate_rpm") and config.get("burst_count",1)<=1: result.interval=60.0/float(config.fire_rate_rpm)
		elif config.get("burst_count",1)>1: result.interval=float(config.burst_delay)+float(config.burst_interval)*(int(config.burst_count)-1)
		if config.has("reload_stages") and config.has("fire_sound"):prepare_feedback(result,config)
	profiles[id_or_kind] = result
	return result
static func loadout(faction: int, primary: String, secondary: String) -> Array[NestWeapon]:
	var defaults: Array = data().defaults.faction_loadouts["naki" if faction==0 else "annu"]
	var ids: Array = []
	if primary == "default": ids.append_array(defaults.filter(func(id): return definition(id).slot=="primary"))
	elif primary != "none" and not definition(primary).is_empty(): ids.append(primary)
	if secondary == "default": ids.append_array(defaults.filter(func(id): return definition(id).slot=="secondary"))
	elif secondary != "none" and not definition(secondary).is_empty(): ids.append(secondary)
	var result: Array[NestWeapon] = []
	for id in ids:
		result.append(profile(id))
	if result.is_empty(): result.append(profile("none"))
	if faction==0:result.append(profile("plasma_sword"))
	return result

static func feedback_stream(path: String, fallback: String) -> AudioStream:
	if ResourceLoader.exists(path):return load(path) as AudioStream
	if not missing_feedback.has(path):
		missing_feedback[path]=true;push_warning("Missing weapon audio: %s. Using type fallback."%path)
	return load(fallback) as AudioStream if ResourceLoader.exists(fallback) else null
static func prepare_feedback(weapon: NestWeapon, config: Dictionary) -> void:
	var id=String(config.get("audio_profile",config.id));var folder="res://audio/sfx/weapons/"+id+"/"
	var generic={"sidearm":"magnum","shotgun":"shotgun","sniper":"sniper_rifle","rocket":"rocket_launcher"}.get(weapon.kind,"assault_rifle")
	var fallback="res://audio/weapons/"+generic+"/"+generic
	for index in range(1,4):
		var stream=feedback_stream(folder+"shot_%d.ogg"%index,fallback+"_fire_crack_01.ogg")
		if stream!=null:weapon.shot_sounds.append(stream)
	weapon.distant_sound=feedback_stream(folder+"shot_distant.ogg",fallback+"_fire_distant_01.ogg")
	weapon.dry_fire_sound=feedback_stream(folder+"dry_fire.ogg",fallback+"_dry_fire_01.ogg")
	var reload_fallback="res://audio/weapons/"+id+"/"+String(config.reload_stages[0].id)+"_01.ogg"
	weapon.reload_sound=feedback_stream(folder+"reload.ogg",reload_fallback)
	weapon.shot_volume_db={"sidearm":-9.0,"shotgun":-5.0,"sniper":-3.0,"rocket":-5.0,"ak47":-6.0}.get(weapon.kind,-7.0)
