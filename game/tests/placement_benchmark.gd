extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.apply_game_type_settings(NestMatchPresets.create(2,2));await physics_frame;await physics_frame
 var anchor=game.arena.spawns[0][2];var sum=Vector3.ZERO;var start=Time.get_ticks_usec()
 for i in range(200):
  var p=NestPlacementSafety.find(game,anchor,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT)
  assert(p.is_finite());sum+=p
 print("PLACEMENT_BENCHMARK ",JSON.stringify({"calls":200,"average_ms":(Time.get_ticks_usec()-start)/200000.,"position_sum":str(sum)}))
 game.queue_free();await create_timer(.2).timeout;quit()
