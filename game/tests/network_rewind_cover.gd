extends SceneTree
var failures=0
func check(ok: bool,message: String):
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_game();game.set_physics_process(false)
	for actor in game.actors:actor.set_physics_process(false)
	var shooter=game.actors[0]
	var wall=StaticBody3D.new();wall.collision_layer=1
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(4,4,.5);collision.shape=shape;wall.add_child(collision)
	game.add_child(wall);wall.global_position=Vector3(500,101,495);wall.add_to_group("network_rewind_blocker")
	var start=Vector3(500,101,500);var finish=Vector3(500,101,490)
	var excludes: Array[RID]=[]
	game.now=10;game.record_hitbox_history()
	wall.collision_layer=0;wall.global_position.x+=20
	await physics_frame;await physics_frame
	game.now=10.1
	check(game.trace(start,finish,1,excludes).is_empty(),"Opened and moved cover no longer blocks current world")
	game.begin_rewind(shooter,10)
	check(not game.rewound_trace(start,finish,5,excludes).is_empty(),"Historical cover still blocks an older hitscan")
	game.end_rewind()
	check(game.trace(start,finish,1,excludes).is_empty(),"Rewind leaves live physics geometry unchanged")
	wall.global_position.x-=20;wall.collision_layer=1
	await physics_frame;await physics_frame
	game.begin_rewind(shooter,10.1)
	check(not game.rewound_trace(start,finish,5,excludes).is_empty(),"Current cover remains blocking during rewind")
	game.end_rewind();game.stop_game();game.queue_free();await process_frame
	print("REWIND COVER failures="+str(failures));quit(1 if failures else 0)
