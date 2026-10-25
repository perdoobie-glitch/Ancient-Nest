extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;var c=game.campaign;c.save_store.path="user://campaign-combat-qa.json";c.selected_difficulty="Angel";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");await physics_frame
 c.state.phase="WAVE_5";c.state.completed_waves=4;c.apply_difficulty();c.phase_elapsed=0;c.spawn_at=game.now
 for slot in range(2,5):c.members[slot]=c.local_member(slot,0,"Load fixture");c.members[slot].loaded=c.phase_epoch;c.make_actor(slot,true,0,"Load fixture")
 for slot in c.members:
  c.flashlights[slot]=true;var actor=game.actor_by_id(slot);actor.health=100000;actor.shield=100000
 c.data.difficulties.Angel.spawn_gap=.12
 var maximum=0;var initial_positions={};var moved=0.0
 for i in range(720):
  await physics_frame
  maximum=maxi(maximum,c.state.enemies.size())
  for id in c.state.enemies:
   var actor=game.actor_by_id(id)
   if actor!=null:
    if not initial_positions.has(id):initial_positions[id]=actor.global_position
    else:moved=maxf(moved,actor.global_position.distance_to(initial_positions[id]))
 var costs=game.physics_samples.duplicate();costs.sort();var p95=float(costs[int(costs.size()*.95)]) if not costs.is_empty() else 0.0
 print(("PASS " if maximum==12 else "FAIL ")+"Maximum wave spawns twelve actual AI actors: "+str(maximum))
 print(("PASS " if moved>3 else "FAIL ")+"AI physically follows crash-site navigation: distance "+str(moved))
 if maximum!=12 or moved<=3:failures+=1
 var lamps=0
 for actor in game.actors:
  if actor.faction==0 and actor.eye.get_node_or_null("CampaignFlashlight")!=null:lamps+=1
 print(("PASS " if lamps==4 else "FAIL ")+"Four independent flashlight nodes: "+str(lamps));if lamps!=4:failures+=1
 var smoke=c.world.smoke_volumes[0];var a=smoke.center+Vector3(-6,0,0);var b=smoke.center+Vector3(6,0,0)
 print(("PASS " if not c.visible_between(a,b) else "FAIL ")+"Opaque smoke blocks AI perception at every graphics quality");if c.visible_between(a,b):failures+=1
 print("CAMPAIGN COMBAT: max_ai=%d, motion_m=%.2f, four_lights=%d, simulation_p95_ms=%.3f, sample_ticks=%d"%[maximum,moved,lamps,p95,costs.size()])
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 quit(1 if failures else 0)
