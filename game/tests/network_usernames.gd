extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String):marks[key]=true
var game
var gate
var role="host"
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS "+role+": "+message)
 else:failures+=1;push_error("FAIL "+role+": "+message)
func wait_for(test: Callable):
 var limit=Time.get_ticks_msec()+15000
 while not test.call() and Time.get_ticks_msec()<limit:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func run():
 role="client" if "client" in OS.get_cmdline_user_args() else "host"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false)
 gate=Gate.new();gate.name="UsernameGate";game.add_child(gate);await process_frame
 game.bot_fill=false;game.team_size=1;game.mode=2
 check(game.save_username("Raven")==OK,"Preferred username is saved before connecting")
 if role=="host":check(game.host_direct(17955,game.current_username(),0)==OK,"Host starts with the profile username")
 else:check(game.join_direct("127.0.0.1",17955,game.current_username(),1)==OK,"Client joins with the profile username")
 check(await wait_for(func():return game.lobby_members.size()==2),"Both peers receive the named lobby")
 if role=="host":
  var peer=game.lobby_members.keys().filter(func(id):return id!=1)[0]
  check(await phase("collision"),"Client sees its collision-resolved name")
  check(game.lobby_members[1].name=="Raven" and game.lobby_members[peer].name=="Raven_2","Joining with a duplicate name preserves the host and assigns a bounded suffix")
  check(await phase("renamed"),"Client rename was acknowledged")
  check(game.lobby_members[peer].name=="Pilot" and game.lobby_members[peer].ready and game.lobby_members[1].name=="Raven","Client rename changes only its own name and preserves ready state")
  check(await phase("invalid"),"Client submits an invalid name")
  await create_timer(.2).timeout
  check(game.lobby_members[peer].name=="Pilot","An empty sanitized name cannot erase the client's identity")
  gate.mark.rpc_id(peer,"invalid_checked")
  check(await phase("bounded"),"Host processes the bounded sanitized name")
  var client_name=String(game.lobby_members[peer].name)
  check(client_name.length()==20 and client_name.begins_with("Ace") and not client_name.contains("["),"Host strips controls/markup and bounds remote names")
  check(game.save_username(client_name)==OK,"Host can rename without disconnecting")
  var host_name=String(game.lobby_members[1].name)
  check(host_name!=client_name and host_name.length()<=20 and host_name.ends_with("_2"),"Host rename collisions use the same bounded unique-name rules")
  gate.mark.rpc_id(peer,"host_renamed")
  check(await phase("final_name"),"Client restores its preferred lobby name")
  game.start_game();game.create_hud()
  check(game.player.username==host_name and game.actor_by_id(peer).username=="Pilot","Authoritative actors inherit the final canonical lobby usernames")
  check(await phase("chat"),"Client sends named in-game chat")
  check(await wait_for(func():return game.messages.any(func(message):return message=="Pilot: hello")),"Server labels client chat with its authoritative username")
  game.now+=2;check(game.send_chat("host hello"),"Host can send named chat")
  gate.mark.rpc_id(peer,"host_chat")
  check(await phase("done"),"Client verifies shared names, scoreboard and chat")
  gate.mark.rpc_id(peer,"finish");await create_timer(.2).timeout
 else:
  var id=game.multiplayer.get_unique_id()
  check(await wait_for(func():return game.lobby_members[id].name=="Raven_2"),"Client receives the host's unique assigned name")
  check(game.current_username()=="Raven","Lobby suffix does not overwrite the locally preferred username")
  gate.mark.rpc_id(1,"collision")
  game.set_personal_lobby(-1,true);check(await wait_for(func():return game.lobby_ready),"Ready fixture is acknowledged")
  game.screen.find_child("EditUsername",true,false).pressed.emit();await process_frame
  var dialog=game.modal;dialog.find_child("UsernameInput",true,false).text="Pilot";dialog.confirmed.emit()
  check(await wait_for(func():return game.lobby_members[id].name=="Pilot"),"Client username editor updates its server-owned slot")
  check(game.current_username()=="Pilot" and game.lobby_members[1].name=="Raven","Profile saves locally while host identity remains intact")
  gate.mark.rpc_id(1,"renamed");game.request_username.rpc_id(1," \n[]");gate.mark.rpc_id(1,"invalid")
  check(await phase("invalid_checked"),"Server verifies rejection of the invalid rename")
  game.request_username.rpc_id(1,"[Ace]\n"+"X".repeat(40))
  check(await wait_for(func():return String(game.lobby_members[id].name).begins_with("Ace")),"Client sees the sanitized canonical remote name")
  gate.mark.rpc_id(1,"bounded");check(await phase("host_renamed"),"Host rename is broadcast to the client")
  var host_name=String(game.lobby_members[1].name)
  check(host_name!=String(game.lobby_members[id].name) and host_name.ends_with("_2"),"Both peers display the same host collision suffix")
  game.save_username("Pilot");check(await wait_for(func():return game.lobby_members[id].name=="Pilot"),"Client can restore its preferred name")
  game.show_username_dialog();var interrupted=game.modal;interrupted.find_child("UsernameInput",true,false).text="Unsubmitted"
  gate.mark.rpc_id(1,"final_name")
  check(await wait_for(func():return game.running and game.player!=null),"Named match starts")
  check(not is_instance_valid(interrupted) or not interrupted.visible,"Host starting a match closes the client username dialog")
  check(game.player.username=="Pilot" and game.actor_by_id(1).username==host_name,"Client actors mirror canonical usernames")
  game.scoreboard.refresh()
  check(game.scoreboard.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Pilot")),"Multiplayer scoreboard displays the client username")
  game.now+=2;check(game.send_chat("hello"),"Client can send chat under its username");gate.mark.rpc_id(1,"chat")
  check(await phase("host_chat"),"Host sends named chat")
  check(await wait_for(func():return game.messages.any(func(message):return message==host_name+": host hello")),"Client chat displays the authoritative renamed host")
  gate.mark.rpc_id(1,"done");check(await phase("finish"),"Host completes the session")
 game.stop_game();game.close_connection();game.lobby_network.shutting_down=true;game.queue_free();await create_timer(.2).timeout
 print("NETWORK USERNAMES "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
