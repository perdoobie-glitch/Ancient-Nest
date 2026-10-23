extends SceneTree
func _initialize():call_deferred("run")
func run():
 var ak=NestWeaponCatalog.definition("ak47");assert(ak.fire_rate_rpm==600 and is_equal_approx(NestWeaponCatalog.profile("ak47").interval,.1))
 assert(ak.damage_body==32)
 for id in ["plasma_br","plasma_auto","plasma_pistol","viper_pulse_smg","plasma_sniper"]:assert(NestWeaponCatalog.profile(id).speed>=900.)
 var previous=-1.
 for grade in ["A","B","C","D"]:
  var angle=NestWeaponAccuracy.cone({"accuracy_grade":grade});assert(angle>previous);previous=angle
 for weapon in NestWeaponCatalog.data().weapons:
  if weapon.get("slot","")=="grenade":continue
  var profile=NestWeaponCatalog.profile(weapon.id)
  if weapon.has("accuracy_grade"):assert(is_equal_approx(profile.spread_half_angle_deg,NestWeaponAccuracy.cone(weapon)))
 for id in ["sniper_rifle","plasma_sniper"]:assert(NestWeaponCatalog.profile(id).interval==1.5 and NestWeaponCatalog.definition(id).damage_body==100.)
 var rocket=NestWeaponCatalog.definition("rocket_launcher");assert(rocket.splash_damage_max==200. and rocket.splash_radius_m==7.)
 var sg=NestWeaponCatalog.definition("shotgun");assert(sg.falloff_start_m==5. and sg.falloff_end_m==12. and sg.pattern_spread_half_angle_deg==2.75)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for id in ["assault_rifle","ak47","battle_rifle_scoped","plasma_auto","falcon_smg","viper_pulse_smg","magnum","plasma_pistol","shotgun"]:
  var config=NestWeaponCatalog.definition(id);var last=INF
  for distance in range(int(config.max_effective_range_m)+2):
   var damage=NestGunDamage.resolve(config,0,"torso",float(distance),game);assert(damage<=last+.00001);last=damage
   assert(is_equal_approx(NestGunDamage.resolve(config,0,"head",float(distance),game),damage*2.))
 print("PASS: original AK600RPM, tier/range damage, grade-driven accuracy, fast plasma, 1x/2x hit rules, sniper/rocket protected settings")
 game.queue_free();await create_timer(.75).timeout
 call_deferred("quit")
