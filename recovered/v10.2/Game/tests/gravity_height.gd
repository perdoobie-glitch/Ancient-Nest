extends SceneTree
class JumpDriver extends Node:
 signal completed(result)
 var actor
 var tick=0
 var start=0.
 var apex=0.
 func _physics_process(delta: float):
  if tick<30:
   actor.movement_step(Vector2.ZERO,false,0,0,delta);tick+=1;return
  if tick==30:
   assert(actor.is_on_floor());start=actor.position.y;apex=start
  actor.movement_step(Vector2.ZERO,tick==30,0,0,delta);apex=maxf(apex,actor.position.y);tick+=1
  if tick>31 and actor.is_on_floor():
   set_physics_process(false);completed.emit({"height":apex-20.,"rest_position":start,"ticks":tick-30})
var game
var actor
func _initialize():call_deferred("run")
func trajectory(gravity: float,launch: float) -> Dictionary:
 actor.tuning.gravity=gravity;actor.tuning.jump_speed=launch;actor.reset_crouch();actor.position=Vector3(500,20.08,500);actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.velocity=Vector3.ZERO
 var driver=JumpDriver.new();driver.actor=actor;root.add_child(driver)
 var result=await driver.completed;driver.queue_free();return result
func ballistic_apex(gravity: float,launch: float) -> float:
 var height=0.
 for tick in range(200):height+=maxf(0.,launch-gravity*tick/60.)/60.
 return height
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(2,0,1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 actor=game.player;actor.set_physics_process(false);actor.set_process(false)
 var floor=StaticBody3D.new();var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(50,1,50);collider.shape=shape;floor.add_child(collider);game.add_child(floor);floor.global_position=Vector3(500,19.5,500)
 var settings=NestTuning.new();assert(absf(settings.gravity-8.14065237*1.15)<.000001)
 assert(absf(ballistic_apex(settings.gravity,settings.jump_speed)-ballistic_apex(8.14065237,6.4552829507))<.000001)
 var old=await trajectory(8.14065237,6.4552829507)
 var updated=await trajectory(settings.gravity,settings.jump_speed)
 print("MEASURE ",JSON.stringify({"old":old,"updated":updated}))
 assert(absf(old.height-updated.height)<.01,"Jump apex changed beyond collision tolerance")
 assert(updated.ticks<old.ticks)
 print("PASS: gravity +15%, previous jump apex retained within 1cm collision tolerance; exact ballistic apex, shorter airtime")
 game.stop_game();game.queue_free();await create_timer(.15).timeout;quit()
