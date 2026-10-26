extends SceneTree
# Rendered input/physics walkthrough, isolated profile. No tutorial flags are injected.
var game
var c
var output=""
var failures=0
var checks=[]
var started=0
var frame_times=[]
var last_frame=0
var intro_captured={}
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks.append({"passed":ok,"message":message});print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func pulse(action: String,pressed: bool):
 var bindings=InputMap.action_get_events(action)
 if bindings.is_empty():return
 var event=bindings[0].duplicate();event.pressed=pressed
 if event is InputEventKey:event.echo=false
 Input.parse_input_event(event)
func frame():
 await process_frame
 game.input_window_focused=true
 var now=Time.get_ticks_usec()
 if last_frame>0:frame_times.append((now-last_frame)/1000.0)
 last_frame=now
func wait_seconds(seconds: float):
 var end=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:await frame()
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func go(target: Vector3,seconds=18.0) -> bool:
 var actor=game.player;var deadline=Time.get_ticks_msec()+int(seconds*1000);var path=c.world.route(actor.global_position,target)
 if path.is_empty():print("WALK_NO_ROUTE "+str(actor.global_position)+" -> "+str(target))
 if not path.is_empty() and path[-1].distance_to(target)>.25 and c.world.segment_open(path[-1],target):path.append(target)
 for waypoint in path:
  while Vector2(actor.global_position.x-waypoint.x,actor.global_position.z-waypoint.z).length()>.65:
   if Time.get_ticks_msec()>deadline:pulse("forward",false);print("WALK_STUCK "+str(actor.global_position)+" -> "+str(waypoint)+" ray "+str(game.trace(actor.eye.global_position,waypoint+Vector3.UP*1.8,1)));return false
   var direction=waypoint-actor.global_position;actor.rotation.y=atan2(-direction.x,-direction.z);actor.eye.rotation.x=0
   pulse("forward",true);await frame()
 pulse("forward",false);await wait_seconds(.15)
 return Vector2(actor.global_position.x-target.x,actor.global_position.z-target.z).length()<1.1
func hold(action: String,seconds: float):
 pulse(action,true);await wait_seconds(seconds);pulse(action,false);await frame()
func finish():
 for action in ["forward","jump","interact","fire","aim","crouch"]:pulse(action,false)
 var elapsed=(Time.get_ticks_msec()-started)/1000.0;frame_times.sort()
 var report={"passed":failures==0,"checks":checks,"elapsed_seconds":elapsed,"samples":frame_times.size(),"rendered_frame_p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"phase":c.state.phase,"practice":c.state.practice,"note":"Automated real-time input/renderer fixture; not a human balance or voice listening test."}
 var file=FileAccess.open(output+"/walkthrough.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
func run():
 output=OS.get_environment("NEST_WALKTHROUGH_OUTPUT")
 if output.is_empty() or OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 DirAccess.make_dir_recursive_absolute(output);started=Time.get_ticks_msec();root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.values.graphics_quality=2;game.prefs.values.shadows=true;game.prefs.values.vsync=false;game.prefs.values.fps_limit=60;game.prefs.apply()
 c=game.campaign;c.save_store.path="user://walkthrough.json";c.selected_difficulty="Easy";c.begin_solo(false)
 var fast=OS.get_environment("NEST_WALKTHROUGH_FAST")=="1";var intro_start=Time.get_ticks_msec()
 var intro_only=OS.get_environment("NEST_WALKTHROUGH_INTRO_ONLY")=="1"
 if not fast:
  await RenderingServer.frame_post_draw
  print("FIRST_VISIBLE_FRAME_AFTER_MS "+str(Time.get_ticks_msec()-intro_start));intro_start=Time.get_ticks_msec()
 if fast:c.send_action("skip",{})
 while c.state.phase=="INTRO":
  await frame()
  var slot=int(c.phase_elapsed/20)
  # Keep synchronous PNG readback/encoding out of the timed cinematic.
 var intro_seconds=(Time.get_ticks_msec()-intro_start)/1000.0
 check(c.state.phase=="PREPARATION" and (fast or absf(intro_seconds-120)<1.2),("Rehearsal skips intro" if fast else "Normal 120-second introduction hands off to playable preparation")+": %.2f s"%intro_seconds)
 if intro_only:
  check(c.cinematic.camera.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Cinematic camera avoids physics interpolation jitter")
  await capture("intro-handoff");await finish();return
 var motion=InputEventMouseMotion.new();motion.relative=Vector2(900,120);Input.parse_input_event(motion);await wait_seconds(.3)
 pulse("jump",true);await wait_seconds(.2);pulse("jump",false)
 var reached=await go(c.world.locations.service+Vector3(0,0,2.2))
 check(reached,"Physical movement reaches equipment terminal around new scenery")
 await hold("interact",.85);check(c.state.practice.get("1",{}).get("interact",false),"Actual held input completes the equipment check")
 reached=await go(c.world.locations.calibration+Vector3(0,0,2.2));check(reached,"Shield calibration approach is physically reachable")
 await hold("interact",1.2);check(c.state.practice.get("1",{}).get("calibrating",false),"Actual calibration interaction loads the shield")
 reached=await go(c.world.locations.shield_cover);check(reached,"Route walks around the calibration barrier into cover")
 await wait_seconds(12);check(c.state.practice.get("1",{}).get("shield",false),"Shield naturally recharges behind cover")
 reached=await go(c.world.locations.range+Vector3(0,0,2));check(reached,"Firing bay remains reachable")
 game.player.rotation.y=0;game.player.eye.rotation.x=0;await hold("aim",.35);await hold("fire",.4);await hold("reload",2.5);await hold("secondary_weapon",.8);await hold("primary_weapon",.8)
 reached=await go(Vector3(21,0,16));check(reached,"Approach reaches the service passage entrance")
 pulse("crouch",true);await wait_seconds(.3);reached=await go(Vector3(21,0,-3));pulse("crouch",false);await hold("flashlight",.25)
 check(reached,"Crouched traversal passes the service passage beam")
 await wait_seconds(.4);check(c.practice_complete(1),"Every personal tutorial check is earned through input and physics")
 await capture("preparation-complete")
 if not c.practice_complete(1):await finish();return
 reached=await go(c.world.locations.manifest+Vector3(0,0,2.2));check(reached,"Cargo approach is unobstructed")
 if not reached:await finish();return
 await hold("interact",.85)
 reached=await go(c.world.locations.board+Vector3(0,0,1));check(game.player.global_position.z<-10 and c.interaction(game.player).get("key","")=="campaign:board","Player physically enters the expedition cabin and receives boarding interaction");print("CABIN_POSITION "+str(game.player.global_position));await capture("inside-cabin");await hold("interact",1.2)
 check(c.state.phase=="DEPARTURE","Manifest and boarding inputs authorize departure")
 if c.state.phase!="DEPARTURE":await finish();return
 if fast:c.send_action("skip",{})
 while c.state.phase=="DEPARTURE":await frame()
 if fast:c.send_action("skip",{})
 while c.state.phase=="CRASH":await frame()
 check(c.state.phase=="CRASH_ORIENTATION" and game.player.alive and game.player.camera.current,"Normal flight/crash restores a living player and gameplay camera")
 await capture("crash-handoff")
 reached=await go(c.world.locations.exit);check(reached,"Crash cabin exit remains physically open")
 var charge=c.world.locations["charge"+str(c.state.charge_site)]
 reached=await go(charge+Vector3(0,0,2.1));check(reached,"Actual movement reaches the mission charge");await hold("interact",1.25)
 check(c.state.bomb=="carried","Charge can be recovered with actual held interaction")
 reached=await go(c.world.locations.secure+Vector3(0,0,2.1));check(reached,"Cargo locker approach remains unobstructed");await hold("interact",1.25)
 check(c.state.bomb=="secured","Recovered charge is secured through gameplay")
 await capture("charge-secured")
 check(await go(c.world.maze.approaches[0],100),"Dirt trail physically reaches the first staged Annu approach")
 var deadline=Time.get_ticks_msec()+65000
 var pursuit=[];var repath_at=0.0;var click_at=0.0
 while c.state.completed_waves==0 and c.state.phase!="DEFEAT" and Time.get_ticks_msec()<deadline:
  var actor=game.player;var target=null;var nearest=INF;var search=null;var search_distance=INF
  for enemy in game.actors:
   if enemy.faction!=1 or not enemy.alive:continue
   var point=enemy.global_position+Vector3.UP*1.1;var distance=actor.global_position.distance_to(point)
   if distance<search_distance:search_distance=distance;search=enemy
   if distance<nearest and c.visible_between(actor.eye.global_position,point):nearest=distance;target=point
  if target!=null:
   pulse("forward",false)
   var direction=(target-actor.eye.global_position).normalized();actor.rotation.y=atan2(-direction.x,-direction.z)-actor.aim_punch.x;actor.eye.rotation.x=asin(direction.y)-actor.aim_punch.y
   if actor.weapons[actor.slot].automatic:pulse("fire",true)
   elif game.now>=click_at:pulse("fire",false);pulse("fire",true);click_at=game.now+.45
  else:
   pulse("fire",false)
   # The test driver pursues known fixture actors, but only fires with genuine LOS.
   # This is input/weapon acceptance, not human balance or a production aim assist.
   if search!=null and game.now>=repath_at:repath_at=game.now+.8;pursuit=c.world.route(actor.global_position,search.global_position+Vector3(8,0,5))
   while not pursuit.is_empty() and Vector2(actor.global_position.x-pursuit[0].x,actor.global_position.z-pursuit[0].z).length()<.8:pursuit.pop_front()
   if not pursuit.is_empty():
    var direction=pursuit[0]-actor.global_position;actor.rotation.y=atan2(-direction.x,-direction.z);actor.eye.rotation.x=0;pulse("forward",true)
   else:pulse("forward",false);actor.rotation.y+=.002
  if actor.ammo[actor.slot]==0:pulse("reload",true)
  else:pulse("reload",false)
  await frame()
 pulse("fire",false);pulse("forward",false);check(c.state.completed_waves>=1,"First real three-enemy wave can be completed using existing weapon simulation")
 for actor in game.actors:print("END_ACTOR id=%d hp=%.1f armor=%.1f alive=%s position=%s ammo=%s"%[actor.net_id,actor.health,actor.armor,str(actor.alive),str(actor.global_position),str(actor.ammo)])
 await capture("first-wave-result");await finish()
