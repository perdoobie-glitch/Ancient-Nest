extends SceneTree
var checks=0
func ok(value: bool,message: String):
 checks+=1
 assert(value,message)
 if not value:push_error(message);quit(1)
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 var snapshot={"release":"10.2","generated_at":1792620000,"summary":{"online_players":30,"searching_players":0,"playing_matches":3,"reconnecting_slots":0,"forming_matches":0,"results_matches":0,"parties":0,"started":3,"finished":0,"failed":0},"capabilities":{"turn_configured":true,"accounts_configured":true,"guest_mode":false},"playlists":[],"game_types":[],"recent":[],"matches":[]}
 var names=["Connectuct","Qaytal","Temple"]
 for id in range(3,6):
  snapshot.matches.append({"id":"fixture-map-"+str(id),"playlist":"bomb_5v5","mode":4,"map":id,"phase":"running","online":10,"capacity":10,"host":"FixtureHost","age_seconds":45,"disconnected":0,"epoch":1,"live":{"scores":[1,2]},"players":[{"name":"FixturePlayer","team":0,"online":true,"host":true}]})
 app.polling=true;app.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(snapshot).to_utf8_buffer())
 ok(app.status.text.begins_with("CONNECTED"),"10.2 monitor response is accepted")
 var item=app.matches.get_root().get_first_child()
 for name in names:
  ok(item!=null and item.get_text(2)==name,"Correct new map name "+name);ok(item.get_text(4)=="10 / 10","Full 5v5 roster visible");ok(item.get_text(7)=="1 : 2","Live score visible");item=item.get_next()
 app.show_detail(snapshot.matches[0]);ok(app.detail.text.contains("FixturePlayer"),"Player details retained")
 app.completed(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),PackedByteArray())
 ok(not app.polling and app.status.text.contains("401") and app.data.matches.size()==3,"Authentication failure preserves stale snapshot and stops polling")
 app.queue_free();await create_timer(.2).timeout;print("FRONTIER MONITOR: ",checks," checks passed");quit()
