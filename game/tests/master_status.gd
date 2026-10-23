extends SceneTree
var count=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 count+=1
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var h=game.matchmaking.hybrid
 check(h.master_status().ends_with("DISCONNECTED") and not h.master_connected(),"closed connection is not advertised as connected")
 h.enabled=true;h.failure_reason="";h.master_authenticated=false
 check(h.master_status().ends_with("CONNECTING"),"authentication pending displays connecting")
 h.master_authenticated=true;h.master_last_reply=h.clock()
 check(not h.master_connected(),"authentication flag alone cannot fake an open transport")
 check(h.master_status().ends_with("CONNECTION INTERRUPTED"),"closed authenticated transport displays interrupted")
 h.failure_reason="Disconnected"
 check(h.master_status().ends_with("DISCONNECTED"),"failure clears connected status")
 h.leave();check(not h.master_authenticated and h.master_last_reply<0,"leaving resets master authentication and heartbeat age")
 game.queue_free()
 for i in range(8):await process_frame
 print("MASTER STATUS: %d checks, %d failures"%[count,failures]);quit(1 if failures else 0)
