extends SceneTree
var output_dir: String
class Probe extends Node:
 var owner_tree
 var callbacks=[]
 var draws=[]
 var active=false
 func _input(event):
  if active and event is InputEventMouseMotion:
   callbacks.append({"at_us":int(Time.get_unix_time_from_system()*1000000),"dx":event.screen_relative.x})
 func frame_done():
  if active:draws.append(int(Time.get_unix_time_from_system()*1000000))
func _initialize():call_deferred("run")
func frames(n=6):
 for i in range(n):await process_frame
func run():
 output_dir=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path("user://input-benchmark")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.selected_faction=0;game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true
 var probe=Probe.new();root.add_child(probe);RenderingServer.frame_post_draw.connect(probe.frame_done)
 var results=[]
 for i in range(4):
  Input.use_accumulated_input=(i%2==0);await frames(10);probe.callbacks=[];probe.draws=[];probe.active=true
  FileAccess.open(output_dir+"/bench-ready",FileAccess.WRITE).store_string(str(i))
  var deadline=Time.get_ticks_msec()+15000
  while Time.get_ticks_msec()<deadline:
   if FileAccess.file_exists(output_dir+"/bench-done-"+str(i)):break
   await process_frame
  await frames(3);probe.active=false
  results.append({"accumulated":Input.use_accumulated_input,"callbacks":probe.callbacks,"draws":probe.draws})
 FileAccess.open(output_dir+"/bench-received.json",FileAccess.WRITE).store_string(JSON.stringify(results))
 game.stop_game();game.queue_free();probe.queue_free();await frames();quit()
