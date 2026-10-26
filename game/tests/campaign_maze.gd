extends SceneTree
var game
var c
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func pulse(pressed: bool):
 var event=InputMap.action_get_events("forward")[0].duplicate();event.pressed=pressed;event.echo=false;Input.parse_input_event(event)
func pulse_back(pressed: bool):
 var event=InputMap.action_get_events("backward")[0].duplicate();event.pressed=pressed;event.echo=false;Input.parse_input_event(event)
func jump_to(target: Vector3) -> bool:
 var actor=game.player;var start_y=actor.global_position.y;var peak=start_y
 print("JUMP_START ",actor.global_position," target ",target," grounded ",actor.is_on_floor())
 var key=InputMap.action_get_events("jump")[0].duplicate();key.pressed=true;key.echo=false;Input.parse_input_event(key)
 for tick in range(180):
  var offset=target-actor.global_position;actor.rotation.y=atan2(-offset.x,-offset.z);actor.eye.rotation.x=0
  var distance=Vector2(offset.x,offset.z).length();var along=Vector2(actor.controlled.x,actor.controlled.z).dot(Vector2(offset.x,offset.z).normalized());var braking=not actor.is_on_floor() and distance<1 and along>1
  pulse(distance>.3 and not braking);pulse_back(braking)
  if tick==5:key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
  game.input_window_focused=true;await physics_frame;peak=maxf(peak,actor.global_position.y)
  if tick>12 and actor.is_on_floor() and distance<.8 and absf(actor.global_position.y-target.y)<.15:pulse(false);pulse_back(false);return true
 print("JUMP_PEAK ",peak," from ",start_y)
 pulse(false);pulse_back(false);return false
func walk(target: Vector3) -> bool:
 var actor=game.player;var path=c.world.route(actor.global_position,target)
 if path.is_empty():print("NO_ROUTE "+str(actor.global_position)+" to "+str(target));return false
 if c.world.segment_open(path[-1],target):path.append(target)
 for waypoint in path:
  var steps=0
  while Vector2(actor.global_position.x-waypoint.x,actor.global_position.z-waypoint.z).length()>.7:
   steps+=1
   if steps>500:pulse(false);print("STUCK "+str(actor.global_position)+" toward "+str(waypoint));return false
   var direction=waypoint-actor.global_position;actor.rotation.y=atan2(-direction.x,-direction.z);actor.eye.rotation.x=0
   pulse(true);game.input_window_focused=true;await physics_frame
 pulse(false);await physics_frame
 var close=Vector2(actor.global_position.x-target.x,actor.global_position.z-target.z).length()<1.2
 if not close:print("SHORT_ROUTE "+str(actor.global_position)+" to "+str(target)+" path "+str(path))
 return close
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 c=game.campaign;c.save_store.path="user://maze-test.json";c.begin_solo(false);c.state.phase="BOARDING";c.present_phase();await physics_frame
 var boarding=c.world.locations.board+Vector3(0,0,1)
 game.player.global_position=c.world.locations.manifest+Vector3(0,0,2.2)
 print("BOARDING_ROUTE ",c.world.route(game.player.global_position,boarding))
 check(await walk(boarding),"Preparation cargo terminal leads into the curved ship cabin")
 c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");await physics_frame
 var actor=game.player
 c.phase_elapsed=999;c.tick(0);check(c.state.phase=="CRASH_ORIENTATION","No timer-triggered assault at crash site")
 actor.global_position=c.world.maze.checkpoints[3];c.tick(0);check(c.state.phase=="CRASH_ORIENTATION","Future encounter cannot skip ordered wave progression")
 actor.global_position=c.world.maze.checkpoints[0];c.downed[1]={"at":game.now,"expired":false};c.tick(0);check(c.state.phase=="CRASH_ORIENTATION","Downed members cannot trigger encounters")
 c.downed.clear();c.tick(0);check(c.state.phase=="WAVE_1","Living squad member triggers only the active encounter")
 var epoch=c.phase_epoch;c.tick(0);check(c.phase_epoch==epoch,"Standing inside trigger does not duplicate phase changes")
 # Isolate locomotion from combat. Full wave accounting is covered by campaign_mission.
 c.state.phase="RADIO_READY";c.state.completed_waves=5;c.spawn_at=INF;actor.global_position=Vector3(0,.3,11)
 check(await walk(Vector3(0,0,23)),"Curved ship cabin and continuous rear ramp are physically traversable")
 check(await walk(Vector3(0,0,30)),"Crash hub opens onto the forest dirt trail")
 var graph_cells=c.world.maze.cells;var connected={Vector2i(0,1):true};var queue=[Vector2i(0,1)]
 while not queue.is_empty():
  var cell: Vector2i=queue.pop_front()
  for next in c.world.maze.neighbours(cell):
   if not connected.has(next):connected[next]=true;queue.append(next)
 check(connected.size()==graph_cells.size()+1 and c.world.maze.edges.size()==graph_cells.size(),"Every maze cell belongs to one acyclic route tree with no connecting shortcuts")
 check(c.world.maze.spine.size()>75 and c.world.maze.stats.area_m2==40000 and c.world.maze.stats.clear_width==17.0 and c.world.maze.stats.wall_height==13.0,"Maze has fivefold footprint, doubled corridor clearance and taller walls")
 check(c.world.maze.vertical_sites.size()>=3,"Dead-end gardens contain real climbing routes")
 var reached=true
 for cell in c.world.maze.spine:
  if not await walk(c.world.maze.position(cell)):reached=false;break
 check(reached,"Real movement traverses the entire 1.6-kilometre main route and its bridges")
 check(await walk(c.world.locations.radio+Vector3(2,0,0)),"Main route ends at the physical expedition relay interaction")
 if not c.world.maze.vertical_sites.is_empty():
  var site=c.world.maze.vertical_sites[0];actor.global_position=site.entry+Vector3.UP*.8;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;pulse(false)
  for i in range(30):await physics_frame
  var climbed=true
  for step in site.steps:
   if not await jump_to(step):climbed=false;print("CLIMB_STOP ",actor.global_position," target ",step);break
  check(climbed and actor.global_position.y>3,"Actual jump input climbs rocks and successive solid branches above three metres")
 for i in range(4):
  var point=c.world.maze.checkpoints[i]
  check(not c.world.blocked_point(point) and not c.world.route(point,c.world.locations.exit).is_empty(),"Encounter %d has an open clearing and navigation back to the ship"%(i+1))
 var ray=PhysicsRayQueryParameters3D.create(Vector3(0,1.8,40),Vector3(20,1.8,40),1)
 check(not c.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Opaque plant barriers block real weapon/perception rays")
 check(c.world.get_meta("maze_stats").bridges>=4,"Shallow-stream crossings have wide timber bridges")
 c.state.phase="INTERMISSION_2";c.state.completed_waves=2
 check(c.choose_spawn(actor).distance_to(c.world.maze.checkpoints[1])<4,"Checkpoint retry respawns at the previous cleared garden")
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 print("CAMPAIGN MAZE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
