extends SceneTree
func _initialize():call_deferred("run")
func run():
 var definition=NestWeaponCatalog.for_kind("rocket")
 assert(definition.splash_damage_max==200. and definition.splash_radius_m==7.)
 assert(definition.damage_direct==240.,"Direct impact was not requested to change")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(2,0,1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false);game.context="playing"
 var actor=game.player;actor.set_physics_process(false);actor.set_character(1);actor.refresh_traits();actor.alive=true
 var origin=Vector3(500,50,500)
 for distance in [.05,3.5,7.1]:
  actor.global_position=origin+Vector3(distance,-NestActor.STAND_CENTER,0);actor.health=1000.;actor.shield=0.;actor.armor=0.
  game.explode(origin,null,game.next_event()*16,definition.splash_damage_max,false,"rocket")
  var loss=1000.-actor.health
  var expected=200.*maxf(0.,1.-distance/7.)
  assert(absf(loss-expected)<.1,"Rocket blast falloff/radius mismatch: %s expected %s"%[loss,expected])
 print("PASS: rocket maximum 200 splash damage, linear falloff, no damage beyond 7m, direct damage unchanged")
 game.stop_game();game.queue_free();await create_timer(.15).timeout;quit()
