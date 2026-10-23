extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var routes=game.arena.up_routes.filter(func(path):return path.name=="EAST OUTER ASCENT" or (path.name=="BASE APPROACH" and path.start.x<0 and path.start.z>10))
 check(routes.size()==2,"Both repaired ramps are present")
 for path in routes:
  var across=Vector3.UP.cross(path.end-path.start).normalized()
  for reverse in [false,true]:
   for offset in [-.6,0,.6]:
    var start=(path.end if reverse else path.start)+across*offset
    var finish=(path.start if reverse else path.end)+across*offset
    # Cross the full seam: a rounded capsule can rest above a slope endpoint.
    var exit_direction=Vector3(finish.x-start.x,0,finish.z-start.z).normalized()
    finish+=exit_direction*.65
    p.respawn();p.set_physics_process(false);p.global_position=start+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
    for i in range(10):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
    var direction=finish-start;var yaw=atan2(-direction.x,-direction.z)
    for i in range(ceili(direction.length()/p.tuning.ground_speed*60)+100):
     var forward=Vector3(direction.x,0,direction.z).normalized()
     var remaining=(finish-p.global_position).dot(forward)
     var speed=p.controlled.dot(forward)
     var stopping=speed*speed/(2.0*35.0)+.12
     var input=Vector2(0,-1 if remaining>0 else 1)
     if absf(remaining)<.15 and absf(speed)<.3:input=Vector2.ZERO
     elif signf(remaining)==signf(speed) and absf(remaining)<stopping:input=Vector2(0,1 if speed>0 else -1)
     p.movement_step(input,false,0,yaw,1.0/60);await physics_frame
     if absf(p.global_position.y-finish.y)<.1 and Vector2(p.global_position.x-finish.x,p.global_position.z-finish.z).length()<.25:break
    for i in range(10):p.movement_step(Vector2.ZERO,false,0,yaw,1.0/60);await physics_frame
    print("CLEARANCE ",path.name," ","down" if reverse else "up"," offset ",offset," result ",p.global_position," target ",finish)
    check(p.alive and p.is_on_floor() and absf(p.global_position.y-finish.y)<.17,"Standing traverse %s %s offset %.1f"%[path.name,"down" if reverse else "up",offset])
 print("V16 RAMP CLEARANCE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
