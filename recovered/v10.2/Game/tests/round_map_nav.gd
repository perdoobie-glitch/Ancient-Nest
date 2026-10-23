extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for team in game.arena.spawns:
  for pos in game.arena.spawns[team]:
   for target in [game.arena.sites[0],game.arena.sites[1],game.arena.ship_position,Vector3(6,14,8)*.85]:
    checks+=1
    if game.arena.route(pos,target).is_empty():failures+=1;push_error("No route "+str(pos)+" -> "+str(target))
 print("ROUND MAP NAV: ",checks," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
