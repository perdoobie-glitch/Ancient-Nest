extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(label: String):marks[label]=true
var game
var gate
var role
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+role+": "+label)
 else:failures+=1;push_error("FAIL "+role+": "+label)
func wait_for(condition: Callable) -> bool:
 var until=Time.get_ticks_msec()+25000
 while not condition.call() and Time.get_ticks_msec()<until:await process_frame
 return condition.call()
func phase(label: String) -> bool:return await wait_for(func():return gate.marks.has(label))
func freeze():
 game.context="pause"
 for actor in game.actors:actor.set_physics_process(false);actor.set_process(false)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.map_selection=1 if role=="host" else 0;rules.mode=4;rules.bots_fill_empty_slots=false;rules.max_players_per_team=1;game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="MapGate";game.add_child(gate)
 check((game.host_direct(17952,"MapHost",0) if role=="host" else game.join_direct("127.0.0.1",17952,"MapClient",1))==OK,"Real ENet connection opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Two real peers join")
 if role=="host":
  check(await phase("crossroads_loaded"),"Client loads the host-selected tactical map")
  game.start_game();freeze();check(await phase("started"),"Client enters Crossroads match")
  check(game.mode==4 and game.arena.map_selection==1,"Host starts Bomb Defusal on Crossroads")
  var p=game.player;p.global_position=game.arena.sites[1]+Vector3(0,.08,2.5);game.cs_carrier=p.net_id
  await physics_frame;var choice=game.cs_interaction(p)
  check(not choice.is_empty() and game.complete_cs_interaction(p,choice),"Host plants on tactical site B")
  gate.mark.rpc("planted");check(await phase("plant_seen"),"Client receives authoritative planted bomb")
  var next=game.game_type.duplicate_settings();next.map_selection=0;game.apply_game_type_settings(next)
  check(game.arena.map_selection==1,"Queued map selection leaves active map unchanged")
  gate.mark.rpc("pending");check(await phase("pending_seen"),"Client receives pending map selection")
  var previous=game.match_session
  check(game.restart_round_in_match() and game.arena.map_selection==0,"Host round restart installs wider Sanctuary")
  freeze();check(game.match_session!=previous,"Map restart creates a fresh network session")
  gate.mark.rpc("restarted");check(await phase("restart_seen"),"Client loads new map and resets objectives")
  check(await phase("client_done"),"Client confirms host-only map controls")
  gate.mark.rpc("finish");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.game_type.map_selection==1 and game.arena.map_selection==1),"Lobby map selection builds matching Crossroads geometry")
  check(game.arena.sites[1].is_equal_approx(Vector3(25,0,-21)*Vector3(.85,.85,.85*1.35)),"Client bombsite coordinates match the host")
  gate.mark.rpc_id(1,"crossroads_loaded")
  check(await wait_for(func():return game.running and game.player!=null),"Client enters live tactical match");freeze()
  check(game.mode==4 and game.arena.pads.size()==8,"Client uses Bomb Defusal and tactical pickups")
  gate.mark.rpc_id(1,"started")
  check(await phase("planted") and await wait_for(func():return game.cs_planted()),"Planted bomb state reaches client")
  check(game.bomb_site==1 and float(game.site_states[1].bomb_at)>game.now,"Site B and active fuse agree")
  gate.mark.rpc_id(1,"plant_seen")
  check(await phase("pending") and await wait_for(func():return game.pending_game_type!=null),"Pending rules arrive reliably")
  check(game.pending_game_type.map_selection==0 and game.arena.map_selection==1,"Pending map does not replace client collision early")
  var previous=game.match_session;gate.mark.rpc_id(1,"pending_seen")
  check(await phase("restarted") and await wait_for(func():return game.match_session!=previous and game.arena.map_selection==0),"Reliable restart swaps client geometry and session")
  freeze();check(is_equal_approx(game.arena.scale.x,.85*1.35) and not game.cs_planted(),"Client has widened collision and cleared bomb objectives")
  check(game.pad_stock.size()==game.arena.pads.size(),"Snapshot pickup state matches the new map")
  gate.mark.rpc_id(1,"restart_seen")
  game.show_pause();game.open_game_type_settings();await process_frame
  check(game.game_type_editor.controls.map_selection.disabled and not game.apply_game_type_settings(GameTypeSettings.new()),"Client may view maps but cannot change authoritative rules")
  game.game_type_editor.close_editor();gate.mark.rpc_id(1,"client_done");check(await phase("finish"),"Both real peers finish test")
 game.stop_game();game.close_connection();game.queue_free()
 for i in range(8):await process_frame
 print("NETWORK MAPS "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
