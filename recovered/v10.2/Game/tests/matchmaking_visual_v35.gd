extends SceneTree
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func settle():
 for i in range(8):await process_frame
func shot(name: String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v35/"+name+".png")
func run():
 Engine.max_fps=60
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
 var mm=game.matchmaking
 game.open_matchmaking();await settle()
 check(game.current_screen=="matchmaking","Native UI opens dedicated matchmaking page")
 check(not game.network_active,"Opening matchmaking never hosts an empty game")
 var address=game.screen.find_children("*","LineEdit",true,false)[0];address.text=""
 var find=game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Find Match")[0]
 find.pressed.emit();await settle()
 check(not game.network_active and mm.status.contains("Enter"),"Find Match button validates endpoint without accidental hosting")
 await shot("V35_Matchmaking_Server_Setup")
 mm.status="";mm.phase="queue";mm.public_state={"connected":4,"members":{}}
 for i in range(4):mm.public_state.members[i+100]={"name":"Player "+str(i+1),"faction":i%2,"peer":i+100}
 game.show_matchmaking();await settle();await shot("V35_Matchmaking_Searching")
 check(game.screen.find_children("*","ProgressBar",true,false)[0].value>0,"Connection progress bar animates")
 mm.phase="voting";mm.until=mm.clock()+25;mm.local_slot=100;mm.public_state.connected=6;mm.public_state.votes={100:{"mode":2,"map":0},101:{"mode":4,"map":1}}
 for i in range(6):mm.public_state.members[i+100]={"name":"Player "+str(i+1),"faction":i%2,"peer":i+100}
 game.show_matchmaking();await settle();await shot("V35_Matchmaking_Voting")
 check(game.screen.find_children("*","OptionButton",true,false).size()==2,"Independent map and game-type controls rendered")
 var choices=game.screen.find_children("*","OptionButton",true,false)
 choices[0].select(3);choices[1].select(1);choices[0].grab_focus()
 var before=choices[0].get_instance_id()
 choices[0].show_popup();await settle()
 game.matchmaking_ui_changed();await settle()
 choices=game.screen.find_children("*","OptionButton",true,false)
 check(choices[0].selected==3 and choices[1].selected==1,"Other players voting cannot overwrite an unsubmitted ballot")
 check(choices[0].get_instance_id()==before and choices[0].get_popup().visible,"Lobby updates preserve an open dropdown and its instance")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
 Input.parse_input_event(escape);await settle()
 check(mm.active and game.current_screen=="matchmaking" and not choices[0].get_popup().visible,"Escape closes a voting dropdown without leaving matchmaking")
 choices[0].get_popup().hide();choices[0].grab_focus()
 var pulse=game.screen.find_children("*","Label",true,false).filter(func(l):return l.text.contains("Match found"))[0]
 var alpha=pulse.modulate.a;await create_timer(.2).timeout
 check(not is_equal_approx(alpha,pulse.modulate.a),"Lobby heading has a lightweight pulse animation")
 for dimensions in [Vector2i(1920,810),Vector2i(1280,960),Vector2i(640,360)]:
  root.size=dimensions;await settle();await shot("V35_Matchmaking_%dx%d"%[dimensions.x,dimensions.y])
  var box=game.screen.find_children("*","ScrollContainer",true,false)[0]
  check(box.get_h_scroll_bar().max_value<=box.size.x+1,"Lobby fits horizontally at %dx%d"%[dimensions.x,dimensions.y])
 var scroll=game.screen.find_children("*","ScrollContainer",true,false)[0]
 var leave=game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Leave matchmaking")[0]
 check(leave.get_global_rect().end.y<=scroll.get_global_rect().end.y+1 or scroll.get_v_scroll_bar().max_value>scroll.size.y,"Small-screen controls remain reachable by layout or vertical scrolling")
 check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"Small-screen lobby has no horizontal clipping")
 mm.active=false;game.queue_free();await process_frame
 print("MATCHMAKING VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
