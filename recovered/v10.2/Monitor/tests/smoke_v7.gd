extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.endpoint.text="http://127.0.0.1:18080";app.token.text="local-test-monitor-key-not-for-production-0123456789";app.toggle_connection()
 var until=Time.get_ticks_msec()+15000
 while app.data.is_empty() and Time.get_ticks_msec()<until:await create_timer(.1).timeout
 var ok=not app.data.is_empty() and app.metric_labels.size()==4 and not app.connection_panel.visible
 if ok:
  for key in app.metric_labels:ok=ok and app.metric_labels[key].text.is_valid_int()
 app.clear_key();app.queue_free();await create_timer(.2).timeout;print("V7 EXPORTED MONITOR: ","PASS" if ok else "FAIL");quit(0 if ok else 1)
