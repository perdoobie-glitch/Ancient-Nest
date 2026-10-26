extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func run():
 check(NestWeaponCatalog.profile("plasma_pistol").magazine==8,"Naki pistol runtime magazine contains eight rounds")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://staging-qa.json";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");c.state.bomb="secured"
 game.set_physics_process(false);game.player.set_physics_process(false)
 for wave in range(5):
  game.player.global_position=c.world.maze.approaches[wave]+Vector3.UP*.25;c.tick(0)
  check(c.state.phase=="WAVE_"+str(wave+1),"Approach starts stage %d before the clearing is reached"%(wave+1))
  for i in range(NestCampaignState.COUNTS[wave]+20):
   game.now+=.36;c.update_wave()
   for actor in game.actors:actor.set_physics_process(false)
   await physics_frame
  check(c.state.enemies.size()==NestCampaignState.COUNTS[wave],"All %d Annu stage ahead while the player is still on the approach"%NestCampaignState.COUNTS[wave])
  var separated=true
  for id in c.state.enemies:
   var enemy=game.actor_by_id(int(id))
   if enemy==null or not enemy.alive or enemy.global_position.distance_to(game.player.global_position)<12:separated=false
  check(separated,"Stage %d uses actual live defenders away from the player"%(wave+1))
  var ambusher=game.actor_by_id(-1000-wave*100-1)
  check(ambusher!=null and ambusher.has_meta("ambush_wait"),"Stage %d includes a concealed waiting ambusher"%(wave+1))
  if ambusher!=null:
   var saved=game.player.global_position;game.player.global_position=ambusher.global_position+Vector3(60,0,0)
   var idle=c.bot_intent(ambusher,.016)
   check(ambusher.has_meta("ambush_wait") and idle.move==Vector2.ZERO,"Ambusher holds position before the squad approaches")
   game.player.global_position=ambusher.global_position+Vector3(10,0,0)
   var spring=c.bot_intent(ambusher,.016)
   check(not ambusher.has_meta("ambush_wait") and spring.jump,"Nearby squad triggers a single surprise leap")
   game.player.global_position=saved
  for id in c.state.enemies.keys():game.actor_by_id(int(id)).die(game.player,"qa")
  c.update_wave();await process_frame
 check(c.state.radio_ready() and c.state.defeated.size()==34,"Five staged encounters preserve exact counts and final radio requirements")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
