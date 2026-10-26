extends SceneTree
var game
var actor
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func box(p: Vector3,size: Vector3,angle=0.0,velocity=Vector3.ZERO):
 var body=StaticBody3D.new();body.collision_layer=1;body.constant_linear_velocity=velocity
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision);game.add_child(body);body.position=p;body.rotation.z=angle;return body
func settle(p: Vector3):
 actor.reset_crouch();actor.global_position=p;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.velocity=Vector3.ZERO
 for i in range(15):actor.movement_step(Vector2.ZERO,false,0,0,1./60.);await physics_frame
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var rules=NestMatchPresets.create(2,0,1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 actor=game.player;actor.set_physics_process(false);actor.set_process(false)
 var transferred=Vector3.ZERO
 for i in range(120):transferred=NestContactMomentum.transfer(transferred,Vector3.RIGHT,Vector3(8,0,0))
 check(transferred.is_equal_approx(Vector3(8,0,0)),"Repeated object contacts conserve bounded speed instead of stacking impulses")
 check(NestContactMomentum.transfer(Vector3(2,0,0),Vector3.RIGHT,Vector3.ZERO)==Vector3(2,0,0),"Static objects never inject momentum")
 check(NestContactMomentum.transfer(Vector3.ZERO,Vector3.RIGHT,Vector3(1000,0,0)).length()<=24.001,"Extreme object velocities have a bounded transfer")
 check(NestContactMomentum.transfer(Vector3.ZERO,Vector3.RIGHT,Vector3(8,0,0),2).length()<.3,"Lightweight objects cannot launch an eighty-kilogram player")
 var floor=box(Vector3(500,19.5,500),Vector3(35,1,35))
 await physics_frame;await settle(Vector3(500,20.1,500))
 var flat_jump=actor.movement_step(Vector2.RIGHT,true,0,0,1./60.)
 print("FLAT ",flat_jump," y ",actor.controlled.y," base ",actor.tuning.jump_speed," traits ",actor.traits.jump_height_percent," gravity ",actor.traits.gravity_percent)
 check(flat_jump and absf(actor.controlled.y-actor.tuning.jump_speed*sqrt(actor.traits.jump_height_percent*actor.traits.gravity_percent/10000.0))<.01,"Flat-ground jump strength remains unchanged")
 var ramp=box(Vector3(550,20,500),Vector3(16,1,10),deg_to_rad(25))
 await physics_frame;await settle(Vector3(550,21,500));actor.controlled=Vector3(5,0,0)
 var slope_jump=actor.movement_step(Vector2.RIGHT,true,0,0,1./60.)
 check(slope_jump and actor.controlled.y>actor.tuning.jump_speed+1,"Actual uphill ramp jump carries forward-and-upward surface momentum")
 var conveyor=box(Vector3(600,19.5,500),Vector3(12,1,12),0,Vector3(4,0,0))
 await physics_frame;await settle(Vector3(600,20.1,500));var inherited=actor.get_platform_velocity();actor.movement_step(Vector2.ZERO,true,0,0,1./60.)
 print("PLATFORM ",inherited," ext ",actor.external," ctrl ",actor.controlled)
 check(inherited.x>3.9 and actor.external.x>3.8,"Jump inherits actual moving-support momentum once")
 # A moving side surface presses the capsule against an opposing static wall.
 box(Vector3(650,19.5,500),Vector3(12,1,12));box(Vector3(651,22,500),Vector3(.5,4,8));var pusher=box(Vector3(648.8,22,500),Vector3(.5,4,8),0,Vector3(6,0,0))
 await physics_frame;await settle(Vector3(649.5,20.1,500));actor.controlled=Vector3(-5,0,0)
 for i in range(8):actor.movement_step(Vector2.LEFT,false,0,0,1./60.);await physics_frame
 check(actor.global_position.is_finite() and actor.external.length()<30,"Compression remains finite and bounded under sustained object pressure")
 # Isolate opposed-contact escape without requiring engine overlap recovery to select both walls.
 check(NestContactMomentum.slope_rise(Vector3(-5,0,0),Vector3(-.4226,.9063,0))==0,"Downhill motion never creates an upward launch")
 actor.global_position=Vector3(650,20.05,500);actor.external=Vector3.ZERO;actor.controlled=Vector3.ZERO
 var left=KinematicCollision3D.new();var right=KinematicCollision3D.new()
 var enclosed=actor.test_move(actor.global_transform,Vector3.LEFT,left) and actor.test_move(actor.global_transform,Vector3.RIGHT,right)
 check(enclosed and NestContactMomentum.escape(actor,[left.get_normal(),right.get_normal()],6) and actor.external.z< -3,"Opposed real object contacts eject toward open space without crossing either wall")
 var before=actor.global_position;actor.movement_step(Vector2.ZERO,false,0,0,1./60.)
 check(actor.global_position.z<before.z,"Compression escape momentum physically moves the capsule")
 var momentum=Vector3(8,4,0);actor.global_position=Vector3(700,100,500);actor.external=momentum;actor.controlled=Vector3.ZERO;actor.velocity=Vector3.DOWN*.1;actor.move_and_slide()
 actor.movement_step(Vector2.ZERO,false,0,0,1./60.)
 check(actor.external.length()<momentum.length() and actor.external.length()>momentum.length()-.05,"Airborne momentum decays gradually through existing drag")
 game.stop_game();game.queue_free();await process_frame;print("CONTACT MOMENTUM: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
