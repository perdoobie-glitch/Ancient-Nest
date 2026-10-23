extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(2,0,1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.set_character(0);p.refresh_traits();p.respawn()
 var floor=StaticBody3D.new();var cs=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(50,1,50);cs.shape=shape;floor.add_child(cs);game.add_child(floor);floor.global_position=Vector3(500,19.5,500)
 var wall=StaticBody3D.new();var ws=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,5,24);ws.shape=box;wall.add_child(ws);game.add_child(wall);wall.global_position=Vector3(506,22.5,500)
 p.reset_crouch();p.position=Vector3(500,20.08,500);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
 await physics_frame;await physics_frame
 var records=[]
 for step in range(600):
  game.now=step/60.0
  var move=Vector2(.8,0) if step<250 else Vector2(-.6,.4) if step<450 else Vector2.ZERO
  var jump=step in [45,165,330,490]
  var crouch=1 if step>=70 and step<120 or step>=350 and step<405 else 0
  p.movement_step(move,jump,crouch,0,1./60.)
  records.append({"pos":[p.position.x,p.position.y,p.position.z],"ctrl":[p.controlled.x,p.controlled.y,p.controlled.z],"crouched":p.crouched,"air_duck":p.air_duck,"floor":p.is_on_floor()})
  await physics_frame
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(records))
 print("PASS: 600 ticks covering movement, braking, wall contact, jumps, air crouch and landing")
 game.stop_game();game.queue_free();await create_timer(.12).timeout;quit()
