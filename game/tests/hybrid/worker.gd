extends SceneTree
var game
var done=false
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=60
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 while true:
  await create_timer(.25).timeout
  if not done and game.running and not game.matchmaking.hybrid.session.frozen and FileAccess.file_exists(OS.get_environment("NEST_QA_FIXTURE")):
   load(OS.get_environment("NEST_QA_FIXTURE_SCRIPT") if OS.has_environment("NEST_QA_FIXTURE_SCRIPT") else "res://tests/hybrid/fixture.gd").apply(game);done=true
