extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String,data: Dictionary={}):marks[key]=data
var game
var gate
var role
var checks=0
var failures=0
const TRIGGER="/workspace/work/v26/late_join_trigger"
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+role+": "+label)
 else:failures+=1;push_error("FAIL "+role+": "+label)
func wait_for(test: Callable):
 var until=Time.get_ticks_msec()+30000
 while not test.call() and Time.get_ticks_msec()<until:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func freeze():
 game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
func run():
 var args=OS.get_cmdline_user_args();role=args[0] if args.size()>0 else "host"
 if role=="late":await wait_for(func():return FileAccess.file_exists(TRIGGER))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.lobby_network.set_process(false);game.lobby_network=null
 var rules=GameTypeSettings.new();rules.mode=3;rules.max_players=6;rules.max_players_per_team=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.lobby_kind="forge"
 game.ranked.profile.data.human.elo=1200 if role=="host" else 1600 if role=="client" else 2250
 gate=Gate.new();gate.name="ForgeGate";game.add_child(gate)
 check((game.host_direct(17936,"ForgeHost",0) if role=="host" else game.join_direct("127.0.0.1",17936,"ForgeClient" if role=="client" else "LateBuilder",1))==OK,"Real ENet peer opens")
 if role=="host":
  check(await wait_for(func():return game.lobby_members.size()==2),"Separate client joins Nest Forge lobby")
  var peer=game.lobby_members.keys().filter(func(id):return id>1)[0]
  game.forge_session.start();check(await phase("client_ready"),"Client enters editor through authoritative Nest Forge state")
  var s=game.forge_session;s.submit("spawn",{"spec":{"type":"structure","kind":"wall"},"position":[100,30,100]});var key=game.forge_editor.selected_key
  gate.mark.rpc_id(peer,"wall",{"key":key});check(await phase("client_moved"),"Client submits object transform")
  check(await wait_for(func():return s.model.records[key].node.global_position.is_equal_approx(Vector3(101,31,100))),"Client move is applied on authoritative host")
  check(s.model.records[key].node.global_basis.get_scale().is_equal_approx(Vector3(1.4,1.2,1)),"Client dimensions reach host")
  gate.mark.rpc_id(peer,"move_accepted");check(await phase("light_ready"),"Client spawns and edits light")
  var light_key=gate.marks.light_ready.key
  check(s.model.records.has(light_key) and is_equal_approx(s.model.records[light_key].node.light_energy,2.5),"Real light properties agree on host")
  var rev=s.revision;gate.mark.rpc_id(peer,"check_rejections")
  check(await phase("rejections_sent"),"Client sends duplicate/stale/host-only edit cases")
  check(s.revision==rev and s.model.records.has(key),"Duplicate and stale requests do not delete object or advance revision")
  gate.mark.rpc_id(peer,"rejections_ok")
  var file=FileAccess.open(TRIGGER,FileAccess.WRITE);file.store_string("join");file.close()
  check(await wait_for(func():return game.lobby_members.size()==3),"Late direct-IP guest can join while Nest Forge is editing")
  check(await phase("late_ready"),"Late guest receives current layout and revision")
  var late=gate.marks.late_ready.peer
  check(game.lobby_members[late].rating.human==2250,"Late guest rank metadata received")
  s.submit("transform",{"key":"point:3:flag:1:1","position":[24,12,6]})
  game.forge_session.start_test();freeze()
  gate.mark.rpc_id(peer,"playtest");gate.mark.rpc_id(late,"playtest")
  check(await phase("client_playtest") and await phase("late_playtest"),"Both separate clients enter shared playtest")
  check(game.actors.size()==3 and game.flag_bases[1].is_equal_approx(Vector3(24,12,6)),"Host playtest uses three real participants and edited flag site")
  check(not game.ranked.eligible,"Shared Nest Forge playtest remains unrated")
  s.return_to_editing();gate.mark.rpc_id(peer,"back");gate.mark.rpc_id(late,"back")
  check(await phase("client_back") and await phase("late_back"),"Both clients return from playtest to editor")
  s.stop_editing();gate.mark.rpc_id(peer,"lobby");gate.mark.rpc_id(late,"lobby")
  check(await phase("client_lobby") and await phase("late_lobby"),"Both clients return to ranked Nest Forge lobby")
  gate.mark.rpc_id(late,"done");check(await wait_for(func():return game.lobby_members.size()==2),"Late guest disconnect updates roster without ending Nest Forge")
  gate.mark.rpc_id(peer,"done");check(await wait_for(func():return game.lobby_members.size()==1),"Last guest disconnect leaves host lobby usable")
 elif role=="client":
  check(await wait_for(func():return game.forge_session.active and game.forge_editor!=null),"Joined client receives editable shared Nest Forge session")
  var s=game.forge_session
  check(s.model.records.size()>300 and game.lobby_kind=="forge","Client receives base registry and correct lobby kind")
  check(game.lobby_members[1].rating.human==1200,"Client receives host's rank metadata")
  gate.mark.rpc_id(1,"client_ready")
  check(await phase("wall"),"Host publishes new structure")
  var key=String(gate.marks.wall.key)
  check(await wait_for(func():return s.model.records.has(key)),"Host structure appears on client")
  var t=s.model.pose(s.model.records[key].node);var old=t.duplicate(true);t.p=[101,31,100];t.s=[1.4,1.2,1]
  check(s.submit("transform",{"key":key,"transform":t}),"Client can request object edit")
  check(s.model.pose(s.model.records[key].node)==old,"Client cannot mutate authoritative layout before confirmation")
  gate.mark.rpc_id(1,"client_moved");check(await phase("move_accepted") and await wait_for(func():return s.model.records[key].node.global_position.is_equal_approx(Vector3(101,31,100))),"Confirmed move is reconciled on client")
  s.submit("spawn",{"spec":{"type":"light","kind":"point"},"position":[100,34,100]})
  check(await wait_for(func():return s.model.added_order.size()==2),"Client-created light appears after host validation")
  var light_key=String(s.model.added_order.back());s.submit("light",{"key":light_key,"light":{"color":[.3,.5,1.0],"energy":2.5,"range":12,"angle":45,"shadows":false}})
  check(await wait_for(func():return is_equal_approx(s.model.records[light_key].node.light_energy,2.5)),"Client sees confirmed light properties")
  gate.mark.rpc_id(1,"light_ready",{"key":light_key});check(await phase("check_rejections"),"Host ready for request validation cases")
  game.request_forge_edit.rpc_id(1,s.epoch,s.revision,1,"delete",{"key":key})
  s.request_sequence+=1;game.request_forge_edit.rpc_id(1,s.epoch,s.revision-1,s.request_sequence,"delete",{"key":key})
  s.request_sequence+=1;game.request_forge_edit.rpc_id(1,s.epoch-1,s.revision,s.request_sequence,"delete",{"key":key})
  s.request_sequence+=1;game.request_forge_edit.rpc_id(1,s.epoch,s.revision,s.request_sequence,"undo",{})
  gate.mark.rpc_id(1,"rejections_sent");check(await phase("rejections_ok"),"Rejected edits leave same shared object")
  check(s.model.records.has(key),"Client retains object after stale/duplicate edit rejection")
  check(await phase("playtest") and await wait_for(func():return game.running),"Client enters host-started playtest")
  freeze();check(game.actors.size()==3 and game.flag_bases[1].is_equal_approx(Vector3(24,12,6)),"Client playtest has all real peers and edited objective")
  check(game.forge_session.testing and not game.ranked.eligible,"Client Nest Forge playtest is sandbox and unrated")
  gate.mark.rpc_id(1,"client_playtest");check(await phase("back") and await wait_for(func():return not game.running and s.active and game.forge_editor.editing),"Client returns to editor after host ends playtest")
  check(s.model.records.has(key) and s.model.added_order.size()==2,"Round trip preserves collaborative structures and light")
  gate.mark.rpc_id(1,"client_back");check(await phase("lobby") and await wait_for(func():return game.current_screen=="lobby"),"Client returns to Nest Forge lobby")
  check(game.screen.find_children("LobbyRankBadge","HBoxContainer",true,false).size()==3,"Returned lobby lists all three players with current rank medals")
  gate.mark.rpc_id(1,"client_lobby");check(await phase("done"),"Host acknowledges completed checks")
 else:
  check(await wait_for(func():return game.forge_session.active and game.forge_editor!=null),"Late guest joins an already active editor")
  var s=game.forge_session
  check(s.model.added_order.size()==2 and s.revision>=4,"Late guest receives existing added objects and latest revision")
  var wall=s.model.added_order.filter(func(k):return s.model.records[k].spec.type=="structure")[0]
  check(s.model.records[wall].node.global_position.is_equal_approx(Vector3(101,31,100)),"Late guest receives the edited transform, not original wall position")
  check(game.lobby_members.size()==3 and game.lobby_members[1].rating.human==1200,"Late guest receives complete roster and ranks")
  gate.mark.rpc_id(1,"late_ready",{"peer":game.multiplayer.get_unique_id()})
  check(await phase("playtest") and await wait_for(func():return game.running),"Late guest enters shared playtest")
  freeze();check(game.actors.size()==3 and game.flag_bases[1].is_equal_approx(Vector3(24,12,6)),"Late guest playtest receives edited objective")
  gate.mark.rpc_id(1,"late_playtest");check(await phase("back") and await wait_for(func():return not game.running and s.active and game.forge_editor.editing),"Late guest returns to editing")
  gate.mark.rpc_id(1,"late_back");check(await phase("lobby") and await wait_for(func():return game.current_screen=="lobby"),"Late guest returns to lobby")
  gate.mark.rpc_id(1,"late_lobby");check(await phase("done"),"Host completes late-join checks")
 if role!="host":await create_timer(.3).timeout
 game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("NEST FORGE V26 NETWORK ",role,": ",checks," checks, ",failures," failures");quit(1 if failures else 0)
