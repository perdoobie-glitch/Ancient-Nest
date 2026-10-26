extends SceneTree
func _initialize():call_deferred("run")
func run():
 seed(260026)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://motorcycle-ambush-qa.json";c.begin_solo(false);c.journey.start_standalone(2);await physics_frame
 var controller=c.journey.motorcycles;var actor=game.player
 actor.global_position=NestCampaignMotorcycleWorld.point(110)+Vector3.UP*.25;controller.bikes[1].position=actor.global_position
 game.input_window_focused=true;game.game_type.bots_dont_shoot=false;game.context="playing";controller.tick(.1)
 var before=actor.health+actor.shield;var shots=0
 for frame in range(480):
  game.input_window_focused=true
  await physics_frame
  if actor.health+actor.shield<before-1:break
 for enemy in game.actors:
  if enemy.has_meta("bike_ambush"):shots+=enemy.accepted_shots
 var damaged=actor.health+actor.shield<before-1
 print(("PASS " if damaged and shots>0 else "FAIL ")+"Stationed Annu fire real weapon projectiles and damage a stopped rider: shots=%d resources %.1f -> %.1f"%[shots,before,actor.health+actor.shield])
 c.exit_campaign();game.queue_free();await process_frame;quit(0 if damaged and shots>0 else 1)
