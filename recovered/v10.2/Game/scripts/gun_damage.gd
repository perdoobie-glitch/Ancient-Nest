class_name NestGunDamage
extends RefCounted
## Single raw firearm damage contract. All defense processing happens in actor.gd.
const BODY_MULTIPLIER: float=1.0
const HEAD_MULTIPLIER: float=2.0
static func resolve(config: Dictionary, fallback: float, region: String, distance: float, game) -> float:
 var base=maxf(0.0,float(config.get("damage_body",config.get("damage",fallback))))
 var falloff=game.weapon_falloff(config,distance) if not config.is_empty() else 1.0
 return base*maxf(0.0,falloff)*(HEAD_MULTIPLIER if region=="head" else BODY_MULTIPLIER)
