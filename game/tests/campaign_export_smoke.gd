extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures+=1
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(4):await process_frame
 game.sandbox_mode=true;var c=game.campaign;c.save_store.path="user://packed-nine-missions-qa.json"
 check(c.journey.catalog().size()==8,"Packed chapter data contains all eight new missions")
 c.selected_mission=2;c.begin_solo(false)
 check(c.state.phase=="CHAPTER_INTRO" and c.cinematic.chapter_director.DURATION==15.0,"Packed chapter starts its fifteen-second story scene")
 c.journey.finish_cinematic()
 for i in range(4):await physics_frame
 check(c.state.mission_index==2 and c.state.phase=="CHAPTER" and c.journey.motorcycles.bikes.size()==4,"Packed mission 2 creates four motorcycles")
 check(c.state.weapon_caches.size()==8 and c.world.weapon_cache_points().size()==8,"Packed mission 2 creates eight durable randomized field guns")
 c.journey.start_standalone(3)
 for i in range(3):await physics_frame
 var saved=c.save_store.load_checkpoint();check(not saved.is_empty() and int(saved.mission_index)==3,"Packed mission saves a chapter checkpoint")
 c.exit_campaign();c.begin_solo(true)
 for i in range(3):await physics_frame
 check(c.state.mission_index==3 and c.world.region=="chapter_3" and game.player!=null,"Packed Continue restores the correct world")
 check(c.world.surface_height(c.world.locations.objective2)>c.world.surface_height(c.world.locations.objective0)+8,"Packed walking chapter retains real elevation changes")
 c.journey.start_standalone(9)
 for i in range(3):await physics_frame
 check(c.state.mission_index==9 and c.world.boss_root!=null and game.player.alive,"Packed finale creates Ancient AI machinery")
 c.exit_campaign();game.queue_free()
 for i in range(6):await process_frame
 print("PRIVATE_NINE_MISSIONS_EXPORT_SMOKE ",failures," failures");quit(1 if failures else 0)
