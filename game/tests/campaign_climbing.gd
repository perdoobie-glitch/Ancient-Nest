extends "res://tests/campaign_maze.gd"
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 c=game.campaign;c.save_store.path="user://climbing-qa.json";c.begin_solo(false);c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");c.state.phase="RADIO_READY";c.state.completed_waves=5
 var actor=game.player;var site=c.world.maze.vertical_sites[0];actor.global_position=site.entry+Vector3.UP*.8;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;pulse(false)
 for i in range(30):await physics_frame
 var climbed=true
 for step in site.steps:
  if not await jump_to(step):climbed=false;print("CLIMB_STOP ",actor.global_position," target ",step);break
 check(climbed and actor.global_position.y>3,"Actual jump input climbs all five solid branch platforms")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
