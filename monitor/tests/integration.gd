extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(value: bool,message: String):
 checks+=1;print(("PASS " if value else "FAIL ")+message)
 if not value:failures+=1
func run():
 Engine.max_fps=30
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.endpoint.text="http://127.0.0.1:18080";app.token.text="local-test-monitor-key-not-for-production-0123456789";app.toggle_connection()
 var deadline=Time.get_ticks_msec()+20000
 while app.data.is_empty() and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
 check(not app.data.is_empty(),"native monitor authenticates against actual local master API")
 if app.data.is_empty():print(app.status.text);app.queue_free();quit(1);return
 check(app.status.text.begins_with("CONNECTED"),"successful response shows connected status")
 check(app.playlist_filter.item_count==6,"all five playlists visible in monitor filters")
 check(app.data.game_types.size()==5,"all five game types visible")
 check(app.request.max_redirects==0,"monitor key is never forwarded through HTTP redirects")
 var saved=FileAccess.get_file_as_string("user://monitor.cfg")
 check(not saved.contains(app.token.text) and not saved.contains("token"),"private key is not saved in monitor preferences")
 var end=Time.get_ticks_msec()+65000;var saw_game=false
 while Time.get_ticks_msec()<end:
  if int(app.data.summary.playing_matches)>0:saw_game=true;break
  await create_timer(.2).timeout
 check(saw_game,"monitor displays an actual native player-hosted game while five-playlist QA runs")
 if saw_game:
  for game in app.data.matches:
   if game.phase=="running":print("LIVE MATCH OBSERVED: ",game.playlist," players=",game.online,"/",game.capacity)
 check(app.metric_labels.size()==4,"four clear activity cards exist")
 check(not app.connection_panel.visible,"connection form collapses after successful sign-in")
 check(app.search!=null,"match/player search is available")
 app.search.text="no-such-player-v7-000";app.render_matches();check(app.matches.get_root().get_child_count()==0,"search filters match table")
 app.search.clear();app.render_matches()
 app.endpoint.text="https://user:secret@example.com";check(app.base_url().is_empty(),"embedded credentials in server URL rejected")
 app.endpoint.text="http://example.com";check(app.base_url().is_empty(),"remote unencrypted monitor connection rejected")
 app.endpoint.text="http://127.0.0.1:18080";app.token.text="wrong-local-test-key-not-production-123456789";app.refresh()
 var limit=Time.get_ticks_msec()+12000
 while app.polling and Time.get_ticks_msec()<limit:await create_timer(.1).timeout
 check(not app.polling and app.status.text.contains("401"),"incorrect monitor key stops polling with authentication error")
 check(not app.data.is_empty(),"failure preserves last snapshot instead of showing false live zeros")
 app.clear_key();check(app.token.text.is_empty() and not app.polling,"clear key removes credential and disconnects")
 app.queue_free()
 for i in range(8):await process_frame
 print("MONITOR INTEGRATION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
