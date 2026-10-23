extends RefCounted
static func apply(game) -> void:
 game.game_type.weapon_pickups=false # Keep the one-shot migration assertion isolated from automatic pad pickups.
 for actor in game.actors:
  actor.slot=0;actor.weapons[0]=NestWeaponCatalog.profile("assault_rifle");actor.health=17;actor.last_damage=game.now+600;actor.shield=61 if actor.damage_model()=="naki" else 0;actor.ammo[0]=11;actor.reserve[0]=67;actor.kills=4;actor.deaths=2
 game.scores.assign([7,5]);game.deadline=game.now+500
 game.matchmaking.hybrid.checkpoint_at=0
