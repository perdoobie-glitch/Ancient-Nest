extends SceneTree
var game
var checks=0
var failures=0
var samples=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(200,30,200)
 var sg=NestWeaponCatalog.for_kind("shotgun");var weapon=NestWeaponCatalog.profile("shotgun")
 check(is_equal_approx(sg.damage_body,16*1.5) and is_equal_approx(sg.damage_shield,9.6*1.5) and weapon.damage==24,"Body and shield pellet damage increased 50 percent")
 check(weapon.max_range==32 and sg.max_effective_range_m==32,"Hitscan range and authoritative damage range agree")
 check(weapon.pellets==8 and not weapon.automatic and is_equal_approx(weapon.spread_degrees,4.6875) and weapon.magazine==6,"Wider spread applied; pellet count, trigger and magazine unchanged")
 check(is_equal_approx(weapon.interval,.9) and sg.head_multiplier==1.5,"Fire rate and head multiplier unchanged")
 var previous=INF
 for distance in [0.,4.,5.,10.,15.,20.,25.,30.,31.99,32.,32.01]:
  var factor=game.weapon_falloff(sg,distance);var raw=sg.damage_body*factor
  samples.append({"distance_m":distance,"body_damage_per_pellet_before_faction_rules":raw,"shield_damage_per_pellet":sg.damage_shield*factor})
  check(raw<=previous+.00001,"Damage does not grow with distance at "+str(distance)+" m")
  previous=raw
 check(is_equal_approx(game.weapon_falloff(sg,25)*sg.damage_body,4*1.5),"25 m body pellet is 50 percent above old long-range 4 damage")
 check(is_equal_approx(game.weapon_falloff(sg,25)*sg.damage_shield,2.4*1.5),"25 m shield pellet is 50 percent above old long-range 2.4 damage")
 check(game.weapon_falloff(sg,24.9)>game.weapon_falloff(sg,25) and game.weapon_falloff(sg,25)>game.weapon_falloff(sg,25.1),"25 m sits on continuous strengthening toward the target")
 check(game.weapon_falloff(sg,32)==0 and game.weapon_falloff(sg,32.1)==0,"Tail fades to zero at range boundary")
 var enemy=NestActor.new();enemy.game=game;enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.set_physics_process(false);enemy.set_process(false)
 game.fair_playing_field=true;game.fair_health_type="naki"
 for distance in [4.,10.,15.,20.,25.,30.,32.5]:
  enemy.respawn();enemy.set_physics_process(false);enemy.global_position=Vector3(200,30,160);enemy.update_visual(.016);await physics_frame
  var target=enemy.hitboxes[1].global_position;var from=target+Vector3.BACK*distance
  var before=enemy.shield
  var hit=game.trace(from,from+Vector3.FORWARD*weapon.max_range,5,p.ray_exclusions())
  game.launch_bullet(p,weapon,from,Vector3.FORWARD,0,false,game.next_event()*16)
  if distance>32:
   check(is_equal_approx(enemy.shield,before),"Real shotgun ray stops beyond range")
  else:
   var expected=sg.damage_shield*game.weapon_falloff(sg,from.distance_to(hit.position))
   check(before>enemy.shield and is_equal_approx(before-enemy.shield,expected),"Real hitscan routes distance-scaled shield damage at "+str(distance)+" m")
 # Per-target faction body phases still route through their existing protection.
 game.fair_playing_field=false
 for model in ["naki","annu"]:
  game.fair_playing_field=true;game.fair_health_type=model;enemy.respawn();enemy.set_physics_process(false);enemy.shield=0;enemy.armor=0;enemy.helmet_hp=0
  var before=enemy.health;var damage=6.0*float(game.damage_rules.naki_body_bullet_damage_multiplier) if model=="naki" else 6.0
  enemy.take_damage(999,"torso","bullet",false,p,game.next_event()*16,p.global_position,"shotgun",25)
  check(is_equal_approx(before-enemy.health,damage),"Existing "+model+" unshielded body rule remains in effect")
 var output=OS.get_environment("ANCIENT_NEST_TEST_OUTPUT")
 if output.is_empty():output="user://shotgun-damage-samples.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(samples,"  "));file.close()
 print("SHOTGUN BALANCE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
