class_name NestMatchmakingScreen
extends Node
const GOLD=Color("d9bd80")
const IVORY=Color("e6ede7")
const MUTED=Color("b3c2be")
const GREEN=Color("65e5a5")
const RED=Color("a52929")
var gamer_card: NestGamerCard
var gamer_card_key=""
var game
var mm: NestMatchmaking
var view_key=""
var master_label: Label
var detail: Label
var count_text: Label
var pulse: Label
var countdown: Label
var roster: HBoxContainer
var tally: Label
var ballot_status: Label
var playlist_input: OptionButton
var mode_input: OptionButton
var map_input: OptionButton
var life_input: OptionButton
var search_button: Button
var elapsed=0.0
var playlist_grid: GridContainer
var playlist_buttons: Array[Button]=[]
var content_layout: BoxContainer
var roster_key=""
var radar: NestSearchRadar
var atmosphere: NestLobbyAtmosphere
var stage_label: Label
static func show(owner) -> void:
 if owner.get_meta("rank_guide",false):NestRankGuide.show(owner);return
 var mm: NestMatchmaking=owner.matchmaking
 var key=str([mm.phase,mm.epoch,mm.public_state.get("vote_stage","setup"),mm.party.get("code",""),mm.party.get("members",[]),mm.playlist])
 var existing=owner.screen.get_node_or_null("MatchmakingView")
 if owner.current_screen=="matchmaking" and existing is NestMatchmakingScreen and existing.view_key==key:
  existing.refresh();return
 owner.current_screen="matchmaking";owner.context="menu";owner.clear_screen();owner.hud.visible=false
 owner.menu_camera.current=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 owner.shade(.78)
 var atmosphere=NestLobbyAtmosphere.new();atmosphere.name="LobbyAtmosphere";owner.screen.add_child(atmosphere);atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);atmosphere.set_enabled(owner.matchmaking.lobby_effects)
 var scene=NestMatchmakingScreen.new();scene.name="MatchmakingView";scene.game=owner;scene.mm=mm;scene.view_key=key;scene.atmosphere=atmosphere;owner.screen.add_child(scene)
 var margin=MarginContainer.new();owner.screen.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right"]:margin.add_theme_constant_override("margin_"+edge,32)
 for edge in ["top","bottom"]:margin.add_theme_constant_override("margin_"+edge,18)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
 var v=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.add_theme_constant_override("separation",10);scroll.add_child(v)
 v.add_child(owner.label("ANCIENT NEST  /  ONLINE MULTIPLAYER",12,GOLD))
 v.add_child(owner.title("MATCHMAKING",34))
 var tabs=HBoxContainer.new();v.add_child(tabs)
 var play=owner.button("Playlists",func():pass);play.disabled=true;tabs.add_child(play)
 var ranks=owner.button("Ranks & rating",func():owner.set_meta("rank_guide",true);owner.show_matchmaking());ranks.name="MatchmakingRanksTab";tabs.add_child(ranks)
 scene.master_label=owner.label("",14,MUTED);scene.master_label.name="MasterConnectionStatus";v.add_child(scene.master_label)
 scene.stage_label=scene.wrapped("CHOOSE YOUR PLAYLIST",12,GOLD);v.add_child(scene.stage_label)
 if mm.phase in ["idle","party","queue","error","connecting"]:
  var picker=scene.card(v,GOLD);picker.add_child(owner.label("CHOOSE YOUR PLAYLIST",13,GOLD))
  scene.playlist_grid=GridContainer.new();scene.playlist_grid.columns=5;scene.playlist_grid.add_theme_constant_override("h_separation",10);scene.playlist_grid.add_theme_constant_override("v_separation",10);picker.add_child(scene.playlist_grid)
  for i in range(5):
   var index=i
   var choice=owner.button(("✓  " if NestMatchmaking.PLAYLIST_IDS[i]==mm.playlist else "")+NestMatchmaking.PLAYLIST_NAMES[i],func():scene.choose_playlist(index))
   choice.mouse_entered.connect(func():scene.playlist_hover(choice,true));choice.mouse_exited.connect(func():scene.playlist_hover(choice,false))
   choice.name="PlaylistCard"+str(i+1);choice.custom_minimum_size=Vector2(0,74);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choice.add_theme_font_size_override("font_size",16)
   choice.tooltip_text="Your party can have up to %d players."%(i+1);scene.playlist_grid.add_child(choice);scene.playlist_buttons.append(choice)
   if NestMatchmaking.PLAYLIST_IDS[i]==mm.playlist:
    choice.add_theme_stylebox_override("normal",NestMenuSurface.surface(true,true));choice.add_theme_stylebox_override("disabled",NestMenuSurface.surface(true,true));choice.add_theme_color_override("font_disabled_color",Color("0b5036"));choice.add_theme_color_override("font_color",Color("0b5036"))
 scene.content_layout=BoxContainer.new();scene.content_layout.add_theme_constant_override("separation",18);v.add_child(scene.content_layout)
 var main_column=VBoxContainer.new();main_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scene.content_layout.add_child(main_column)
 scene.gamer_card=NestGamerCard.new();scene.gamer_card.username_pressed.connect(func():owner.accounts.show_service_card());main_column.add_child(scene.gamer_card)
 var status_card=scene.card(main_column,GOLD)
 scene.pulse=owner.label("",24,IVORY);status_card.add_child(scene.pulse)
 scene.radar=NestSearchRadar.new();scene.radar.mm=mm;scene.radar.custom_minimum_size=Vector2(220,96);scene.radar.mouse_filter=Control.MOUSE_FILTER_IGNORE;status_card.add_child(scene.radar)
 scene.detail=scene.wrapped("",14,MUTED);status_card.add_child(scene.detail)
 scene.count_text=owner.label("",16,GOLD);status_card.add_child(scene.count_text)
 scene.countdown=scene.wrapped("",14,GOLD);status_card.add_child(scene.countdown)
 if mm.phase in ["idle","party","queue","error","connecting"]:
  var setup=scene.card(main_column,GOLD);setup.add_child(owner.label("READY WHEN YOU ARE",13,GOLD))
  setup.add_child(scene.wrapped("Party limit: %d. Friends in your party play on the same team."%mm.team_size(),14,MUTED))
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);setup.add_child(row)
  scene.search_button=owner.button("Cancel Search" if mm.phase=="queue" else "Reconnect" if mm.phase in ["error","idle"] else "Search",scene.search_or_cancel);scene.search_button.custom_minimum_size=Vector2(190,48);scene.search_button.disabled=mm.phase=="connecting" or (mm.phase in ["party","queue"] and not mm.party_leader());row.add_child(scene.search_button)
  if mm.phase=="party":
   row.add_child(owner.button("Invite",scene.invite))
   row.add_child(owner.button("Join Party",scene.join_dialog))
   if mm.party.get("members",[]).size()>1:row.add_child(owner.button("Leave Party",func():mm.party_action("leave")))
  if not mm.party_leader():setup.add_child(scene.wrapped("Your party leader chooses the playlist and starts the search.",13,GOLD))
 scene.roster=HBoxContainer.new();scene.roster.add_theme_constant_override("separation",18);scene.roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scene.content_layout.add_child(scene.roster)
 if mm.phase=="voting":
  var vote_card=scene.card(v,GOLD);vote_card.add_child(owner.label("CAST YOUR VOTE",16,GOLD))
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",14);vote_card.add_child(row)
  var own: Dictionary=mm.public_state.get("votes",{}).get(mm.local_slot,{"mode":int(mm.public_state.get("mode",2)),"map":int(mm.public_state.get("map",0))})
  for kind in (["Life type"] if mm.public_state.get("vote_stage","setup")=="life" else ["Map","Game type"]):
   var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col);col.add_child(owner.label(kind.to_upper(),12,MUTED))
   var option=OptionButton.new();option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;option.custom_minimum_size.y=42;col.add_child(option)
   if kind=="Game type":
    scene.mode_input=option
    for i in range(NestMatchmaking.MODES.size()):
     if (mm.playlist=="duel_1v1") or (mm.playlist!="duel_1v1" and NestMatchmaking.MODES[i]!=1):option.add_item(NestMatchmaking.MODE_LABELS[i],NestMatchmaking.MODES[i])
    option.select(maxi(0,option.get_item_index(int(own.mode))))
   elif kind=="Life type":
    scene.life_input=option;option.add_item("Naki vs Naki",1);option.add_item("Annu vs Annu",2);option.select(1 if own.get("life",1)==2 else 0)
   else:
    scene.map_input=option
    for name in NestArena.MAP_NAMES:option.add_item(name)
    option.select(int(own.map))
  var submit=owner.button("Submit Vote",scene.submit_vote);submit.size_flags_vertical=Control.SIZE_SHRINK_END;row.add_child(submit)
  scene.ballot_status=scene.wrapped("",13,GREEN);vote_card.add_child(scene.ballot_status)
  scene.tally=scene.wrapped("",13,IVORY);vote_card.add_child(scene.tally)
  vote_card.add_child(scene.wrapped("Most votes wins. Ties are randomized only among the leading choices.\nMap and mode are counted separately, then life type is voted. Extraction skips life voting and uses Annu vs Naki.",12,MUTED))
 var footer=HBoxContainer.new();v.add_child(footer)
 footer.add_child(owner.button("Back",owner.leave_matchmaking))
 var motion=owner.button("Effects: ON" if mm.lobby_effects else "Effects: OFF",func():
  mm.lobby_effects=not mm.lobby_effects;scene.atmosphere.set_enabled(mm.lobby_effects)
  for button in footer.get_children():
   if button is Button and button.name=="MotionToggle":button.text="Effects: ON" if mm.lobby_effects else "Effects: OFF")
 motion.name="MotionToggle";footer.add_child(motion)
 scene.refresh()
func wrapped(text: String,size: int,color: Color) -> Label:
 var label=game.label(text,size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func card(parent: Node,color: Color) -> VBoxContainer:
 var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
 var style=NestMenuSurface.surface()
 style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=12;style.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",9);panel.add_child(column);return column
func playlist_hover(button: Button,hovered: bool) -> void:
 if hovered and button.disabled:return
 button.create_tween().tween_property(button,"modulate",Color(1.12,1.12,1.04) if hovered else Color.WHITE,.14 if mm.lobby_effects else 0.0)
func choose_playlist(index: int) -> void:
 if mm.phase!="party" or not mm.party_leader() or not mm.hybrid.master_connected() or mm.party.get("members",[]).size()>index+1:return
 mm.cancel_search_countdown();mm.party_action("playlist",{"playlist":NestMatchmaking.PLAYLIST_IDS[index]})
func refresh() -> void:
 if is_instance_valid(gamer_card):
  game.accounts.fetch_playlist_profile(mm.playlist)
  var profile: Dictionary=game.accounts.playlist_profiles.get(mm.playlist,{})
  var error=str(game.accounts.profile_errors.get(mm.playlist,""))
  var signature=str([mm.playlist,profile,error,game.accounts.linked(),game.accounts.state.get("username","")])
  if signature!=gamer_card_key:
   gamer_card_key=signature
   if not game.accounts.linked():gamer_card.show_unavailable()
   elif not error.is_empty():gamer_card.show_unavailable(error)
   elif profile.is_empty():gamer_card.show_unavailable("Loading verified playlist stats…")
   else:gamer_card.show_profile(profile,str(game.accounts.state.get("username","Player")),NestMatchmaking.PLAYLIST_NAMES[NestMatchmaking.PLAYLIST_IDS.find(mm.playlist)])
 detail.text=mm.status;detail.visible=not detail.text.is_empty()
 var titles={"idle":"Ready to play","party":"Your party","queue":"Searching for a match…","connecting":"Connecting…","probing":"Match found · choosing host","voting":"Match found · vote","loading":"Loading match","rejoining":"Rejoining match","migrating":"Restoring match","error":"Connection unavailable","playing":"Ready","results":"Match complete"}
 pulse.text=titles.get(mm.phase,"Connecting…")
 var next_roster_key=str([mm.phase,mm.party,mm.public_state.get("members",{}),mm.local_slot,mm.hybrid.player_id])
 if next_roster_key!=roster_key:
  roster_key=next_roster_key
  for child in roster.get_children():roster.remove_child(child);child.queue_free()
  if mm.phase in ["idle","party","queue","connecting","error"]:
   var column=card(roster,GOLD);column.add_child(game.label("YOUR PARTY  ·  %d / %d"%[mm.party.get("members",[]).size(),mm.team_size()],18,GOLD))
   for member in mm.party.get("members",[]):
    var name=str(member.name)+("  · LEADER" if member.get("leader",false) else "")+("  · YOU" if str(member.user)==mm.hybrid.player_id else "")
    if str(member.user).begins_with("account:"):
     var tag=game.button(name,func():game.accounts.show_service_card(str(member.user).trim_prefix("account:")));tag.tooltip_text="View overall service card";column.add_child(tag)
    else:column.add_child(wrapped(name,17,IVORY))
   if mm.party.is_empty():column.add_child(wrapped("Connecting your player…",14,MUTED))
   if is_instance_valid(search_button) and mm.phase=="party":search_button.disabled=not mm.party_leader() or mm.party.get("members",[]).size()>mm.team_size()
  else:
   var members: Dictionary=mm.public_state.get("members",{});var ids=members.keys();ids.sort()
   for team in range(2):
    var column=card(roster,GREEN if team==0 else RED);column.add_child(game.label(["TEAM A","TEAM B"][team],18,GREEN if team==0 else RED))
    for id in ids:
     if int(members[id].faction)==team:player_row(column,id,members[id])
 if is_instance_valid(tally):
  var ballots: Dictionary=mm.public_state.get("votes",{});var mode_counts={};var map_counts={}
  if mm.public_state.get("vote_stage","setup")=="life":
   var life_votes=ballots.values().map(func(b):return int(b.get("life",0)))
   tally.text="Naki vs Naki: %d    Annu vs Annu: %d"%[life_votes.count(1),life_votes.count(2)]
   ballot_status.text="Life ballot received" if ballots.has(mm.local_slot) else "Choose the life type for this match"
   return
  for ballot in ballots.values():
   mode_counts[ballot.mode]=mode_counts.get(ballot.mode,0)+1;map_counts[ballot.map]=map_counts.get(ballot.map,0)+1
  var text=""
  for i in range(NestMatchmaking.MODES.size()):text+=NestMatchmaking.MODE_LABELS[i]+": "+str(mode_counts.get(NestMatchmaking.MODES[i],0))+"    "
  tally.text=text
  for map_id in range(NestArena.MAP_NAMES.size()):tally.text+="\n%s: %d"%[NestArena.MAP_NAMES[map_id],map_counts.get(map_id,0)]
  var own: Dictionary=ballots.get(mm.local_slot,{})
  ballot_status.text="No vote submitted yet" if own.is_empty() else "VOTE RECEIVED  ·  %s  /  %s"%[NestMatchmaking.MODE_LABELS[NestMatchmaking.MODES.find(int(own.mode))],NestArena.MAP_NAMES[int(own.map)]]
func player_row(parent: Node,id,member: Dictionary) -> void:
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);row.custom_minimum_size.y=48;parent.add_child(row)
 var elo=int(member.get("rating",{}).get("human",0));var rank=NestPlaylistRanks.rank_for(elo)
 var icon=TextureRect.new();icon.texture=NestRankBadge.emblem_for(elo);icon.custom_minimum_size=Vector2(44,44);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
 var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col)
 var name=game.label(str(member.name)+("  · YOU" if int(id)==mm.local_slot else ""),16,GOLD if int(id)==mm.local_slot else IVORY);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name.tooltip_text=str(member.name);col.add_child(name)
 var target=str(member.get("account",""))
 if not target.is_empty():
  var open=Button.new();open.name="OpenServiceCard";open.text="◇ Service card";open.tooltip_text="View "+str(member.name)+"’s overall record";open.pressed.connect(func():game.accounts.show_service_card(target));col.add_child(open)
  name.mouse_filter=Control.MOUSE_FILTER_STOP;name.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:game.accounts.show_service_card(target))
 var status="BOT STAND-IN" if member.get("substitute",false) else "CONNECTED"
 col.add_child(wrapped("%s  ·  %s %s  ·  %d/21"%[status,rank.name,rank.roman,rank.number],12,MUTED))
func empty_row(parent: Node,text: String) -> void:
 var row=HBoxContainer.new();row.custom_minimum_size.y=48;row.add_theme_constant_override("separation",12);parent.add_child(row)
 var dot=game.label("◇",28,Color(.4,.45,.4));dot.custom_minimum_size.x=44;dot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;row.add_child(dot)
 row.add_child(wrapped(text,14,MUTED))
func _process(delta: float) -> void:
 elapsed+=delta
 if is_instance_valid(playlist_grid):
  playlist_grid.columns=5 if game.get_viewport().get_visible_rect().size.x>=1100 else 3 if game.get_viewport().get_visible_rect().size.x>=760 else 2
  for i in range(playlist_buttons.size()):playlist_buttons[i].disabled=mm.phase!="party" or not mm.party_leader() or not mm.hybrid.master_connected() or mm.party.get("members",[]).size()>i+1
 if is_instance_valid(content_layout):content_layout.vertical=game.get_viewport().get_visible_rect().size.x<900
 master_label.text=("●  CONNECTED  ·  MASTER SERVER" if mm.hybrid.master_connected() else "◌  CONNECTING TO MASTER SERVER" if mm.phase=="connecting" else "●  DISCONNECTED  ·  MASTER SERVER")
 master_label.add_theme_color_override("font_color",GREEN if mm.hybrid.master_connected() else GOLD if mm.phase=="connecting" else RED)
 if is_instance_valid(search_button) and mm.phase in ["party","queue"]:search_button.disabled=not mm.hybrid.master_connected() or not mm.party_leader() or mm.party.get("members",[]).size()>mm.team_size()
 pulse.modulate.a=1.0 if mm.phase=="party" or not mm.lobby_effects else .93+.07*sin(elapsed*3)
 count_text.text="%d / %d players found"%[int(mm.public_state.get("connected",0)),mm.capacity()] if mm.phase=="queue" else ""
 count_text.visible=not count_text.text.is_empty()
 if mm.phase=="voting":countdown.text="%ds to vote  ·  %d / %d votes"%[maxi(0,ceili(mm.until-mm.clock())),mm.public_state.get("votes",{}).size(),mm.capacity()]
 elif mm.phase in ["loading","rejoining"]:countdown.text="Waiting for every player · %d / %d ready"%[int(mm.public_state.get("loaded",0)),mm.capacity()]
 else:countdown.text=""
 if mm.phase=="queue":
  pulse.text="Searching"+".".repeat(int(elapsed*2.5)%4 if mm.lobby_effects else 3)
  var seconds=maxi(0,int(mm.clock()-mm.queue_started_at))
  countdown.text="%02d:%02d elapsed  ·  Your party stays on one team"%[seconds/60,seconds%60]
 stage_label.text={"party":"CHOOSE PLAYLIST  ›  SEARCH  ›  VOTE  ›  PLAY","queue":"SEARCHING FOR A COMPATIBLE MATCH","probing":"MATCH FOUND  ›  CHECKING PEER CONNECTIONS","voting":"MATCH FOUND  ›  CAST YOUR VOTE","loading":"JOINING HOST  ›  WAITING FOR ALL PLAYERS","error":"CONNECTION LOST  ›  RECONNECT TO CONTINUE"}.get(mm.phase,"CONNECTING TO MATCHMAKING")
 if mm.phase=="queue" and not mm.hybrid.master_connected():
  pulse.text="Connection interrupted";countdown.text="Waiting for the master connection. Reconnect if this persists."
 if is_instance_valid(radar):radar.enabled=mm.lobby_effects
 if mm.search_countdown_until>0:
  pulse.text="Search starts in %d"%maxi(1,ceili(mm.search_countdown_until-mm.clock()));countdown.text="Cancel anytime before searching begins."
 if is_instance_valid(search_button) and mm.phase=="party":search_button.text="Cancel Countdown" if mm.search_countdown_until>0 else "Search"
 countdown.visible=not countdown.text.is_empty()
func search_or_cancel() -> void:
 if mm.phase=="queue":mm.party_action("cancel")
 elif mm.phase=="party":
  if mm.search_countdown_until>0:mm.cancel_search_countdown()
  else:mm.begin_search_countdown()
 else:mm.open_party()
func invite() -> void:
 var code=str(mm.party.get("code",""))
 if code.is_empty():return
 DisplayServer.clipboard_set(code)
 var popup=AcceptDialog.new();popup.title="Invite friends";popup.dialog_text="Invite code: "+code+"\n\nCode copied. Send it to a friend. They can open Play → Join Party and paste it.\nParty limit for this playlist: %d."%mm.team_size();game.screen.add_child(popup);popup.confirmed.connect(popup.queue_free);popup.canceled.connect(popup.queue_free);popup.popup_centered(Vector2i(550,210))
func join_dialog() -> void:
 var popup=ConfirmationDialog.new();popup.title="Join Party";popup.ok_button_text="Join"
 var box=VBoxContainer.new();popup.add_child(box);box.add_child(wrapped("Paste your friend's invite code",16,IVORY))
 var entry=LineEdit.new();entry.placeholder_text="Invite code";entry.max_length=10;entry.custom_minimum_size=Vector2(330,44);box.add_child(entry)
 game.screen.add_child(popup)
 var submit=func():
  if entry.text.strip_edges().is_empty():return
  mm.party_action("join",{"code":entry.text.strip_edges()});popup.queue_free()
 popup.confirmed.connect(submit);entry.text_submitted.connect(func(_text):submit.call());popup.canceled.connect(popup.queue_free);popup.popup_centered(Vector2i(390,170));entry.grab_focus()
func submit_vote() -> void:
 if is_instance_valid(life_input):mm.vote(int(mm.public_state.get("mode",2)),int(mm.public_state.get("map",0)),life_input.get_selected_id())
 else:mm.vote(mode_input.get_selected_id(),map_input.selected)
