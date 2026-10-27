extends SceneTree
var game
var actor
var failures=0
func _initialize():call_deferred("run")
func check(value: bool,message: String):
 print(("PASS " if value else "FAIL ")+message)
 if not value:failures+=1
func add_ramp(position: Vector3,axis: Vector3,angle: float):
 var body=StaticBody3D.new();var shape=BoxShape3D.new();shape.size=Vector3(22,1,32);var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);game.add_child(body);body.position=position;body.basis=Basis(axis,angle);body.collision_layer=1;return body
func top(ramp: Node3D,x: float,z: float) -> Vector3:
 var n=ramp.global_basis.y;var plane=ramp.global_position+n*.5
 return Vector3(x,plane.y-(n.x*(x-plane.x)+n.z*(z-plane.z))/n.y,z)
func settle(position: Vector3):
 actor.global_position=position+Vector3.UP*.15;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.reset_crouch()
 for frame in range(20):actor.movement_step(Vector2.ZERO,false,0,0,1./60);await physics_frame
func walk_to(target: Vector3) -> bool:
 var stuck=0;var previous=actor.global_position
 for frame in range(400):
  var direction=target-actor.global_position
  if Vector2(direction.x,direction.z).length()<.45:return absf(direction.y)<.7
  actor.rotation.y=atan2(-direction.x,-direction.z)
  actor.movement_step(Vector2(0,-1),false,0,actor.rotation.y,1./60);await physics_frame
  if actor.global_position.distance_to(previous)<.001:stuck+=1
  else:stuck=0
  if stuck>35:print("SLOPE STALL at=",actor.global_position," normal=",actor.get_floor_normal()," controlled=",actor.controlled," velocity=",actor.velocity);return false
  previous=actor.global_position
 return false
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var rules=NestMatchPresets.create(2,0,1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 actor=game.player
 for entity in game.actors:entity.set_physics_process(false);entity.set_process(false)
 var ramp=add_ramp(Vector3(500,30,500),Vector3.RIGHT,deg_to_rad(25));var cross_ramp=add_ramp(Vector3(550,30,500),Vector3.FORWARD,deg_to_rad(18));await physics_frame
 await settle(top(ramp,496,509));check(await walk_to(top(ramp,504,491)),"Diagonal uphill crosses an uninterrupted 25 degree floor without stalling")
 await settle(top(ramp,504,491));check(await walk_to(top(ramp,496,509)),"Diagonal downhill remains supported without unintended launching")
 await settle(top(cross_ramp,544,507));check(await walk_to(top(cross_ramp,556,493)),"Cross-axis diagonal travel climbs the 18 degree ramp")
 await settle(top(cross_ramp,556,493));check(await walk_to(top(cross_ramp,544,507)),"Cross-axis diagonal downhill retains control")
 await settle(top(ramp,499,502));actor.controlled=Vector3(2,0,-4);var launch=actor.global_position
 var jumped=actor.movement_step(Vector2(0,-1),true,0,0,1./60);var peak=actor.global_position.y
 for frame in range(130):actor.movement_step(Vector2(0,-1),false,0,0,1./60);await physics_frame;peak=maxf(peak,actor.global_position.y)
 check(jumped and peak>launch.y+1,"Jump from diagonal ramp retains an actual upward arc")
 game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
