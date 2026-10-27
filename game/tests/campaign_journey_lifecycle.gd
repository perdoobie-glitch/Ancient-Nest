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
func bike_count(world) -> int:
 var count=0
 for child in world.get_children():
  if str(child.name).begins_with("ExpeditionMotorcycle_"):count+=1
 return count
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://journey-lifecycle.json";c.selected_difficulty="Easy";c.begin_solo(false);c.journey.start_standalone(2);c.journey.finish_cinematic();await frames()
 var packet=c.journey.pack();c.journey.receive(packet);var original=c.journey.motorcycles.visuals[1].get_instance_id()
 check(bike_count(c.world)==4,"Initial receive owns exactly four bike visuals")
 c.journey.receive(packet);check(c.journey.motorcycles.visuals[1].get_instance_id()==original and bike_count(c.world)==4,"Ordinary snapshots preserve current bike instance")
 game.match_session+=1;c.journey.receive(packet)
 check(c.journey.motorcycles.visuals[1].get_instance_id()!=original and bike_count(c.world)==4,"New session recreates four bikes without old-world duplicates")
 c.state.chapter_progress={"ride_seconds":95.0,"ride_distance":2600.0};c.state.chapter_stage=2
 c.journey.restore();check(c.journey.motorcycles.bikes[1].ride_seconds==95 and bike_count(c.world)==4,"Checkpoint restore rebuilds safe sector with recorded ride time")
 c.journey.start_standalone(9);c.journey.finish_cinematic();await frames();c.state.chapter_flags.armed=true;c.state.chapter_progress.core_health=350;c.journey.receive({"clock":1.0})
 check(is_instance_valid(c.journey.weakpoint),"Boss snapshot creates authoritative shootable presentation")
 var first=c.journey.weakpoint.get_instance_id();c.journey.receive({"clock":1.2})
 check(c.journey.weakpoint.get_instance_id()==first,"Ordinary boss snapshots retain collision identity")
 c.state.chapter_stage=1;c.journey.receive({"clock":1.3})
 check(c.journey.weakpoint.get_instance_id()!=first and c.journey.weakpoint.global_position.is_equal_approx(c.world.boss_weakpoint(1)),"Stage snapshot moves vulnerability and removes stale collider")
 c.state.chapter_flags.clear();c.journey.receive({"clock":0.0})
 check(not is_instance_valid(c.journey.weakpoint),"Unarmed checkpoint removes hidden stale shootable core")
 c.state.chapter_flags.armed=true;c.journey.receive({"clock":1.0});first=c.journey.weakpoint.get_instance_id();game.match_session+=1;c.journey.receive({"clock":1.0})
 check(c.journey.weakpoint.get_instance_id()!=first,"Same-chapter new session replaces stale boss collision")
 c.journey.start_standalone(3);c.journey.finish_cinematic();c.journey.tick(0)
 var expected=c.state.chapter_enemies.size();var enemy=game.actor_by_id(c.state.chapter_enemies.keys()[0]);enemy.die(game.player,"retry-fixture");c.journey.tick(0)
 var old_session=game.match_session;c.set_phase("DEFEAT");c.retry_checkpoint()
 check(c.state.phase=="CHAPTER" and c.state.chapter_stage==0 and c.state.chapter_spawned.is_empty() and game.match_session!=old_session,"Actual defeat/retry restores safe stage entrance in a fresh session")
 c.journey.tick(0);check(c.state.chapter_enemies.size()==expected and c.state.chapter_defeated.is_empty(),"Retry recreates the opening patrol without phantom prior kills")
 for mission in [2,3,9]:
  c.journey.start_standalone(mission);c.exit_campaign();await frames();c.begin_solo(true);await frames()
  check(c.active and c.world.region=="chapter_"+str(mission) and game.player!=null and game.player.alive,"Initial Continue restores Mission %d directly into correct world"%mission)
  check(c.state.mission_index==mission and c.state.phase=="CHAPTER_INTRO" and c.state.chapter_stage==0,"Initial Continue preserves Mission %d opening scene checkpoint"%mission)
 c.exit_campaign();game.queue_free();await frames()
 print("CAMPAIGN JOURNEY LIFECYCLE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
