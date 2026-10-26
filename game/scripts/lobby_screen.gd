class_name NestLobbyScreen
extends RefCounted
static func show(game) -> void:
 game.current_screen="lobby";game.context="menu";game.restore_focus="Nest Forge" if game.lobby_kind=="forge" else "Custom Lobby";game.clear_screen();game.shade();game.hud.visible=false;game.menu_camera.current=true;game.lobby_preview=null
 if not game.network_active and game.lobby_network!=null:game.lobby_network.start_auto_host()
 var size=game.get_viewport().get_visible_rect().size;var body=game.center_panel(minf(1200,size.x-40),minf(760,size.y-40));body.get_parent().name="ForgeLobby" if game.lobby_kind=="forge" else "CustomLobby"
 var top=HBoxContainer.new();body.add_child(top);var title=game.title("NEST FORGE LOBBY" if game.lobby_kind=="forge" else "CUSTOM GAMES",30);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
 game.lobby_host_badge=game.label("",12,game.GOLD);game.lobby_host_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;top.add_child(game.lobby_host_badge);body.add_child(HSeparator.new())
 var columns=HBoxContainer.new();columns.add_theme_constant_override("separation",20);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(columns)
 var left_panel=PanelContainer.new();left_panel.name="LobbySettingsPanel";left_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(left_panel)
 var left_scroll=ScrollContainer.new();left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left_panel.add_child(left_scroll)
 var left=VBoxContainer.new();left.name="LobbySettingsList";left.add_theme_constant_override("separation",10);left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left_scroll.add_child(left)
 left.add_child(game.label("SETTINGS & CUSTOMIZATION",15,game.GOLD))
 var search=LineEdit.new();search.name="LobbySettingsSearch";search.placeholder_text="Search lobby · mode, map, voting, player, connection…";search.clear_button_enabled=true;left.add_child(search)
 var results=game.label("",12,game.MUTED);results.visible=false;left.add_child(results)
 var category=OptionButton.new();category.name="LobbyCategory";category.fit_to_longest_item=false
 for category_title in ["GAME SETUP","MAP & OBJECTIVES","YOUR PLAYER","DIRECT CONNECTION"]:category.add_item(category_title)
 left.add_child(category)
 var sections={};var headings={}
 var setup=section(game,left,"GAME SETUP",sections,headings)
 setup.add_child(game.label("Official presets · Vote for map, game type and life type.",12,game.MUTED))
 var preset=game.label(game.game_type.game_type_name,22);preset.name="ActiveGameType";setup.add_child(preset)
 var summary=game.label(game.lobby_rules_summary(),13);summary.name="MatchSummary";summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;setup.add_child(summary)
 var settings=game.button("Match Settings · Game Types / Traits / Weapons",game.open_game_type_settings);settings.name="EditGameTypeSettings";settings.set_meta("search_terms","rules gravity health armor shields movement bots difficulty damage resistance presets save game type")
 if game.can_edit_match_traits():setup.add_child(settings)
 else:settings.free()
 var mode_row=HBoxContainer.new();setup.add_child(mode_row);mode_row.add_child(game.label("Play mode",13));var mode=OptionButton.new();mode.name="LobbyMode";mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode.fit_to_longest_item=false
 for name in game.MODE_NAMES:mode.add_item(name)
 mode.select(game.mode);mode.disabled=game.is_client() or game.lobby_vote.active();mode_row.add_child(mode);mode.item_selected.connect(func(i):game.select_normal_preset(i,game.game_type.map_selection,game.matchup);game.show_lobby())
 var life=OptionButton.new();life.name="LobbyLifeType";life.add_item("Naki vs Naki",1);life.add_item("Annu vs Annu",2)
 if game.mode==0:life.clear();life.add_item("Annu vs Naki · Extraction",3)
 else:life.select(1 if game.matchup==2 else 0)
 life.disabled=game.is_client() or game.mode==0 or game.lobby_vote.active();game.row(setup,"Life type",life)
 life.item_selected.connect(func(_index):game.select_normal_preset(game.mode,game.game_type.map_selection,life.get_selected_id());game.show_lobby())
 if game.lobby_kind=="custom":
  NestLobbyVote.show(game,setup)
  if game.lobby_vote.active():
   for child in setup.get_children():child.visible=child.name=="LobbyVotePanel"
 var map_section=section(game,left,"MAP & OBJECTIVES",sections,headings)
 var map_choice=OptionButton.new();map_choice.name="LobbyMap";map_choice.fit_to_longest_item=false
 for map_name in NestArena.MAP_NAMES:map_choice.add_item(map_name)
 map_choice.select(game.game_type.map_selection);map_choice.disabled=game.is_client() or game.lobby_vote.active();game.row(setup,"Map",map_choice)
 map_choice.item_selected.connect(func(index):game.select_normal_preset(game.mode,index,game.matchup);game.show_lobby())
 map_section.add_child(game.label(game.arena.map_title()+" · "+("Edited Nest Forge layout" if game.forge_session.model!=null else "Default layout"),14))
 var forge=game.button("Open Nest Forge · Edit Map & Sites",func():game.open_forge());forge.name="LobbyOpenForge";forge.disabled=game.is_client();map_section.add_child(forge)
 var load=game.button("Load Saved Nest Forge Layout",game.load_forge_layout_from_lobby);load.name="LobbyLoadLayout";load.disabled=game.is_client();map_section.add_child(load)
 var reset=game.button("Use Default "+game.arena.map_title()+" Layout",game.reset_forge_layout);reset.name="LobbyDefaultLayout";reset.disabled=game.is_client();map_section.add_child(reset)
 if game.lobby_kind=="forge":
  var use=game.button("Use This Layout in Custom Games",func():game.lobby_kind="custom";game.broadcast_lobby();game.show_lobby());use.disabled=game.is_client();map_section.add_child(use)
 var note=game.label("Nest Forge lets direct-IP guests join and edit. The host loads layouts, undoes shared edits and starts playtests. Each mode has separate spawn/bomb/flag locations.",12,game.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;map_section.add_child(note)
 var player_section=section(game,left,"YOUR PLAYER",sections,headings);player_section.add_child(game.button("Change Username",game.show_username_dialog));player_section.add_child(game.button("Personal Settings · Controls / Video / Audio / HUD",func():game.open_settings("lobby")))
 game.lobby_faction=OptionButton.new();game.lobby_faction.name="YourTeam";game.lobby_faction.fit_to_longest_item=false
 for team in [0,1]:game.lobby_faction.add_item(("Team A · " if team==0 else "Team B · ")+("Naki" if game.MATCHUPS[game.matchup][team]==0 else "Annu"))
 game.lobby_faction.select(game.selected_faction);game.row(player_section,"Your team",game.lobby_faction);game.lobby_faction.item_selected.connect(func(i):game.set_personal_team(i))
 game.lobby_character=OptionButton.new();game.lobby_character.name="YourCharacter";game.lobby_character.fit_to_longest_item=false;game.lobby_character.add_item("Team default");game.lobby_character.set_item_metadata(0,-1)
 for entry in NestCharacterCatalog.all():game.lobby_character.add_item(entry.name);game.lobby_character.set_item_metadata(game.lobby_character.item_count-1,int(entry.index))
 for i in range(game.lobby_character.item_count):
  if game.lobby_character.get_item_metadata(i)==game.selected_character:game.lobby_character.select(i)
 game.row(player_section,"Your character",game.lobby_character);game.lobby_character.get_parent().visible=game.can_edit_match_traits();game.lobby_character.disabled=not game.can_edit_match_traits();game.lobby_character.item_selected.connect(func(i):game.set_personal_lobby(int(game.lobby_character.get_item_metadata(i)),game.lobby_ready))
 var ready=CheckButton.new();ready.name="LobbyReady";ready.text="Ready";ready.button_pressed=game.lobby_ready;player_section.add_child(ready);ready.toggled.connect(func(on):game.set_personal_lobby(game.selected_character,on))
 var connection_section=section(game,left,"DIRECT CONNECTION",sections,headings);var join=game.button("Join by IP / Port / Link",func():game.show_connection(false));join.name="JoinByAddress";connection_section.add_child(join)
 var copy=game.button("Copy Join Address",game.copy_join_address);copy.name="CopyJoinAddress";copy.disabled=not game.network_active;connection_section.add_child(copy);connection_section.add_child(game.button("Connection Details",game.show_connection_details))
 var filter=func(query):
  results.visible=not query.strip_edges().is_empty()
  var found=0
  for key in sections:
   var count=NestMenuSearch.filter_group(sections[key],query,key)
   var shown=count>0 and (not query.strip_edges().is_empty() or key==category.get_item_text(category.selected))
   sections[key].visible=shown;headings[key].visible=shown;found+=count
  game.lobby_character.get_parent().visible=game.can_edit_match_traits()
  if game.lobby_vote.active():
   category.select(0);category.disabled=true;search.editable=false;results.visible=false
   for key in sections:sections[key].visible=key=="GAME SETUP";headings[key].visible=key=="GAME SETUP"
   for child in setup.get_children():child.visible=child.name=="LobbyVotePanel"
  results.text="" if query.strip_edges().is_empty() else ("Matching lobby actions below." if found>0 else "No matching lobby actions. Try another term or clear search.")
 search.text_changed.connect(filter)
 category.item_selected.connect(func(_index):search.text="";filter.call(""))
 filter.call("")
 var right=PanelContainer.new();right.name="PlayersPanel";right.custom_minimum_size.x=clampf(size.x*.29,260,340);columns.add_child(right)
 var right_box=VBoxContainer.new();right_box.add_theme_constant_override("separation",8);right.add_child(right_box);game.lobby_player_count_label=game.label("Players",18,game.GOLD);right_box.add_child(game.lobby_player_count_label)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right_box.add_child(scroll)
 game.lobby_roster_box=VBoxContainer.new();game.lobby_roster_box.name="RankedRoster";game.lobby_roster_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;game.lobby_roster_box.add_theme_constant_override("separation",8);scroll.add_child(game.lobby_roster_box);game.lobby_roster_signature=""
 var bottom=HBoxContainer.new();body.add_child(bottom);bottom.add_child(game.button("Leave Lobby",game.leave_custom_lobby));var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom.add_child(spacer)
 var start=game.button("START NEST FORGE" if game.lobby_kind=="forge" else "START GAME",func():game.start_forge_session() if game.lobby_kind=="forge" else game.begin_match());start.name="StartGame";start.disabled=game.is_client() or game.lobby_vote.active();start.custom_minimum_size.x=210
 if game.lobby_kind=="custom" and not game.can_edit_match_traits() and not game.lobby_vote.complete():start.text="VOTING IN PROGRESS" if game.lobby_vote.active() else "START VOTING"
 if game.is_client():start.text="Waiting for host"
 bottom.add_child(start);game.focus_later(start);game.refresh_lobby_network_ui()
static func section(game,parent: Control,title: String,sections: Dictionary,headings: Dictionary) -> VBoxContainer:
 var heading=game.label(title,13,game.GOLD);heading.custom_minimum_size.y=30;heading.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;parent.add_child(heading);headings[title]=heading
 var group=VBoxContainer.new();group.add_theme_constant_override("separation",10);group.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(group);sections[title]=group
 return group
static func refresh_roster(game) -> void:
 if not is_instance_valid(game.lobby_roster_box):return
 var members=game.lobby_members
 if members.is_empty():members={1:{"name":game.current_username(),"faction":game.selected_faction,"rating":game.ranked.profile.summary(),"character":game.selected_character,"ready":game.lobby_ready}}
 var channel="practice" if game.bot_fill and game.lobby_kind=="custom" else "human"
 var signature=str([members,channel,game.matchup,game.lobby_capacity()])
 if signature==game.lobby_roster_signature:return
 game.lobby_roster_signature=signature
 for child in game.lobby_roster_box.get_children():game.lobby_roster_box.remove_child(child);child.queue_free()
 var ids=members.keys();ids.sort()
 for id in ids:
  var member=members[id];var card=VBoxContainer.new();card.name="Player_%s"%id;game.lobby_roster_box.add_child(card)
  var color=Color("b73535") if game.MATCHUPS[game.matchup][int(member.faction)]==1 else Color("7da680")
  var name=game.label(String(member.name)+(" · HOST" if id==1 else ""),14,Color.WHITE);name.name="TeamHighlightedName";name.clip_text=true
  var style=StyleBoxFlat.new();style.bg_color=color.darkened(.25);style.content_margin_left=8;style.content_margin_top=5;style.content_margin_bottom=5;name.add_theme_stylebox_override("normal",style);card.add_child(name)
  var summary=NestRatingProfile.clean_summary(member.get("rating",{}));var badge=NestRankBadge.new();badge.light_theme=true;badge.name="LobbyRankBadge";card.add_child(badge);badge.update_rating(summary[channel],channel,0,0);badge.tier.text="TEAM "+("A" if int(member.faction)==0 else "B")+(" · READY" if member.get("ready",false) else " · NOT READY")
  card.add_child(HSeparator.new())
 game.lobby_player_count_label.text="Players  %d / %d"%[members.size(),game.game_type.max_players]
