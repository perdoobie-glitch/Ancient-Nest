extends SceneTree
class ConnectedBridge extends NestHybridNetwork:
 func master_connected() -> bool:return true
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func settle():
 for i in range(8):await process_frame
func button(game,text: String):
 for node in game.screen.find_children("*","Button",true,false):
  if node.text==text:return node
 return null
func run():
 Engine.max_fps=60
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
 var mm=game.matchmaking;
 var original_bridge=mm.hybrid;original_bridge.get_parent().remove_child(original_bridge);original_bridge.queue_free();mm.hybrid=ConnectedBridge.new();mm.hybrid.game=game;mm.hybrid.mm=mm;mm.add_child(mm.hybrid)
 mm.active=true;mm.party_mode=true;mm.phase="party";mm.hybrid.player_id="me"
 mm.party={"code":"ABCD123456","leader":"me","members":[{"user":"me","name":"Leader","leader":true,"rating":0}],"playlist":"tactical_3v3"}
 mm.public_state={"members":{},"connected":0,"capacity":6};game.show_matchmaking();await settle()
 check(button(game,"Search")!=null and not button(game,"Search").disabled,"leader has one Search action")
 check(button(game,"Invite")!=null and button(game,"Join Party")!=null,"invite and join accessible in same lobby")
 check(game.screen.find_children("*","LineEdit",true,false).is_empty(),"server address and ports removed from main matchmaking UI")
 var options=game.screen.get_node("MatchmakingView").playlist_buttons
 check(options.size()==5,"five playlist cards")
 var original=options[0].get_instance_id();game.show_matchmaking();await settle()
 check(game.screen.get_node("MatchmakingView").playlist_buttons[0].get_instance_id()==original,"unchanged updates preserve keyboard/dropdown focus")
 mm.party.members.append({"user":"friend","name":"Friend","leader":false,"rating":0});game.show_matchmaking();await settle()
 options=game.screen.get_node("MatchmakingView").playlist_buttons
 check(options[0].disabled and not options[1].disabled,"party of two cannot select Duel but can select Doubles")
 mm.hybrid.player_id="friend";mm.party.leader="me";mm.phase="queue";game.show_matchmaking();await settle()
 check(button(game,"Cancel Search").disabled,"non-leader cannot cancel whole-party search")
 check(game.screen.get_node("MatchmakingView").playlist_buttons[0].disabled,"playlist locked while searching")
 mm.phase="party";game.show_matchmaking();await settle()
 check(button(game,"Search").disabled,"non-leader cannot search")
 mm.hybrid.player_id="me";mm.party.members.clear()
 for i in range(4):mm.party.members.append({"user":str(i),"name":"Player "+str(i),"leader":i==0,"rating":0})
 game.show_matchmaking();await settle();check(button(game,"Search").disabled,"oversize state disables Search locally too")
 mm.party.members=[{"user":"me","name":"Leader","leader":true,"rating":0}];game.show_matchmaking();await settle()
 button(game,"Join Party").pressed.emit();await settle()
 check(game.screen.find_children("*","LineEdit",true,false).size()==1,"Join opens simple invite-code dialog")
 for dialog in game.screen.find_children("*","ConfirmationDialog",true,false):dialog.queue_free()
 await settle()
 mm.phase="voting";mm.until=mm.clock()+25;mm.local_slot=2;mm.public_state={"capacity":6,"connected":6,"members":{},"votes":{},"vote_stage":"setup","mode":2,"map":0};game.show_matchmaking();await settle()
 check(game.screen.find_children("*","OptionButton",true,false).size()==2 and button(game,"Submit Vote")!=null,"map and game voting retained after search")
 for dimensions in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=dimensions;await settle()
  var scroll=game.screen.find_children("*","ScrollContainer",true,false)[0]
  check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"no horizontal scroll at %dx%d"%[dimensions.x,dimensions.y])
 mm.leave();game.queue_free();await settle()
 print("PARTY MENU: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
