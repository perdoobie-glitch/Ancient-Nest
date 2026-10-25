extends RefCounted
const GOLD=Color("d9bd80")
const MUTED=Color("b3c2be")
static func show(game) -> void:
 var mm=game.matchmaking
 # A directory reply can arrive after the user starts typing. Keep the draft
 # controls alive instead of rebuilding them and discarding entered values.
 if game.current_screen=="server_browser" and mm.phase=="party" and game.get_meta("server_create_form",false) and game.screen.find_child("ServerLobbyName",true,false)!=null:return
 game.current_screen="server_browser";game.context="menu";game.clear_screen();game.hud.visible=false;game.menu_camera.current=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.shade()
 var size=game.get_viewport().get_visible_rect().size
 var body=game.center_panel(minf(1100,size.x-32),minf(790,size.y-32));game.header(body,"ANCIENT NEST / CUSTOM MULTIPLAYER","SERVER BROWSER")
 var status=game.label(mm.status,14,MUTED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(status)
 var connected=mm.hybrid.master_connected()
 var supported=connected and mm.party.get("server_browser_supported",false)
 if connected and not supported:body.add_child(game.label("The master server needs the Server Browser update. Reconnect after deployment.",14,GOLD))
 var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);body.add_child(actions)
 var create=game.button("Create Lobby",func():game.set_meta("server_create_form",true);show(game));create.name="ServerBrowserCreate";create.disabled=not supported or mm.party.has("custom") or mm.phase!="party";actions.add_child(create)
 var refresh=game.button("Refresh",func():mm.refresh_browser());refresh.name="ServerBrowserRefresh";refresh.disabled=not supported;actions.add_child(refresh)
 if not connected:
  actions.add_child(game.button("Reconnect",func():mm.open_party();show(game)))
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 var contents=VBoxContainer.new();contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL;contents.add_theme_constant_override("separation",12);scroll.add_child(contents)
 if game.get_meta("server_create_form",false):
  create_form(game,contents);game.footer(body,false).add_child(game.button("Back to Browser",func():game.set_meta("server_create_form",false);show(game)));return
 if mm.party.has("custom"):
  var lobby=mm.party.custom
  contents.add_child(game.title(str(lobby.name),24))
  contents.add_child(game.label(summary(game,lobby)+" / UNRANKED",14,GOLD))
  var members=mm.party.get("members",[])
  for i in range(members.size()):
   var member=members[i]
   contents.add_child(game.label(str(member.name)+("  / LOBBY OWNER" if member.get("leader",false) else ""),16))
  contents.add_child(game.label("%d / %d players · Both teams play in this lobby."%[members.size(),int(lobby.capacity)],14,MUTED))
  var row=HBoxContainer.new();contents.add_child(row)
  var start=game.button("Start Game",func():mm.party_action("custom_start"));start.name="ServerBrowserStart";start.disabled=not supported or not mm.party_leader() or members.size()<2 or mm.party.get("searching",false);row.add_child(start)
  row.add_child(game.button("Leave Lobby",func():mm.party_action("leave");mm.browser_refresh_at=0))
  if not mm.party_leader():contents.add_child(game.label("The lobby owner starts the game when everyone is ready.",14,MUTED))
 contents.add_child(game.title("PUBLIC LOBBIES",20))
 if not mm.browser_loaded:
  contents.add_child(game.label("Loading lobbies…" if supported else "Connect to the master server to browse lobbies.",15,MUTED))
 elif mm.browser_lobbies.is_empty():
  contents.add_child(game.label("No public lobbies yet. Create one and invite other players to join here.",15,MUTED))
 for lobby in mm.browser_lobbies:
  var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",NestMenuSurface.surface(false,true));contents.add_child(panel)
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",14);panel.add_child(row)
  var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(details)
  var name=game.label(str(lobby.get("name","Custom Lobby")),19,GOLD);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(name)
  var description=game.label("Host: %s · %d / %d players\n%s"%[lobby.get("host","Player"),int(lobby.get("players",0)),int(lobby.get("capacity",2)),summary(game,lobby)],14,MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(description)
  var own=str(lobby.code)==str(mm.party.get("code",""))
  var full=int(lobby.players)>=int(lobby.capacity)
  var code=str(lobby.code)
  var join=game.button("Your Lobby" if own else "Full" if full else "Join Lobby",func():mm.party_action("join",{"code":code}));join.name="ServerBrowserJoin";join.disabled=not supported or own or full or mm.phase!="party";row.add_child(join)
 game.footer(body,false).add_child(game.button("Back to Main Menu",func():game.set_meta("server_create_form",false);game.leave_matchmaking()))
static func summary(game,lobby: Dictionary) -> String:
 return "%s · %s · %s"%[game.MODE_NAMES[clampi(int(lobby.get("mode",2)),0,4)],NestArena.MAP_NAMES[clampi(int(lobby.get("map",0)),0,NestArena.MAP_NAMES.size()-1)],["Naki vs Annu","Naki vs Naki","Annu vs Annu","Annu vs Naki"][clampi(int(lobby.get("matchup",0)),0,3)]]
static func picker(game,parent: VBoxContainer,title: String,options: Array,selected: int) -> OptionButton:
 parent.add_child(game.label(title,14,GOLD))
 var control=OptionButton.new();control.custom_minimum_size.y=42
 for option in options:control.add_item(str(option))
 control.select(selected);parent.add_child(control);return control
static func create_form(game,parent: VBoxContainer) -> void:
 parent.add_child(game.title("CREATE A PUBLIC LOBBY",22))
 parent.add_child(game.label("Lobby name",14,GOLD))
 var name=LineEdit.new();name.name="ServerLobbyName";name.text=game.current_username()+"'s Lobby";name.max_length=40;name.custom_minimum_size.y=42;parent.add_child(name)
 var mode=picker(game,parent,"Game mode",Array(game.MODE_NAMES),2)
 var map=picker(game,parent,"Map",Array(NestArena.MAP_NAMES),0)
 var matchup=picker(game,parent,"Teams",["Naki vs Annu","Naki vs Naki","Annu vs Annu","Annu vs Naki"],0)
 var capacity=picker(game,parent,"Player limit",["2 players","4 players","6 players","8 players","10 players"],4)
 var create=game.button("Create Lobby",func():
  game.set_meta("server_create_form",false)
  game.matchmaking.party_action("custom_create",{"name":name.text,"mode":mode.selected,"map":map.selected,"matchup":matchup.selected,"capacity":(capacity.selected+1)*2}))
 create.name="ServerBrowserConfirmCreate";parent.add_child(create)
 parent.add_child(game.label("Custom games are unranked. The lobby owner starts once at least two players join.",14,MUTED))
