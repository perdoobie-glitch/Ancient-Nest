extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;var c=game.campaign;c.save_store.path="user://campaign-spawn-qa.json";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");await physics_frame
 c.state.phase="WAVE_1";c.apply_difficulty()
 for wave in range(5):
  var found=0
  for i in range(NestCampaignState.COUNTS[wave]):
   var position=c.spawn_position(wave,i)
   if position.is_finite():found+=1
  print(("PASS " if found==NestCampaignState.COUNTS[wave] else "FAIL ")+"Wave %d valid concealed, navigable spawn positions: %d / %d"%[wave+1,found,NestCampaignState.COUNTS[wave]])
  if found!=NestCampaignState.COUNTS[wave]:failures+=1
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 quit(1 if failures else 0)
