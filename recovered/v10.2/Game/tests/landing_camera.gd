extends SceneTree
class CameraMonitor extends Node:
 var actor
 var rows=[]
 func _process(_delta):
  if actor!=null:rows.append({"y":actor.camera.global_position.y,"eye":actor.eye.global_position.y,"body":actor.global_position.y,"floor":actor.is_on_floor(),"crouch":actor.crouched,"fraction":Engine.get_physics_interpolation_fraction()})
func _initialize():call_deferred("run")
func run():
 var fps=int(OS.get_environment("NEST_CAMERA_TEST_FPS"));Engine.max_fps=fps if fps>0 else 120
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="playing";Engine.max_fps=fps if fps>0 else 120
 var p=game.player;p.set_process(false);p.set_physics_process(false)
 var floor=StaticBody3D.new();var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=Vector3(30,1,30);c.shape=s;floor.add_child(c);game.add_child(floor);floor.position=Vector3(200,99.5,200)
 p.respawn();p.set_physics_process(false);p.global_position=Vector3(200,100.04,200);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.reset_physics_interpolation();p.set_process(true);p.set_physics_process(true)
 for i in range(30):await physics_frame
 var monitor=CameraMonitor.new();monitor.actor=p;monitor.process_priority=100;root.add_child(monitor)
 Input.action_press("jump");await physics_frame;await physics_frame;Input.action_release("jump")
 for i in range(8):await physics_frame
 Input.action_press("crouch")
 for i in range(170):await physics_frame
 p.set_physics_process(false);p.set_process(false);Input.action_release("crouch")
 var rows=monitor.rows;var land=-1;var had_air=false
 for i in range(rows.size()):
  if not rows[i].floor:had_air=true
  if had_air and rows[i].floor:land=i;break
 var tail=rows.slice(rows.size()-30);var settled=tail.reduce(func(a,b):return a+b.y,0.0)/tail.size();var near=rows.slice(land,mini(land+12,rows.size()));var ys=near.map(func(r):return r.y)
 print("CAMERA LAND dip below settled ",settled-ys.min()," land ",land," settled ",settled," min ",ys.min())
 var ok=land>0 and settled-ys.min()<.03
 if not ok:push_error("Landing camera dip exceeds 3 cm or no landing was observed")
 var out=OS.get_environment("NEST_CAMERA_PROBE_OUTPUT");if out.is_empty():out="user://camera-landing.json"
 var f=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify({"fps_cap":Engine.max_fps,"dip_m":settled-ys.min(),"land_frame":land,"passed":ok,"rows":rows}));f.close()
 monitor.actor=null;game.stop_game();game.queue_free();monitor.queue_free();await process_frame;quit(0 if ok else 1)
