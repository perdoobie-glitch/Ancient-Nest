extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;var c=game.campaign;c.save_store.path="user://campaign-spawn-qa.json";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");await physics_frame
 c.state.phase="WAVE_1";c.apply_difficulty()
 for wave in range(5):
  game.player.global_position=c.world.maze.approaches[wave]+Vector3.UP*.2
  var found=0
  for direction in range(4):
   game.player.rotation.y=direction*PI*.5
   for i in range(NestCampaignState.COUNTS[wave]):
    var position=c.spawn_position(wave,i)
    if position.is_finite():found+=1
  var expected=NestCampaignState.COUNTS[wave]*4
  print(("PASS " if found==expected else "FAIL ")+"Wave %d ahead-of-squad concealed staging across four viewing directions: %d / %d"%[wave+1,found,expected])
  if found!=expected:failures+=1
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 quit(1 if failures else 0)
