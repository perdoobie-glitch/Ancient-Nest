extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 for path in game.arena.up_routes:
  if not (String(path.name).begins_with("J1") or String(path.name).begins_with("EAST OUTER") or String(path.name).begins_with("BOTTOM")):continue
  for backwards in [false,true]:
   var start=path.end if backwards else path.start;var finish=path.start if backwards else path.end
   p.respawn();p.set_physics_process(false);p.global_position=start+Vector3.UP*.10;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
   for i in range(8):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
   var direction=finish-start;var yaw=atan2(-direction.x,-direction.z)
   var flat=Vector2(direction.x,direction.z);var wanted=flat.length()
   for i in range(720):
    p.movement_step(Vector2(0,-1),false,0,yaw,1.0/60);await physics_frame
    var progress=Vector2(p.global_position.x-start.x,p.global_position.z-start.z).dot(flat.normalized())
    if progress>=wanted+.2 and absf(p.global_position.y-finish.y)<.35:break
   print("WALK ",path.name," backwards=",backwards," end ",p.global_position," target ",finish)
   check(p.alive and absf(p.global_position.y-finish.y)<.35,"Standing capsule traverses "+path.name+(" down" if backwards else " up"))
 game.stop_game();game.queue_free();await process_frame;print("ROUND RAMP WALK: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
