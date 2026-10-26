extends SceneTree
class FakeHub extends NestHybridNetwork:
 var messages=[]
 func _ready():
  add_child(session);add_child(rtc);session.set_process(false);rtc.set_process(false);set_process(false)
 func master_connected() -> bool:return true
 func send(message: Dictionary):messages.append(message)
var game
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func frames():
 for i in range(4):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true;game.set_process(false)
 var old=game.matchmaking.hybrid;old.set_process(false);game.matchmaking.remove_child(old);old.queue_free()
 var hub=FakeHub.new();hub.enabled=true;hub.cloud=true;hub.player_id="me";hub.game=game;hub.mm=game.matchmaking;game.matchmaking.add_child(hub);game.matchmaking.hybrid=hub
 var mm=game.matchmaking;mm.active=true;mm.browser_mode=true;mm.phase="party";mm.party={"server_browser_supported":true,"code":"OWN","leader":"me","members":[{"name":"Me","user":"me","leader":true}]}
 game.show_main();await frames()
 check(game.screen.find_children("*","Button",true,false).any(func(button):return button.text=="Server Browser"),"Main menu offers Server Browser")
 var art=game.screen.get_node("SanctuaryMenuArtwork")
 check(art.offset_bottom==0 and art.stretch_mode==TextureRect.STRETCH_SCALE,"Complete uncropped main menu artwork fills the area behind navigation")
 mm.browser_loaded=true;mm.browser_lobbies=[{"code":"OTHER","name":"Public Duel","host":"Friend","players":1,"capacity":2,"mode":2,"map":0,"matchup":1}]
 for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(640,480)]:
  root.size=dimensions;root.content_scale_size=dimensions;game.show_server_browser();await frames()
  var join=game.screen.find_child("ServerBrowserJoin",true,false)
  check(join!=null and not join.disabled,"Join Lobby is available at "+str(dimensions))
  check(join.get_global_rect().end.x<=dimensions.x and join.get_global_rect().position.x>=0,"Browser fits viewport width at "+str(dimensions))
 game.screen.find_child("ServerBrowserJoin",true,false).pressed.emit()
 check(hub.messages.any(func(message):return message.type=="party_join" and message.code=="OTHER"),"Join routes selected lobby to authenticated master")
 game.screen.find_child("ServerBrowserCreate",true,false).pressed.emit();await frames()
 check(game.screen.find_child("ServerLobbyName",true,false)!=null,"Create Lobby opens configuration form")
 var entered_name=game.screen.find_child("ServerLobbyName",true,false);entered_name.text="Keep My Draft"
 game.show_server_browser();await frames()
 check(game.screen.find_child("ServerLobbyName",true,false)==entered_name and entered_name.text=="Keep My Draft","Background lobby updates preserve the creation draft")
 game.screen.find_child("ServerBrowserConfirmCreate",true,false).pressed.emit()
 check(hub.messages.any(func(message):return message.type=="party_custom_create" and message.capacity==10),"Create submits lobby configuration")
 mm.party.custom={"name":"Own Lobby","mode":2,"map":0,"matchup":1,"capacity":2};game.show_server_browser();await frames()
 check(game.screen.find_child("ServerBrowserStart",true,false).disabled,"One-player lobby cannot start")
 mm.party.members.append({"name":"Friend","user":"friend"});game.show_server_browser();await frames()
 check(not game.screen.find_child("ServerBrowserStart",true,false).disabled,"Owner can start with two players")
 mm.party.leader="friend";game.show_server_browser();await frames()
 check(game.screen.find_child("ServerBrowserStart",true,false).disabled,"Joining player cannot start owner's game")
 for mode in range(5):
  var rules=NestMatchPresets.create(mode);var copy=GameTypeSettings.new();copy.apply_network_dict(rules.to_network_dict())
  check(copy.movement_speed_percent==110 and copy.gravity_percent==145 and copy.jump_height_percent==125 and copy.air_control_percent==115,"Mode "+str(mode)+" transmits requested physics defaults")
 if "--qa-preview" in OS.get_cmdline_user_args():
  root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.title="Ancient Nest - Server Browser Preview (offline QA)"
  mm.party.erase("custom");mm.party.leader="me";game.show_main()
  var output=OS.get_environment("NEST_BROWSER_QA_OUTPUT")
  if not output.is_empty():
   DirAccess.make_dir_recursive_absolute(output)
   await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/main-menu.png")
   game.show_server_browser();await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/server-browser.png")
   game.set_meta("server_create_form",true);game.show_server_browser();await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/create-lobby.png")
   game.matchmaking.active=false;game.queue_free();await frames();quit(1 if failures else 0)
  return
 game.matchmaking.active=false;game.queue_free();await frames();quit(1 if failures else 0)
