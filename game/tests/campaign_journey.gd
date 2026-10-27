extends SceneTree
var game
var failures=0
var checks=0
func check(ok: bool,text: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(n=2):
 for i in range(n):await physics_frame
func freeze_actors():
 for actor in game.actors:actor.set_physics_process(false)
func clear_present_defenders(c):
 for id in c.state.chapter_enemies.keys():
  var enemy=game.actor_by_id(id)
  if enemy!=null:enemy.die(game.player,"journey-fixture")
 c.journey.tick(0);freeze_actors()
func test_boss_lanes(c,actor):
 var covered=Vector3.INF;var exposed=Vector3.INF;var source=c.world.boss_attack_origin()
 for x in range(-29,-18,2):
  for z in range(-80,-25,2):
   var point=Vector3(x,0,z);point.y=c.world.surface_height(point)+.25
   if point.y< -100 or c.world.blocked_point(point):continue
   if c.visible_between(source,point+Vector3.UP*.7):exposed=point
   else:covered=point
 check(covered.is_finite() and exposed.is_finite(),"Boss arena has both actual sheltered and exposed floor-lane positions")
 if not covered.is_finite() or not exposed.is_finite():return
 var saved=actor.global_position;actor.global_position=exposed;var resources=actor.health+actor.shield
 c.journey.clock=4;c.journey._boss_hazards();check(actor.health+actor.shield==resources,"Boss warning gives a dodge window before damage")
 actor.global_position=covered;c.journey.clock=5.5;c.journey._boss_hazards();check(actor.health+actor.shield==resources,"Actual machinery cover protects from a warned discharge")
 actor.global_position=exposed;c.journey._boss_hazards();check(actor.health+actor.shield<resources,"Telegraphed active lane damages exposed hero across the new terrain")
 actor.global_position=saved
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://journey-integration.json";c.selected_difficulty="Easy";c.begin_solo(false)
 for mission in range(3,10):
  check(c.journey.start_standalone(mission),"Mission %d starts playable expedition"%mission);await frames()
  game.input_window_focused=true;game.set_physics_process(false);c.set_process(false);freeze_actors()
  check(c.state.phase=="CHAPTER_INTRO" and c.frozen_actors() and not c.can_damage(game.player),"Opening scene protects and holds the squad")
  c.phase_elapsed=14.99;c.tick(0);check(c.state.phase=="CHAPTER_INTRO","Opening story scene lasts the full fifteen seconds")
  c.tick(.02);check(c.state.phase=="CHAPTER","Opening scene hands control to the player")
  check(c.world.region=="chapter_"+str(mission) and game.player!=null,"Mission %d creates its own world and hero"%mission)
  for stage in range(4):
   var actor=game.player;actor.health=10000;actor.shield=10000
   c.journey.tick(0);freeze_actors();await frames()
   check(c.state.chapter_spawned.size()>0 and c.state.chapter_spawned.size()<=c.state.chapter_expected,"Mission %d stage %d activates a route encounter"%[mission,stage])
   var opening_count=c.state.chapter_spawned.size()
   actor.global_position=c.world.locations["objective"+str(stage)]+Vector3(0,.1,2);await frames()
   c.journey.tick(0);freeze_actors()
   var spec=c.journey.stage_data();var mode=str(spec.get("mode","assault"))
   if mode=="traverse":
    check(c.state.chapter_spawned.size()>=opening_count,"Approaching the route objective activates further Annu positions")
    check(not c.journey.interaction(actor).is_empty(),"Traversal objective remains usable while defenders are alive")
   if mode in ["hold","extraction"]:
    check(c.journey.interact(actor,"journey:arm"),"Defense relay activates while defenders are alive")
    var destination=actor.global_position;actor.global_position+=Vector3(0,0,22);c.journey.tick(4)
    check(float(c.state.chapter_progress.get("hold_seconds",0))==0,"Leaving the destination pauses its defense countdown")
    actor.global_position=destination;c.journey.tick(float(spec.hold_seconds));c.journey.tick(0);freeze_actors()
    check(float(c.state.chapter_progress.get("hold_seconds",0))>=float(spec.hold_seconds),"Holding the destination completes the departure countdown")
   var follower=null
   if mode=="traverse" and stage==0:follower=game.actor_by_id(c.state.chapter_enemies.keys()[0])
   else:
    clear_present_defenders(c);clear_present_defenders(c)
    check(c.state.chapter_defeated.size()>0,"Real actor deaths are recorded in the current encounter")
   c.loot.clear();await frames()
   if mission==9 and stage<3:
    check(c.journey.interact(actor,"journey:arm"),"Boss vulnerability requires physical terminal activation")
    await frames();var target=c.world.boss_weakpoint(stage)
    if stage==0:
     test_boss_lanes(c,actor)
    var before=float(c.state.chapter_progress.get("core_health",0));c.journey.clock=4
    check(not c.journey.hit_weakpoint(actor,100,900000+stage) and c.state.chapter_progress.core_health==before,"Closed boss core refuses premature damage")
    c.journey.clock=1
    var bullet=load("res://scripts/bullet.gd").new();bullet.game=game;bullet.owner_actor=actor;bullet.profile=NestWeaponCatalog.profile("plasma_br");bullet.event_id=100000+stage*100;bullet.direction=Vector3.FORWARD
    for hitbox in actor.hitboxes:bullet.excludes.append(hitbox.get_rid())
    check(bullet.resolve_hit(target+Vector3(0,0,3),target-Vector3(0,0,3)),"Real projectile intersects machinery weakness")
    check(float(c.state.chapter_progress.core_health)<before,"Actual projectile damages exposed core")
    var after=float(c.state.chapter_progress.core_health)
    check(not c.journey.hit_weakpoint(actor,100,bullet.event_id) and float(c.state.chapter_progress.core_health)==after,"Duplicate projectile cannot damage core twice")
    for shot in range(20):c.journey.hit_weakpoint(actor,100,100001+stage*100+shot)
    bullet.free();check(float(c.state.chapter_progress.core_health)==0,"Boss machinery core can be destroyed through confirmed hits")
   var option=c.journey.interaction(actor)
   check(not option.is_empty() and c.journey.interact(actor,"journey:objective"),"Mission %d stage %d physical objective advances"%[mission,stage])
   if follower!=null:check(is_instance_valid(follower) and follower.alive and follower in game.actors,"Living Annu continue pursuing after a route stage advances")
   check(NestCampaignState.valid(c.state.pack()),"Stage progression remains valid for saves and co-op replication")
   await frames()
  check(c.state.phase=="CHAPTER_OUTRO" and c.frozen_actors(),"Mission destination opens its closing story scene")
  c.phase_elapsed=14.99;c.tick(0);check(c.state.phase=="CHAPTER_OUTRO","Closing story scene lasts the full fifteen seconds")
  c.tick(.02)
  check(c.state.phase=="CHAPTER_COMPLETE","Mission %d reaches persistent completion"%mission)
  check(c.save_store.load_checkpoint().get("mission_index",0)==mission and c.save_store.load_checkpoint().get("phase","")=="CHAPTER_COMPLETE","Mission %d completion checkpoint loads"%mission)
 c.exit_campaign();game.queue_free();await frames()
 print("CAMPAIGN JOURNEY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
