extends SceneTree
class FakeGame extends Node:
 var running=false
 var film_retaining_transport=false
 var current_screen="server_browser"
 var screen=Control.new()
 func _ready():add_child(screen)
class FakeHub extends NestHybridNetwork:
 var messages=[]
 func _ready():
  add_child(session);add_child(rtc);session.set_process(false);rtc.set_process(false);set_process(false)
 func master_connected() -> bool:return true
 func send(packet: Dictionary):messages.append(packet.duplicate(true))
class ClockMM extends NestMatchmaking:
 var at=0.0
 var window_visible=true
 func _ready():set_process(false)
 func clock() -> float:return at
 func browser_window_visible() -> bool:return window_visible
var failures=0
var checks=0
func check(ok: bool,text: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var game=FakeGame.new();root.add_child(game)
 if DisplayServer.get_name()=="headless":
  var native_visibility=NestMatchmaking.new();native_visibility.game=game
  check(native_visibility.browser_window_visible(),"Headless logical screens do not require a physical native window")
  native_visibility.free()
 var mm=ClockMM.new();mm.game=game;game.add_child(mm)
 var hub=FakeHub.new();hub.game=game;hub.mm=mm;hub.enabled=true;hub.cloud=true;mm.hybrid=hub;mm.add_child(hub)
 mm.browser_mode=true;mm.phase="party";mm.party={"server_browser_supported":true}
 mm._process(0)
 check(hub.messages.size()==1,"Opening the visible browser immediately requests its directory")
 var first=mm.browser_pending
 mm._process(0)
 check(hub.messages.size()==1,"An outstanding request is not duplicated each frame")
 hub.handle_control({"type":"server_list","request_id":first,"lobbies":[{"name":"Known lobby"}]})
 check(mm.browser_loaded and mm.browser_pending.is_empty(),"Matching directory reply completes its request")
 mm.at=14.999;mm._process(0)
 check(hub.messages.size()==1,"No periodic refresh before fifteen seconds")
 mm.at=15;mm._process(0)
 check(hub.messages.size()==2,"Visible directory refreshes at fifteen seconds")
 hub.handle_control({"type":"server_list","request_id":mm.browser_pending,"lobbies":mm.browser_lobbies})
 mm.at=16;mm.refresh_browser()
 var manual=mm.browser_pending
 check(hub.messages.size()==3,"Manual Refresh works while the browser is visible")
 hub.handle_control({"type":"server_list","request_id":manual,"lobbies":mm.browser_lobbies})
 mm.at=16.1;mm.refresh_browser()
 check(hub.messages.size()==3,"Repeated manual refresh is rate limited")
 mm.at=18;mm.refresh_browser();var old=mm.browser_pending
 check(hub.messages.size()==4,"Manual refresh becomes available after its rate limit")
 game.current_screen="settings";mm.at=40;mm._process(0)
 check(mm.browser_pending.is_empty() and hub.messages.size()==4,"Closing the screen stops polling and invalidates its request")
 hub.handle_control({"type":"server_list","request_id":old,"lobbies":[]})
 check(mm.browser_lobbies.size()==1,"A late reply cannot replace the retained list on a closed screen")
 game.current_screen="server_browser";mm.at=41;mm._process(0)
 check(hub.messages.size()==5 and mm.browser_pending!=old,"Reopening refreshes immediately with a new generation")
 hub.handle_control({"type":"server_list","request_id":old,"lobbies":[]})
 check(mm.browser_lobbies.size()==1 and not mm.browser_pending.is_empty(),"A previous view cannot complete the new view's request")
 var before_minimize=mm.browser_pending;mm.window_visible=false;mm.at=42;mm._process(0);mm.at=100;mm._process(0)
 check(hub.messages.size()==5 and mm.browser_pending.is_empty(),"Minimized or hidden game windows stop directory polling")
 hub.handle_control({"type":"server_list","request_id":before_minimize,"lobbies":[]})
 check(mm.browser_lobbies.size()==1,"A reply while minimized is discarded")
 mm.window_visible=true;mm.at=101;mm._process(0)
 check(hub.messages.size()==6,"Restoring the game window refreshes immediately")
 var current=mm.browser_pending
 hub.handle_control({"type":"server_list","request_id":current,"lobbies":mm.browser_lobbies})
 hub.handle_control({"type":"server_list","lobbies":[]})
 check(mm.browser_lobbies.size()==1,"Unsolicited replies with an empty request ID are ignored")
 mm.phase="queue";mm.at=200;mm._process(0)
 check(hub.messages.size()==6,"Queued players do not poll the server directory")
 mm.phase="party";game.running=true;mm._process(0)
 check(hub.messages.size()==6,"Established gameplay does not poll the server directory")
 game.running=false;mm.at=201;mm._process(0);var delayed=mm.browser_pending
 mm.at=211;mm._process(0)
 check(mm.browser_pending.is_empty() and hub.messages.size()==7 and mm.browser_failures==1,"Ten-second request timeout preserves the previous list without immediate retry")
 hub.handle_control({"type":"server_list","request_id":delayed,"lobbies":[]})
 check(mm.browser_lobbies.size()==1,"Timed-out responses cannot clear the cached list")
 mm.at=226;mm._process(0)
 check(hub.messages.size()==8,"Directory retries after the configured interval")
 game.free();print("BROWSER SCHEDULE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
