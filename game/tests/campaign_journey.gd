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
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://journey-integration.json";c.selected_difficulty="Easy";c.begin_solo(false)
 for mission in range(3,10):
  check(c.journey.start_standalone(mission),"Mission %d starts playable expedition"%mission);await frames()
  game.input_window_focused=true
  check(c.world.region=="chapter_"+str(mission) and game.player!=null,"Mission %d creates its own world and hero"%mission)
  for stage in range(4):
   var actor=game.player;actor.health=10000;actor.shield=10000
   c.journey.tick(0);await frames()
   check(c.state.chapter_spawned.size()==c.state.chapter_expected and c.state.chapter_enemies.size()==c.state.chapter_expected,"Mission %d stage %d contains its authored Annu encounter"%[mission,stage])
   actor.global_position=c.world.locations["objective"+str(stage)]+Vector3(0,.1,2);await frames()
   var spec=c.journey.stage_data();var mode=str(spec.get("mode","assault"))
   if mode=="hold":
    check(c.journey.interact(actor,"journey:arm"),"Defense relay activates while defenders are alive")
    c.journey.tick(float(spec.hold_seconds));check(float(c.state.chapter_progress.get("hold_seconds",0))>=float(spec.hold_seconds),"Nearby defender progresses hold timer")
   if c.state.chapter_expected>0:check(not c.journey.interact(actor,"journey:objective"),"Living defenders block objective bypass")
   else:check(c.state.phase=="CHAPTER","Peaceful finale still requires deliberate physical objective")
   for id in c.state.chapter_enemies.keys():
    var enemy=game.actor_by_id(id)
    if enemy!=null:enemy.die(actor,"journey-fixture")
   c.journey.tick(0);c.loot.clear();await frames()
   check(c.state.chapter_clear(),"Real actor deaths clear stage encounter")
   if mission==9 and stage<3:
    check(c.journey.interact(actor,"journey:arm"),"Boss vulnerability requires physical terminal activation")
    await frames();var target=c.world.boss_weakpoint(stage)
    if stage==0:
     var saved_position=actor.global_position;actor.global_position=Vector3(-24,.25,-55);var resources=actor.health+actor.shield
     c.journey.clock=4;c.journey._boss_hazards();check(actor.health+actor.shield==resources,"Boss warning gives a dodge window before damage")
     actor.global_position=Vector3(-24,.25,-48.3);c.journey.clock=5.5;c.journey._boss_hazards()
     check(not c.visible_between(Vector3(0,8,-55),actor.global_position+Vector3.UP*.7) and actor.health+actor.shield==resources,"Solid stone baffle blocks actual boss pulse")
     actor.global_position=Vector3(-24,.25,-55);c.journey._boss_hazards();check(actor.health+actor.shield<resources,"Telegraphed active lane damages exposed hero")
     actor.global_position=saved_position
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
   await frames()
  check(c.state.phase=="CHAPTER_COMPLETE","Mission %d reaches persistent completion"%mission)
  check(c.save_store.load_checkpoint().get("mission_index",0)==mission and c.save_store.load_checkpoint().get("phase","")=="CHAPTER_COMPLETE","Mission %d completion checkpoint loads"%mission)
 c.exit_campaign();game.queue_free();await frames()
 print("CAMPAIGN JOURNEY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
