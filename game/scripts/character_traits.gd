class_name NestCharacterTraits
extends RefCounted
# Lightweight live view: shared defaults + the selected character's overrides.
var settings: GameTypeSettings
var character_id: String
func _init(rules: GameTypeSettings, id: String):settings=rules;character_id=id
static func is_trait(key: String) -> bool:
 if key in ["nu_enabled","bullet_impact_debug"]:return false
 if key in ["armor_strength_percent","helmet_strength_percent","armor_absorption_percent","helmet_absorption_percent","shields_enabled","shield_strength_percent","shield_recharge_delay","shield_recharge_rate_percent"]:return true
 for definition in GameTypeSettings.definitions():
  if definition.key==key:return definition.category in ["Player","Movement","Combat"] or (definition.category=="Weapons" and key not in ["map_weapons","weapon_pickups","weapon_respawn_percent"])
 return key in ["walk_speed_percent","damage_received_percent"]
static func value(rules: GameTypeSettings, id: String, key: String):
 var overrides: Dictionary=rules.character_traits.get(id,{})
 if overrides.has(key):return overrides[key]
 if key=="show_low_health_vignette":return rules.show_low_health_vignette and NestCharacterCatalog.by_id(id).get("defaults",{}).get(key,true)
 return rules.get(key)
func _get(key: StringName):return value(settings,character_id,String(key))
