extends SceneTree
# Existing Annu must actually pursue across an opened raised route and shoot.
var game
var failures=0
var checks=0
func check(ok: bool,label: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(n=2):
 for i in range(n):await physics_frame
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 seed(260026)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://route-pressure-qa.json";c.selected_difficulty="Medium";c.begin_solo(false);game.set_physics_process(false);c.set_process(false)
 var selected=int(OS.get_environment("NEST_PRESSURE_MISSION"));var missions=[selected] if selected in [3,7,8] else [3,7,8]
 for mission in missions:
  c.journey.start_standalone(mission);c.journey.finish_cinematic();game.input_window_focused=true;c.journey.tick(0)
  var hero=game.player;hero.set_physics_process(false);hero.health=10000;hero.shield=10000
  for actor in game.actors:actor.set_physics_process(false)
  var pursuer=game.actor_by_id(c.state.chapter_enemies.keys()[0])
  if mission==missions[0]:
   var movement=NestBotMovement.new(pursuer);var original_health=pursuer.health
   check(pursuer.damage_model()=="annu" and pursuer.shield==0 and not movement.vulnerable(),"Healthy armoured Annu does not retreat because its species has no energy shield")
   pursuer.health=pursuer.tuning.health_capacity*.3
   check(movement.vulnerable(),"Seriously injured Annu still seeks defensive cover")
   pursuer.health=original_health
   var hero_movement=NestBotMovement.new(hero);var original_shield=hero.shield;hero.shield=0
   check(hero_movement.vulnerable(),"Naki with depleted energy shield still seeks defensive cover")
   hero.shield=original_shield
   check(not hero_movement.vulnerable(),"Healthy fully shielded Naki retains aggressive movement")
  hero.global_position=c.world.locations.objective0+Vector3(0,.25,2);await frames()
  check(c.journey.interact(hero,"journey:objective") and c.state.chapter_stage==1,"Mission %d route opens while its patrol remains alive"%mission)
  var start=Vector3(0,0,-15);start.y=c.world.surface_height(start)+.25;pursuer.global_position=start;pursuer.controlled=Vector3.ZERO;pursuer.external=Vector3.ZERO;pursuer.velocity=Vector3.ZERO
  pursuer.remove_meta("ambush_wait");pursuer.set_physics_process(true)
  var destination=c.world.stage_center(1)+Vector3(0,.25,2);hero.global_position=destination
  var resources=hero.health+hero.shield;var max_height=pursuer.global_position.y;var min_height=max_height
  for frame in range(840):
   if frame==360:
    destination+=Vector3(0,0,-10);destination.y=c.world.surface_height(destination)+.25;hero.global_position=destination
   game.now+=1.0/60.0;game.input_window_focused=true;await physics_frame
   if not is_instance_valid(pursuer):break
   max_height=maxf(max_height,pursuer.global_position.y);min_height=minf(min_height,pursuer.global_position.y)
   if frame%120==119 and OS.get_environment("NEST_PRESSURE_DIAGNOSTIC")=="1":
    var movement=pursuer.bot_movement;var toward=destination-pursuer.global_position;toward.y=0;toward=toward.normalized()
    var clear=movement.clear_direction(toward);var contacts=[]
    for contact_index in range(movement.motion_result.get_collision_count()):
     var body=movement.motion_result.get_collider(contact_index)
     contacts.append({"normal":movement.motion_result.get_collision_normal(contact_index),"body":str(body.get_path()) if body is Node else str(body)})
    print("PURSUIT_DIAGNOSTIC ",{"frame":frame,"target":pursuer.target.net_id if pursuer.target!=null else 0,"goal":c.enemy_goal(pursuer),"route":pursuer.bot_route,"position":pursuer.global_position,"velocity":pursuer.velocity,"controlled":pursuer.controlled,"external":pursuer.external,"desired":movement.desired,"steering":movement.steering,"contact_normal":movement.contact_normal,"floor":pursuer.is_on_floor(),"clear":clear,"contacts":contacts})
   if frame>360 and pursuer.global_position.distance_to(destination)<14 and hero.health+hero.shield<resources:break
  check(is_instance_valid(pursuer) and pursuer.alive and pursuer.global_position.distance_to(destination)<16 and absf(pursuer.global_position.y-destination.y)<.65,"Mission %d surviving Annu physically pursues onto the next terrace after target retreat"%mission)
  check(max_height-min_height>2.0,"Mission %d pursuer crosses actual elevation"%mission)
  check(hero.health+hero.shield<resources,"Mission %d pursuer fires real projectiles and damages an exposed target"%mission)
  print("PRESSURE ",mission," position ",pursuer.global_position," distance ",pursuer.global_position.distance_to(destination)," height ",max_height-min_height," damage ",resources-hero.health-hero.shield," remaining_route ",pursuer.bot_route)
 c.exit_campaign();game.queue_free();game=null;c=null;await frames();print("ROUTE PRESSURE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
