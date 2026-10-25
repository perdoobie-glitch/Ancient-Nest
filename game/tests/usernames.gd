extends SceneTree
class FakeSession extends Node:
 var network_active=false
 var selected_faction=0
 var network_status=""
 var received_names=[]
 func current_username() -> String:return "Route Pilot"
 func host_direct(_port,_name,_faction) -> Error:received_names.append(_name);return OK
 func join_direct(_address,_port,_name,_faction) -> Error:received_names.append(_name);return OK
class SafeLobby extends NestLobbyNetwork:
 func _ready():set_process(false)
 func _start_upnp(_port):pass
 func _stop_upnp_mapping():pass
var checks=0
var failures=0
var game
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func screenshot(name):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/usernames/"+name+".png")
func run():
 if "readback" in OS.get_cmdline_user_args():
  var preferences=NestPreferences.new();preferences.load_saved()
  check(preferences.values.username=="Pilot Nova","Saved username survives a full process restart")
  print("USERNAMES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0);return
 check(NestPreferences.normalize_username("  [Pilot]\n\tNova  ")=="PilotNova","Username normalization strips markup/control characters and outer whitespace")
 check(NestPreferences.normalize_username("X".repeat(100)).length()==24,"Usernames stay within the 24-character limit")
 check(NestPreferences.normalize_username("\u200b\u202e\n[]").is_empty(),"Invisible/control-only usernames are rejected")
 check(NestPreferences.normalize_username("Kira 猫-7")=="Kira 猫-7","Visible Unicode, spaces and punctuation are retained")
 var fake=FakeSession.new();root.add_child(fake);var service=SafeLobby.new();service.game=fake;fake.add_child(service)
 check(service.start_auto_host()==OK and fake.received_names[-1]=="Route Pilot","Auto-host passes the saved username to the session")
 await service.quick_join({"name":"Local fixture","ip":"127.0.0.1","port":17955})
 check(fake.received_names[-1]=="Route Pilot","Quick join passes the saved username instead of You")
 fake.queue_free()
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var main_button=game.screen.find_child("EditUsername",true,false)
 check(main_button!=null and main_button.text.contains("Player"),"Main menu shows a working username control for older preferences")
 main_button.pressed.emit();await frames();var dialog=game.modal;var entry=dialog.find_child("UsernameInput",true,false)
 check(dialog.visible and entry.has_focus() and root.gui_embed_subwindows and dialog.size.y<=360,"Username editor opens embedded with typing focus")
 entry.text="   ";dialog.confirmed.emit()
 check(dialog.visible and not dialog.find_child("UsernameError",true,false).text.is_empty() and game.current_username()=="Player","Blank username stays in the editor with an error")
 entry.text="[Raven]";dialog.confirmed.emit();await frames()
 check(game.current_username()=="Raven" and game.screen.find_child("EditUsername",true,false).text.contains("Raven"),"Saving updates the profile and main menu name")
 await screenshot("main-username")
 game.show_username_dialog();await frames();dialog=game.modal;dialog.find_child("UsernameInput",true,false).text="Cancelled Name";dialog.canceled.emit();await frames()
 check(game.current_username()=="Raven","Cancel leaves the saved username unchanged")
 game.show_lobby();await frames();game.screen.find_child("EditUsername",true,false).pressed.emit();await frames();dialog=game.modal;entry=dialog.find_child("UsernameInput",true,false)
 check(dialog.visible and entry.text=="Raven" and not game.lobby_preview.can_rotate(),"Lobby username editor prefills the profile and blocks model rotation while typing")
 await screenshot("username-editor")
 entry.text="Pilot Nova";entry.text_submitted.emit(entry.text);dialog.confirmed.emit();await frames()
 check(game.current_username()=="Pilot Nova" and not is_instance_valid(dialog),"Enter saves once even if confirmation also fires")
 var preferences=NestPreferences.new();preferences.load_saved();check(preferences.values.username=="Pilot Nova","Username is stored with personal preferences")
 check(game.save_username(" \n[]")==ERR_INVALID_PARAMETER and game.current_username()=="Pilot Nova","Core save validation rejects empty names without overwriting the profile")
 game.show_connection(false);await frames();dialog=game.modal
 check(dialog.find_child("ConnectionUsername",true,false).text=="Pilot Nova","Direct Join starts with the saved username")
 dialog.find_child("ConnectionUsername",true,false).text=" ";dialog.confirmed.emit();check(dialog.visible and not game.network_active,"Invalid direct-join username cannot start a connection")
 dialog.canceled.emit();await frames()
 game.lobby_members={1:{"name":"Raven","faction":0},2:{"name":"Raven_2","faction":1}}
 check(game.unique_alias("raven")=="raven_3" and game.unique_alias("Raven",1)=="Raven","Collision resolution is case-insensitive and ignores the player's own slot")
 game.lobby_members={1:{"name":"A".repeat(20),"faction":0},2:{"name":"A".repeat(18)+"_2","faction":1}}
 check(game.unique_alias("A".repeat(20))=="A".repeat(18)+"_3","Duplicate suffixes remain within the username limit")
 game.lobby_members.clear();game.bot_fill=false;game.team_size=1
 game.show_username_dialog();var interrupted=game.modal;interrupted.find_child("UsernameInput",true,false).text="Unsubmitted"
 game.begin_match();await frames(8);game.set_physics_process(false)
 check(not is_instance_valid(interrupted) and game.current_username()=="Pilot Nova","Starting a match closes unsaved username input so controls cannot remain trapped")
 check(game.player.username=="Pilot Nova","Offline match uses the saved username instead of You")
 check(game.save_username("Midmatch Rename")==ERR_BUSY and game.player.username=="Pilot Nova","Names stay stable for the duration of a running match")
 game.now=5;check(game.send_chat("hello") and game.messages[-1]=="Pilot Nova (local): hello","Offline chat uses the chosen username")
 game.create_hud();game.scoreboard.refresh()
 check(game.scoreboard.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Pilot Nova")),"Scoreboard displays the player's username")
 game.clear_screen();game.current_screen="playing";game.hud.visible=true;Input.action_press("scoreboard")
 game.player.username="W".repeat(20);game.scoreboard.refresh(true);await frames()
 var names=game.scoreboard.find_children("*","Label",true,false).filter(func(label):return label.text=="W".repeat(20))
 check(names.size()==1 and names[0].clip_text and names[0].size.x>=249 and names[0].size.x<=251,"Long usernames stay inside the scoreboard name column")
 Input.action_release("scoreboard");game.stop_game();game.queue_free();await frames(5)
 print("USERNAMES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
