extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.set_physics_process(false);game.lobby_network.set_process(false)
 var hub=game.matchmaking.hybrid;hub.set_process(false);hub.scheduler.set_process(false);hub.enabled=true;game.matchmaking.active=true
 var original=game.accounts;var delayed=load("res://tests/delayed_account_fixture.gd").new();delayed.game=game;root.add_child(delayed);game.accounts=delayed
 hub.control_deadline=hub.clock()+10;hub.account_handshake()
 check(hub.control_deadline==0 and game.matchmaking.status.contains("Verifying"),"Account HTTP verification cannot lose a race against the shorter WSS hello timer")
 hub.ws=WebSocketPeer.new();delayed.resolved.emit(false)
 check(hub.failure_reason.is_empty() and not hub.hello_sent,"A stale account callback cannot fail or authenticate a replacement connection")
 game.accounts=original;delayed.queue_free();hub.scheduler.reset();hub._process(0)
 check(game.matchmaking.phase=="error" and hub.scheduler.retry_at>hub.clock(),"Socket closure before hello exposes Reconnect and schedules bounded retry")
 hub.scheduler.reset();hub.control({"type":"failed","reason":"Use matching game version and a valid playlist"})
 check(game.matchmaking.phase=="error" and game.matchmaking.status.contains("matching game version") and hub.scheduler.permanent,"Server rejection retains the actionable reason instead of an endless Connecting screen")
 hub.scheduler.reset();hub.failure_reason="";game.running=true;game.matchmaking.phase="playing"
 hub.control({"type":"failed","reason":"Account verification unavailable"})
 check(game.running and game.matchmaking.phase=="playing","Control-service rejection never terminates established gameplay")
 game.running=false;hub.enabled=false;game.queue_free();await process_frame;print("MATCHMAKING CONNECT failures: "+str(failures));quit(1 if failures else 0)
