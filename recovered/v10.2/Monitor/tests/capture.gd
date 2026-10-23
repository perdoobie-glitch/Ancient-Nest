extends SceneTree
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=30
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.endpoint.text="http://127.0.0.1:18080";app.token.text="local-test-monitor-key-not-for-production-0123456789";app.toggle_connection()
 var until=Time.get_ticks_msec()+110000
 while Time.get_ticks_msec()<until:
  if not app.data.is_empty() and int(app.data.summary.playing_matches)>0 and int(app.data.summary.online_players)>0:break
  await create_timer(.2).timeout
 if app.data.is_empty():quit(1);return
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v7/monitor-overview.png")
 var tabs=app.find_children("*","TabContainer",true,false)[0];tabs.current_tab=1
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v7/monitor-matches.png")
 FileAccess.open("/workspace/work/v7/monitor-captured",FileAccess.WRITE).store_string("captured")
 print("MONITOR VISUAL captured actual local coordinator data")
 app.queue_free()
 for i in range(8):await process_frame
 quit()
