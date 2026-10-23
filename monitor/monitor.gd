extends Control
const GOLD=Color("ccb480")
const GREEN=Color("87d69a")
const RED=Color("ef8b80")
const MODES={0:"Extraction",1:"Iso Deathmatch",2:"Team Deathmatch",3:"Capture the Flag",4:"Bomb Defusal"}
var connection_panel: VBoxContainer
var connection_toggle: Button
var metric_labels: Dictionary={}
var search: LineEdit
var tabs: TabContainer
var endpoint: LineEdit
var token: LineEdit
var connect_button: Button
var status: Label
var updated: Label
var totals: Label
var capabilities: Label
var playlist_text: RichTextLabel
var mode_text: RichTextLabel
var matches: Tree
var history: Tree
var detail: RichTextLabel
var phase_filter: OptionButton
var playlist_filter: OptionButton
var mode_filter: OptionButton
var request: HTTPRequest
var polling=false
var busy=false
var last_success=-1.0
var data: Dictionary={}
var selected_match=""
var metrics: Dictionary={}
func label(text: String,size: int=16,color: Color=Color("ebe7dc")) -> Label:
 var item=Label.new();item.text=text;item.add_theme_font_size_override("font_size",size);item.add_theme_color_override("font_color",color);return item
func button(text: String,action: Callable) -> Button:
 var item=Button.new();item.text=text;item.custom_minimum_size.y=38;item.pressed.connect(action);return item
func column(parent: Node) -> VBoxContainer:
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(box);return box
func rich(parent: Node,height: float) -> RichTextLabel:
 var item=RichTextLabel.new();item.custom_minimum_size.y=height;item.size_flags_vertical=Control.SIZE_EXPAND_FILL;item.scroll_active=true;parent.add_child(item);return item
func table(parent: Node,columns: Array) -> Tree:
 var tree=Tree.new();tree.columns=columns.size();tree.hide_root=true;tree.column_titles_visible=true;tree.size_flags_vertical=Control.SIZE_EXPAND_FILL;tree.custom_minimum_size.y=220
 for i in range(columns.size()):tree.set_column_title(i,columns[i])
 parent.add_child(tree);return tree
func _ready() -> void:
 DisplayServer.window_set_title("Ancient Nest 10.5-dev — Master Server Monitor")
 get_window().min_size=Vector2i(980,640)
 var theme_new=Theme.new();theme_new.default_font=load("res://assets/body.ttf");theme_new.default_font_size=16;theme=theme_new
 for kind in ["Button","LineEdit","OptionButton","Tree","TabContainer"]:
  for state in ["normal","panel","focus","hover","pressed"]:
   var style=StyleBoxFlat.new();style.bg_color=Color("17211f");style.border_color=GOLD;style.set_border_width_all(1);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8;theme_new.set_stylebox(state,kind,style)
 var bg=ColorRect.new();bg.color=Color("0b1110");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,22)
 var box=column(margin)
 box.add_child(label("ANCIENT NEST  /  MASTER MONITOR  /  10.5-dev",26,GOLD))
 box.add_child(label("Your matchmaking service at a glance · updates every 5 seconds",14))
 var controls=HBoxContainer.new();box.add_child(controls)
 connection_toggle=button("Connection settings",func():connection_panel.visible=not connection_panel.visible);controls.add_child(connection_toggle)
 controls.add_child(button("Setup guide",func():tabs.current_tab=3))
 connection_panel=column(box)
 connection_panel.add_child(label("1  Paste your matchmaking Worker URL     2  Paste your private monitor key     3  Connect",14,GOLD))
 var row=HBoxContainer.new();connection_panel.add_child(row)
 endpoint=LineEdit.new();endpoint.placeholder_text="Master URL: https://your-matchmaking-worker.workers.dev";endpoint.tooltip_text="Use the matchmaking Worker URL, not the main website. You can also paste the game WSS address.";endpoint.size_flags_horizontal=Control.SIZE_EXPAND_FILL;endpoint.custom_minimum_size.y=42;row.add_child(endpoint)
 var cfg=ConfigFile.new();cfg.load("user://monitor.cfg");endpoint.text=str(cfg.get_value("monitor","endpoint","https://ancient-nest-matchmaking.ancientnest-llc.workers.dev"))
 token=LineEdit.new();token.secret=true;token.placeholder_text="Private monitor key";token.tooltip_text="Created by Configure Monitor.cmd. Kept in memory only; never saved.";token.custom_minimum_size=Vector2(260,42);row.add_child(token)
 connect_button=button("Connect",toggle_connection);row.add_child(connect_button);row.add_child(button("Clear key",clear_key))
 status=label("NOT CONNECTED — open Connection settings to get started",18,GOLD);box.add_child(status)
 updated=label("No live data received. Zeros are not being presented as live counts.",13);box.add_child(updated)
 tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(tabs)
 var overview=column(tabs);overview.name="Overview"
 totals=label("Connect to see live activity.",18,GOLD);overview.add_child(totals)
 var cards=GridContainer.new();cards.columns=4;cards.add_theme_constant_override("h_separation",12);overview.add_child(cards)
 for item in [["online_players","Players online"],["queued_players","Searching"],["playing_matches","Matches playing"],["disconnected_slots","Reconnecting slots"]]:
  var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cards.add_child(panel)
  var style=StyleBoxFlat.new();style.bg_color=Color("172822");style.border_color=Color("49644c");style.set_border_width_all(1);style.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",style)
  var content=column(panel);var value=label("—",30,GREEN);content.add_child(value);content.add_child(label(item[1],14));metric_labels[item[0]]=value
 capabilities=label("",14);capabilities.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;overview.add_child(capabilities)
 var views=HBoxContainer.new();views.size_flags_vertical=Control.SIZE_EXPAND_FILL;overview.add_child(views)
 playlist_text=rich(column(views),240);mode_text=rich(column(views),240)
 overview.add_child(label("Offline practice/custom games are not tracked. Disconnected slots refer to active master-coordinated matches.",13))
 var matches_page=column(tabs);matches_page.name="Live Matches"
 matches_page.add_child(label("Select a match to see its players. Filters apply only to this view.",14))
 search=LineEdit.new();search.placeholder_text="Find a match, host or player…";search.custom_minimum_size.y=36;matches_page.add_child(search);search.text_changed.connect(func(_value):render_matches())
 var filters=HBoxContainer.new();matches_page.add_child(filters)
 phase_filter=OptionButton.new()
 for value in ["All states","Playing","Forming","Results","Disconnected slots","Complete","Failed"]:phase_filter.add_item(value)
 filters.add_child(phase_filter);phase_filter.item_selected.connect(func(_i):render_matches())
 playlist_filter=OptionButton.new();playlist_filter.add_item("All playlists");filters.add_child(playlist_filter);playlist_filter.item_selected.connect(func(_i):render_matches())
 mode_filter=OptionButton.new();mode_filter.add_item("All game types")
 for mode in MODES:mode_filter.add_item(MODES[mode],mode)
 filters.add_child(mode_filter);mode_filter.item_selected.connect(func(_i):render_matches())
 filters.add_child(button("Refresh",refresh))
 matches=table(matches_page,["Playlist","Game type","Map","State","Players","Host","Age","Score"]);matches.item_selected.connect(show_selected)
 detail=rich(matches_page,110);detail.text="Select a match above to view its roster and connection state."
 var recent=column(tabs);recent.name="Match History"
 recent.add_child(label("Last 100 terminal matches; cumulative counters persist. No historical player IPs or credentials are exposed.",13))
 history=table(recent,["Match","Playlist","Game type","Result","Players","Duration","Ended UTC"])
 var help=column(tabs);help.name="Setup & Help"
 var help_text=rich(help,300)
 help_text.text="FIRST TIME? Read PC_CODEX_HANDOFF.md in the repository.\n\nSETUP\n\n1. Deploy the 10.5-dev Cloudflare Matchmaking package.\n2. In that folder run Configure Monitor.cmd. It generates a private 64-character key locally, then installs it as MONITOR_TOKEN.\n3. Paste the Worker's HTTPS URL above (not the website URL), and paste that key.\n4. Click Connect. This app does not run game physics or keep matchmaking online; Cloudflare does.\n\nThe key is masked and never saved by this app. Close the app or use Clear key after use. The URL alone is saved.\n\nCONNECTED means a successful authenticated response was received recently. A failed request leaves the last snapshot visible with a STALE warning. A 401 means the key is wrong. A 503 means MONITOR_TOKEN is missing/too short.\n\nActivity is limited to this coordinator. Private offline practice and direct custom matches are not visible. This app is read-only: it cannot kick players, change rules or terminate matches.\n\nTURN/UDP supports difficult NAT networks but does not guarantee connectivity when all UDP is blocked. Results and scores reported by a player-host are not dedicated-server anti-cheat. See the repository setup guide for deployment instructions."
 request=HTTPRequest.new();request.timeout=10;request.max_redirects=0;request.body_size_limit=1048576;add_child(request);request.request_completed.connect(completed)
 var timer=Timer.new();timer.wait_time=5;timer.autostart=true;add_child(timer);timer.timeout.connect(refresh)
 endpoint.text_submitted.connect(func(_text):toggle_connection());token.text_submitted.connect(func(_text):toggle_connection())
func base_url() -> String:
 var value=endpoint.text.strip_edges().trim_suffix("/").replace("wss://","https://").replace("ws://","http://")
 for suffix in ["/v1/matchmaking","/api/monitor"]:value=value.trim_suffix(suffix)
 var regex=RegEx.new();regex.compile("^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$")
 var local=RegEx.new();local.compile("^http://(localhost|127\\.0\\.0\\.1)(:[0-9]{1,5})?$")
 return value if regex.search(value)!=null or local.search(value)!=null else ""
func clear_key() -> void:
 connection_panel.visible=true;polling=false;busy=false;request.cancel_request();token.clear();connect_button.text="Connect";status.text="DISCONNECTED — key cleared; last snapshot is not live";status.add_theme_color_override("font_color",GOLD)
func toggle_connection() -> void:
 if polling:
  polling=false;busy=false;request.cancel_request();connect_button.text="Connect";status.text="DISCONNECTED — last snapshot is not live";return
 if base_url().is_empty():connection_panel.visible=true;status.text="Enter an HTTPS master-server URL. Localhost HTTP is allowed for testing.";return
 if token.text.strip_edges().length()<32:connection_panel.visible=true;status.text="Enter the private monitor key (at least 32 characters).";return
 endpoint.text=base_url();var cfg=ConfigFile.new();cfg.set_value("monitor","endpoint",endpoint.text);cfg.save("user://monitor.cfg")
 polling=true;connect_button.text="Disconnect";refresh()
func refresh() -> void:
 if not polling or busy:return
 busy=true;status.text="CONNECTING — requesting authenticated activity…"
 var err=request.request(base_url()+"/api/monitor",PackedStringArray(["Authorization: Bearer "+token.text.strip_edges(),"Accept: application/json"]))
 if err!=OK:busy=false;unavailable("Unable to begin request")
func unavailable(reason: String) -> void:
 status.text="UNAVAILABLE / STALE — "+reason;status.add_theme_color_override("font_color",RED)
func completed(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
 busy=false
 if not polling:return
 if result!=HTTPRequest.RESULT_SUCCESS:unavailable("Network or TLS request failed. Check URL and Internet access.");return
 if code!=200:
  unavailable("HTTP %d. %s"%[code,"Wrong monitor key." if code==401 else "Configure MONITOR_TOKEN on the matchmaking Worker." if code==503 else "Check the deployed 10.5-dev coordinator URL."])
  if code in [401,503]:polling=false;connect_button.text="Connect"
  return
 var parsed=JSON.parse_string(body.get_string_from_utf8())
 if not parsed is Dictionary or str(parsed.get("release","")) not in ["10.5-dev","10.0","9.0","8.0","5.0"] or not parsed.get("summary") is Dictionary or not parsed.get("matches") is Array:unavailable("Unexpected API response; use the 10.5-dev coordinator.");return
 data=parsed;last_success=Time.get_ticks_msec()/1000.0;connection_panel.visible=false;render_data();status.text="CONNECTED — authenticated master-server activity";status.add_theme_color_override("font_color",GREEN)
func render_data() -> void:
 var s=data.summary
 totals.text="Live activity from your master server"
 for key in metric_labels:metric_labels[key].text=str(int(s.get(key,0)))
 var c=data.capabilities
 capabilities.text="Forming: %d   Results: %d   Parties: %d   Started: %d   Finished: %d   Failed: %d\nTURN: %s   Accounts + stats: %s   Guest mode: %s"%[s.forming_matches,s.results_matches,s.parties,s.started,s.finished,s.failed,"configured" if c.turn_configured else "not configured","configured" if c.accounts_configured else "not configured","ON (unranked)" if c.guest_mode else "OFF"]
 var review=data.get("ranking_review",{})
 if review.get("available",false):
  var count=0
  for item in review.get("reviews",[]):count+=int(item.get("total",0))
  capabilities.text+="\nRanking review flags: %d · Floor adjustment points logged: %d"%[count,int(review.get("floor_credit_total",0))]
 else:capabilities.text+="\nRanking review service: not connected / unavailable"
 playlist_text.text="PLAYLIST ACTIVITY\n\n";metrics.clear()
 var selected_id="" if playlist_filter.selected==0 else str(playlist_filter.get_item_metadata(playlist_filter.selected))
 playlist_filter.clear();playlist_filter.add_item("All playlists")
 for p in data.playlists:
  metrics[str(p.id)]=str(p.name);playlist_filter.add_item(str(p.name));playlist_filter.set_item_metadata(playlist_filter.item_count-1,p.id)
  if selected_id==str(p.id):playlist_filter.select(playlist_filter.item_count-1)
  playlist_text.text+="%s · %d players\n%d searching   %d playing   %d forming\n\n"%[p.name,p.max_players,p.searching,p.playing,p.forming]
 mode_text.text="LIVE GAME TYPES\n\n"
 for mode in data.game_types:mode_text.text+="%s: %d playing\n\n"%[mode.name,mode.playing]
 render_matches();history.clear();var root=history.create_item()
 for item in data.recent:
  var line=history.create_item(root);var values=[str(item.id).substr(0,8),metrics.get(str(item.playlist),item.playlist),MODES.get(int(item.mode),"Unknown"),item.result,str(item.players),"%dm %ds"%[int(item.duration_seconds)/60,int(item.duration_seconds)%60],Time.get_datetime_string_from_unix_time(int(item.ended_at)).replace("T"," ")]
  for i in range(values.size()):line.set_text(i,str(values[i]))
func render_matches() -> void:
 if not is_instance_valid(matches):return
 matches.clear();var root=matches.create_item()
 for item in data.get("matches",[]):
  var needle=search.text.strip_edges().to_lower() if search!=null else ""
  if not needle.is_empty():
   var words=str(item.id)+" "+str(item.host)+" "+str(item.playlist)
   for player in item.players:words+=" "+str(player.name)
   if not words.to_lower().contains(needle):continue
  var phase=str(item.phase);var filter=phase_filter.selected
  if filter==1 and phase!="running":continue
  if filter==2 and phase not in ["probing","voting","connecting","offered"]:continue
  if filter==3 and phase!="results":continue
  if filter==4 and (int(item.disconnected)==0 or phase in ["complete","failed"]):continue
  if filter==5 and phase!="complete":continue
  if filter==6 and phase!="failed":continue
  if playlist_filter.selected>0 and str(item.playlist)!=str(playlist_filter.get_item_metadata(playlist_filter.selected)):continue
  if mode_filter.selected>0 and int(item.mode)!=mode_filter.get_selected_id():continue
  var line=matches.create_item(root);line.set_metadata(0,item.id)
  var score="—"
  if item.live is Dictionary:score="%d : %d"%[item.live.scores[0],item.live.scores[1]]
  var values=[metrics.get(str(item.playlist),item.playlist),MODES.get(int(item.mode),"Unknown"),["Sanctuary","Crossroads","Savannah","Connectuct","Qaytal","Temple"][clampi(int(item.map),0,5)],{"running":"Playing","probing":"Checking connections","voting":"Voting","connecting":"Joining host","offered":"Preparing","results":"Results","complete":"Finished","failed":"Needs attention"}.get(phase,phase),"%d / %d"%[item.online,item.capacity],item.host,"%dm %ds"%[int(item.age_seconds)/60,int(item.age_seconds)%60],score]
  for i in range(values.size()):line.set_text(i,str(values[i]));line.set_tooltip_text(i,str(values[i]))
  if int(item.disconnected)>0:line.set_custom_color(4,RED)
  if str(item.id)==selected_match:line.select(0);show_detail(item)
func show_selected() -> void:
 var selected=matches.get_selected()
 if selected==null:return
 selected_match=str(selected.get_metadata(0))
 for item in data.get("matches",[]):
  if str(item.id)==selected_match:show_detail(item)
func show_detail(item: Dictionary) -> void:
 detail.text="MATCH "+str(item.id)+"  ·  epoch "+str(item.epoch)+"\n"
 for player in item.players:detail.text+="%s · Team %s · %s%s\n"%[player.name,"A" if int(player.team)==0 else "B","connected" if player.online else "disconnected / reserved slot"," · HOST" if player.host else ""]
func _process(_delta: float) -> void:
 if last_success>=0:
  var age=maxi(0,int(Time.get_ticks_msec()/1000.0-last_success))
  updated.text="Last successful snapshot: %ds ago · %s UTC · %s"%[age,Time.get_datetime_string_from_unix_time(int(data.get("generated_at",0))).replace("T"," "),"LIVE" if polling and age<15 else "STALE / NOT LIVE"]
