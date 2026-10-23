extends SceneTree
class Bridge extends NestHybridNetwork:
 var online=true
 var sent=[]
 func master_connected() -> bool:return online
 func send(message: Dictionary) -> void:sent.append(message)
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
 checks+=1;print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures+=1
func settle():
 for i in range(5):await process_frame
func view(game):return game.screen.get_node("MatchmakingView")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle();var mm=game.matchmaking
 mm.hybrid.queue_free();var bridge=Bridge.new();bridge.game=game;bridge.mm=mm;bridge.player_id="me";bridge.enabled=true;bridge.cloud=true;mm.hybrid=bridge;mm.add_child(bridge)
 mm.active=true;mm.phase="party";mm.party_mode=true;mm.playlist="tactical_3v3";mm.party={"code":"TEST","leader":"me","members":[{"user":"me","name":"Player","leader":true}]};game.show_matchmaking();await settle()
 check(view(game).playlist_buttons.size()==5,"Five visible playlist cards")
 check(view(game).playlist_buttons.all(func(b):return not b.text.contains("PLAYERS") and not b.text.contains("\n")),"Playlist cards have no extra player counts")
 check(view(game).radar!=null and view(game).atmosphere!=null,"Search radar and background effects are installed")
 check(game.screen.find_child("MotionToggle",true,false)!=null,"Reduced-motion switch available")
 check(view(game).search_button.text=="Search","Separate Search action")
 view(game).search_or_cancel();var end=mm.search_countdown_until
 check(end>mm.clock()+2.8 and bridge.sent.is_empty(),"Search starts three-second countdown without queueing")
 mm.advance_search_countdown(end-.01);check(bridge.sent.is_empty(),"No early search")
 view(game).search_or_cancel();mm.advance_search_countdown(end+1);check(bridge.sent.is_empty(),"Cancellation prevents search")
 view(game).search_or_cancel();mm.advance_search_countdown(mm.search_countdown_until+.01)
 check(bridge.sent.size()==1 and bridge.sent[0].type=="party_search","Countdown sends exactly one server search")
 mm.advance_search_countdown(mm.clock()+10);check(bridge.sent.size()==1,"No repeated search requests")
 mm.begin_search_countdown();bridge.online=false;mm.advance_search_countdown(mm.search_countdown_until+1);check(mm.search_countdown_until==0 and bridge.sent.size()==1,"Disconnect cancels countdown")
 await settle();check(view(game).master_label.text.contains("DISCONNECTED") and view(game).search_button.disabled,"Disconnected signal and disabled search")
 bridge.online=true;mm.begin_search_countdown();view(game).choose_playlist(3);check(mm.search_countdown_until==0 and bridge.sent[-1].type=="party_playlist","Playlist selection cancels countdown without searching")
 mm.party.members.append({"user":"friend","name":"Friend","leader":false});game.show_matchmaking();await settle()
 check(view(game).playlist_buttons[0].disabled and not view(game).playlist_buttons[1].disabled,"Party of two fits Doubles but not Duel")
 mm.begin_search_countdown();mm.party.members.append({"user":"other","name":"Other"});mm.advance_search_countdown(mm.search_countdown_until+1);check(mm.search_countdown_until==0,"Roster change cancels pending search")
 var old_members=mm.party.members.duplicate();mm.party.members=[]
 for i in range(6):mm.party.members.append({"user":str(i),"name":"Test"})
 check(not mm.can_start_search() and not mm.begin_search_countdown(),"Party larger than five cannot search")
 mm.party.members=old_members
 bridge.player_id="friend";check(not mm.begin_search_countdown(),"Only party leader starts countdown")
 bridge.player_id="me";mm.phase="queue";game.show_matchmaking();await settle();var v=view(game);v.elapsed=0;v._process(0);var first=v.pulse.text;v._process(.45);check(v.pulse.text!=first,"Searching dots appear and disappear")
 for size in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await settle();var scroll=game.screen.find_children("*","ScrollContainer",true,false)[0];check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"No horizontal overflow at "+str(size))
 mm.leave();game.stop_game();game.queue_free();await create_timer(.3).timeout;print("8.0 LOBBY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
