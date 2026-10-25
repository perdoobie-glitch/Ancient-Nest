extends RefCounted
static func apply(game) -> void:
 game.game_type.weapon_pickups=false
 var host=game.player
 for actor in game.actors:
  actor.set_physics_process(false);actor.set_process(false)
  actor.global_position=Vector3(100,30,100 if actor==host else 90)
  actor.rotation.y=0;actor.eye.rotation.x=0;actor.reset_aim();actor.reset_physics_interpolation();actor.update_visual(0)
  actor.shield=0;actor.armor=0;actor.overshield=0;actor.health=100;actor.last_damage=game.now+600
 host.slot=0;host.weapons[0]=NestWeaponCatalog.profile("sniper_rifle");host.ammo[0]=4
 var target=game.actors.filter(func(a):return a!=host)[0]
 var offset=target.hitboxes[0].global_position-host.camera.global_position
 host.rotation.y=atan2(-offset.x,-offset.z)
 host.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length())
 host.reset_aim();host.cooldown=game.now
 game.deadline=game.now+500
