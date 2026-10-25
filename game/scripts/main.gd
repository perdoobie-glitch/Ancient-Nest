extends NestMatch
const GOLD = Color("d9bd80")
const IVORY = Color("e6ede7")
const MUTED = Color("b3c2be")
var forge_editor
var accounts: NestAccountLink
var rank_badge: NestRankBadge
var rating_result_label: Label
var menu_camera: Camera3D
var canvas: CanvasLayer
var screen: Control
var hud: Control
var game_type_editor: NestGameTypeEditor
var match_setup: Window
var modal: Window
var current_screen: String = "main"
var armory_pivot: Node3D
var armory_info: Label
var settings_caller: String = "main"
var draft: Dictionary = {}
var draft_keys: Dictionary = {}
var settings_tab: String = "Controls"
var preferences_query: String=""
var preferences_groups: Dictionary={}
var preferences_headings: Dictionary={}
var preferences_buttons: Dictionary={}
var preferences_search: LineEdit
var preferences_results: Label
var preferences_reset: Button
var hud_faction: int = 0
var binding_action: String = ""
var binding_button: Button
var status_label: Label
var hud_health_model: String=""
var hud_capacities: Vector3=Vector3.ZERO
var lobby_character: OptionButton
var lobby_preview: NestLobbyPreview
var lobby_preview_yaw: float = 0
var last_preview_matchup: int = -1
var lobby_faction: OptionButton
var lobby_host_badge: Label
var lobby_roster_label: Label
var lobby_roster_box: VBoxContainer
var lobby_roster_signature=""
var lobby_player_count_label: Label
var quick_join_status_labels: Dictionary = {}
var quick_join_buttons: Dictionary = {}
var quick_join_cancel: Button
var scoreboard: PanelContainer
var menu_music: AudioStreamPlayer
var menu_music_fade: float = 0
var reference_hud: NestReferenceHud
var hud_top: RichTextLabel
var hud_role: Label
var hud_over: ProgressBar
var hud_protection: Label
var protection_bars: Array[ProgressBar] = []
var hud_weapon: Label
var hud_objective: Label
var hud_prompt: Label
var hud_interact: ProgressBar
var hud_recap_panel: PanelContainer
var hud_death_recap: RichTextLabel
var teammate_markers: NestTeamMarkers
var hud_death_backing: Panel
var hud_death_status: Label
var hud_kill_notice: PanelContainer
var hud_kill_name: Label
var hud_death: Label
var hud_feed: Label
var hud_chat: Label
var hud_crosshair: NestReticle
var hud_carry: Label
var radar: Control
var chat_entry: LineEdit
var chat_panel: PanelContainer
var hurt_overlay: ColorRect
var display_old: Dictionary = {}
var display_until: float = 0
var window_save_at: float=0
var last_hud_refresh: float = 0
var results_shown: bool = false
var restore_focus: String = "Custom Lobby"
var join_notices: VBoxContainer
var join_notice_rows: Array[Dictionary] = []
var training_session: bool=false
var lobby_vote: NestLobbyVote
var fall_audio: AudioStreamPlayer
func _ready() -> void:
	DisplayServer.window_set_title("Ancient Nest 10.5-dev")
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_title("Ancient Nest 10.5-dev")
	super._ready()
	lobby_vote=NestLobbyVote.new();lobby_vote.name="LobbyVote";lobby_vote.game=self;add_child(lobby_vote)
	if not matchmaking.active:select_normal_preset(mode,game_type.map_selection,game_type.matchup,false)
	accounts=NestAccountLink.new();accounts.game=self;add_child(accounts)
	AncientNestDiscordSocial.attach_game(self)
	if "--hybrid-worker" in OS.get_cmdline_user_args():
		var args=OS.get_cmdline_user_args();var url="";var token="";var port=7780
		for i in range(args.size()-1):
			if args[i]=="--hub":url=args[i+1]
			if args[i]=="--worker-token":token=args[i+1]
			if args[i]=="--port":port=int(args[i+1])
		if matchmaking.hybrid.connect_hub(url,true,token,port)!=OK:get_tree().quit(1)
		return
	if OS.has_feature("dedicated_server") or "--matchmaking-server" in OS.get_cmdline_user_args():
		var port=7780;var bind_address="*";var args=OS.get_cmdline_user_args()
		for i in range(args.size()-1):
			if args[i]=="--port":port=int(args[i+1])
			if args[i]=="--bind":bind_address=args[i+1]
		var error=matchmaking.start_server(port,bind_address)
		if error!=OK:push_error("Unable to open matchmaking server UDP port: "+str(error));get_tree().quit(1)
		return
	menu_camera=Camera3D.new()
	menu_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(menu_camera)
	menu_camera.position=Vector3(-48,35,49)
	menu_camera.look_at(Vector3(2,7,0))
	menu_camera.fov=57
	menu_camera.current=true
	canvas=CanvasLayer.new()
	add_child(canvas)
	var root=Control.new()
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	root.theme=make_theme()
	hud=Control.new(); root.add_child(hud); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen=Control.new(); root.add_child(screen); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	join_notices=VBoxContainer.new();join_notices.name="PlayerJoinNotifications";root.add_child(join_notices)
	join_notices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	join_notices.offset_left=-220;join_notices.offset_right=220;join_notices.offset_top=-208;join_notices.offset_bottom=-96
	join_notices.alignment=BoxContainer.ALIGNMENT_END;join_notices.add_theme_constant_override("separation",5)
	make_hud_passthrough(join_notices)
	get_tree().root.size_changed.connect(on_display_resized)
	show_main()
func show_join_notification(username: String) -> void:
	if not is_instance_valid(join_notices):return
	# This layer survives menu/HUD rebuilds and never captures gameplay input.
	while join_notice_rows.size()>=3:
		var old=join_notice_rows.pop_front();old.node.get_parent().remove_child(old.node);old.node.queue_free()
	var row=PanelContainer.new();row.name="PlayerJoinedNotice"
	var style=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.055,.88);style.set_corner_radius_all(5)
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=6;style.content_margin_bottom=6
	row.add_theme_stylebox_override("panel",style);join_notices.add_child(row)
	var text=label(username+(" joined the match" if running else " joined the lobby"),14,Color("a8dce8"));text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;row.add_child(text);make_hud_passthrough(row)
	join_notice_rows.append({"node":row,"until":Time.get_ticks_msec()/1000.0+4.5})
func update_join_notifications() -> void:
	var clock=Time.get_ticks_msec()/1000.0
	for index in range(join_notice_rows.size()-1,-1,-1):
		var notice=join_notice_rows[index]
		if clock>=notice.until:
			notice.node.get_parent().remove_child(notice.node);notice.node.queue_free();join_notice_rows.remove_at(index)
		else:notice.node.modulate.a=clampf((notice.until-clock)/.5,0,1)
func clear_join_notifications() -> void:
	for notice in join_notice_rows:
		if is_instance_valid(notice.node):notice.node.get_parent().remove_child(notice.node);notice.node.queue_free()
	join_notice_rows.clear()
func make_theme() -> Theme:
	var t=Theme.new()
	t.default_font=load("res://assets/body.ttf"); t.default_font_size=17
	for name in ["Button","OptionButton","CheckButton","SpinBox","TabBar","LineEdit"]:
		t.set_color("font_color",name,Color("124c38"))
		t.set_color("font_hover_color",name,Color("084d24"))
		t.set_color("font_focus_color",name,Color("084d24"))
		t.set_color("font_disabled_color",name,Color("6b786f"))
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style=NestMenuSurface.surface(true,state in ["hover","pressed","focus"])
			style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=13;style.content_margin_bottom=13
			t.set_stylebox(state,name,style)
	t.set_color("font_color","Label",IVORY)
	t.set_color("font_outline_color","Label",Color("f6fff4"))
	t.set_constant("outline_size","Label",0)
	t.set_color("font_color","PopupMenu",IVORY)
	t.set_color("font_hover_color","PopupMenu",IVORY)
	t.set_stylebox("panel","PopupMenu",panel_style())
	t.set_color("font_color","LineEdit",Color("124c38"))
	t.set_color("font_uneditable_color","LineEdit",MUTED)
	t.set_color("font_color","CheckBox",IVORY)
	t.set_stylebox("panel","PanelContainer",panel_style())
	t.set_stylebox("panel","AcceptDialog",panel_style())
	var track=StyleBoxFlat.new(); track.bg_color=Color("d6dfd2"); t.set_stylebox("background","ProgressBar",track)
	var fill=StyleBoxFlat.new(); fill.bg_color=GOLD; t.set_stylebox("fill","ProgressBar",fill)
	return t
func panel_style() -> StyleBoxTexture:
	var style=NestMenuSurface.surface()
	style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=24;style.content_margin_bottom=24
	return style
func label(text: String, font_size: int=17, color: Color=IVORY) -> Label:
	var l=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",color)
	return l
func title(text: String, size: int=40) -> Label:
	var l=label(text,size,Color("80e9b4")); l.add_theme_font_override("font",load("res://assets/title.ttf")); return l
func button(text: String, action: Callable, min_width: float=0) -> Button:
	var b=Button.new(); b.text=text; b.custom_minimum_size=Vector2(min_width,48); b.pressed.connect(action); return b
func open_films() -> void:
	clear_screen();shade();current_screen="films";context="menu"
	film_viewer=load("res://scripts/film_viewer.gd").new();film_viewer.game=self;canvas.add_child(film_viewer)
func clear_screen() -> void:
	# Opaque artwork menus do not need a second, hidden 3D arena render.
	get_viewport().disable_3d=not running
	if is_instance_valid(lobby_preview) and not lobby_preview.pivots.is_empty():lobby_preview_yaw=lobby_preview.pivots[0].rotation.y
	for child in screen.get_children(): screen.remove_child(child); child.queue_free()
	binding_action=""
func shade(alpha: float=0.7) -> void:
	if not running:
		var art=TextureRect.new();art.texture=NestMenuSurface.artwork();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background=TextureRect.new();screen.add_child(background);background.texture=NestMenuSurface.backdrop();background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_SCALE;background.modulate.a=alpha;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE
func center_panel(width: float=1060, height: float=700) -> VBoxContainer:
	var p=PanelContainer.new(); screen.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left=-width/2; p.offset_right=width/2; p.offset_top=-height/2; p.offset_bottom=height/2
	var v=VBoxContainer.new(); p.add_child(v); v.add_theme_constant_override("separation",15)
	return v
func header(parent: VBoxContainer, small: String, name: String) -> void:
	parent.add_child(label(small,13,GOLD)); parent.add_child(title(name,36)); parent.add_child(HSeparator.new())
func footer(parent: VBoxContainer, push_bottom: bool=true) -> HBoxContainer:
	if push_bottom:
		var spacer=Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; parent.add_child(spacer)
	var h=HBoxContainer.new(); h.add_theme_constant_override("separation",12); parent.add_child(h); return h
func show_main() -> void:
	if is_instance_valid(forge_editor):forge_editor.exit_editor(false)
	current_screen="main";context="menu";clear_screen();hud.visible=false
	menu_camera.current=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var backdrop=ColorRect.new();backdrop.color=Color("101718");backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art=TextureRect.new();art.name="SanctuaryMenuArtwork";art.texture=NestMenuSurface.artwork();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var size=get_viewport().get_visible_rect().size
	var panel=PanelContainer.new();panel.name="MainNavigation";screen.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left=24;panel.offset_right=-24;panel.offset_top=-220 if size.x>=1000 else -278;panel.offset_bottom=-12
	var style=StyleBoxEmpty.new();style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=12;style.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);panel.add_child(column)
	var studio=label("PERDOOBIE & MISHWAD STUDIO",13,GOLD);NestMenuSurface.plasma_lettering(studio);studio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(studio)
	var grid=GridContainer.new();grid.columns=6 if size.x>=1000 else 2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",8);column.add_child(grid)
	var choices=[["Play",show_play_menu],["Server Browser",open_server_browser],["Films",open_films],["Nest Forge",open_forge],["Armory",show_armory],["Settings",func():open_settings("main")],["Quit Game",quit_dialog]]
	var primary: Array[Button]=[]
	for choice in choices:
		var entry=button(choice[0],choice[1]);NestMenuSurface.main_button(entry,true);entry.clip_text=true;entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entry.custom_minimum_size=Vector2(0,42);grid.add_child(entry);primary.append(entry)
	for i in range(primary.size()):
		primary[i].focus_neighbor_left=primary[i].get_path_to(primary[(i+primary.size()-1)%primary.size()]);primary[i].focus_neighbor_right=primary[i].get_path_to(primary[(i+1)%primary.size()])
	var selected=primary.filter(func(entry):return entry.text==restore_focus)
	focus_later(primary[0] if selected.is_empty() else selected[0])
	var note=label("ANCIENT NEST 10.5-dev  /  FRONTIER MAPS",11,MUTED);NestMenuSurface.plasma_lettering(note);note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(note)
	var identity=button("Player: "+current_username(),func():accounts.show_service_card());NestMenuSurface.main_button(identity);identity.name="EditUsername";identity.clip_text=true;identity.add_theme_font_size_override("font_size",14)
	screen.add_child(identity);identity.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);identity.offset_left=-320;identity.offset_right=-24;identity.offset_top=20;identity.offset_bottom=66
	var discord=button("[I] Discord dashboard",open_discord_dashboard);NestMenuSurface.main_button(discord,true);discord.name="DiscordDashboardShortcut";column.add_child(discord);discord.custom_minimum_size.y=36
	# Warm new shared geometry and materials before a player enters combat.
	if not has_meta("menu_weapons_warmed"):
		set_meta("menu_weapons_warmed",true)
		for kind in ["smg","plasma_smg","plasma_sniper","plasma_br","plasma_auto","plasma_pistol"]:
			var preview=NestWeaponArt.create(kind,0);preview.free()
func show_player_menu() -> void:
	current_screen="player";context="menu";clear_screen();shade();hud.visible=false
	var body=center_panel(minf(600,get_viewport().get_visible_rect().size.x-32),430);header(body,"YOUR PLAYER",current_username())
	body.add_child(button("Change Username",show_username_dialog))
	body.add_child(button("Service Card",func():accounts.show_service_card()))
	body.add_child(button("Account & Game Linking",func():accounts.show_panel()))
	body.add_child(button("Connection Details",show_connection_details))
	footer(body,false).add_child(button("Back",show_main,120))
func show_play_menu() -> void:
	current_screen="play";context="menu";clear_screen();shade();hud.visible=false
	var size=get_viewport().get_visible_rect().size
	var body=center_panel(minf(1100,size.x-32),minf(710,size.y-32));header(body,"ANCIENT NEST / MULTIPLAYER", "PLAY")
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	var entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries.add_theme_constant_override("separation",12);scroll.add_child(entries)
	for entry in [["Matchmaking",open_matchmaking],["Custom Match",open_custom_lobby],["Join by IP / Port",func():show_connection(false)],["Training · Configure bot practice",func():reference_mode_lobby(1,true)]]:
		entries.add_child(button(entry[0],entry[1]))
	var hint=label("Choose your game type, map and teams together in Custom Match.\nTraining opens a bot-practice lobby. Matchmaking requires online services.",14,MUTED);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;entries.add_child(hint)
	footer(body,false).add_child(button("Back",show_main,120))
func reference_mode_lobby(mode_id: int, practice: bool) -> void:
	if not is_client():
		var rules: GameTypeSettings=NestMatchPresets.create(mode_id,2,1)
		if practice:rules.bots_fill_empty_slots=true;rules.bots_dont_shoot=false;rules.max_players_per_team=2;rules.max_players=4
		apply_game_type_settings(rules)
	open_custom_lobby(practice)
func show_armory() -> void:
	current_screen="armory";context="menu";clear_screen();shade();hud.visible=false
	var size=get_viewport().get_visible_rect().size
	var body=center_panel(minf(1180,size.x-30),minf(730,size.y-30));header(body,"ANNU / NAKI / RELICS","ARMORY")
	var columns=HBoxContainer.new();columns.add_theme_constant_override("separation",18);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(columns)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=250;columns.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var right=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(right)
	var container=SubViewportContainer.new();container.stretch=true;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.custom_minimum_size=Vector2(240,220);right.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(640,380);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.handle_input_locally=false;container.add_child(viewport)
	var stage=Node3D.new();viewport.add_child(stage);armory_pivot=Node3D.new();stage.add_child(armory_pivot)
	var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("111b17");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e7e1ce");env.ambient_light_energy=.85;environment.environment=env;stage.add_child(environment)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-35,0);sun.light_energy=1.6;stage.add_child(sun)
	var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(.85,.28,-.95);camera.look_at(Vector3(0,0,-.15));camera.fov=36
	armory_info=label("",17);armory_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;right.add_child(armory_info)
	for definition in NestWeaponCatalog.data().weapons:
		if definition.kind in ["frag_grenade","plasma_grenade"]:continue
		var kind=String(definition.kind);var entry=button(String(definition.title),func():armory_select(kind));entry.add_theme_font_size_override("font_size",14);list.add_child(entry)
	list.add_child(button("Talon Knife",func():armory_select("knife")))
	list.add_child(button("Nexus Blade",func():armory_select("plasma_sword")))
	footer(body,false).add_child(button("Back",show_main,120));armory_select("ak47")
func armory_select(kind: String) -> void:
	for child in armory_pivot.get_children():armory_pivot.remove_child(child);child.queue_free()
	armory_pivot.rotation=Vector3(0,-.35,0);armory_pivot.add_child(NestWeaponArt.create(kind,0))
	if kind=="knife":armory_info.text="Talon Knife\nAnnu conventional combat knife · F to melee";return
	var weapon=NestWeaponCatalog.profile(kind)
	armory_info.text=weapon.title+"\n"+("Annu conventional / red & black" if kind in ["rifle","burst","burst_scoped","ak47","smg","sidearm","sniper"] else "Relic / stone, gold & blue" if kind in ["rocket","shotgun"] else "Naki energy / ivory, graphite & green")
	if kind!="plasma_sword":
		var definition=NestWeaponCatalog.for_kind(kind);var count=int(definition.get("burst_count",1))
		var cadence="%d-round burst · %.2f s cycle"%[count,weapon.interval] if count>1 else "%.0f RPM"%(60/maxf(.001,weapon.interval))
		armory_info.text+="\n%d rounds · %s · %.1f s reload"%[weapon.magazine,cadence,weapon.reload_seconds]
		if definition.has("accuracy_grade"):armory_info.text+="\nTier %d · Accuracy %s · %.0f m working range"%[int(definition.get("tier",0)),str(definition.accuracy_grade),float(definition.get("accuracy_range_m",0))]
		if not definition.get("explosive",false):armory_info.text+="\n%.1f body / %.1f head · before defenses & range"%[float(definition.get("damage_body",weapon.damage)),float(definition.get("damage_body",weapon.damage))*2.0]
func show_rating() -> void:
	if not running:load("res://scripts/rating_page.gd").show(self)
func open_custom_lobby(practice: bool=false) -> void:
	if running:return
	training_session=practice
	if not is_client():lobby_kind="custom"
	show_lobby()
func open_forge() -> void:
	if running:return
	if is_client():info("Nest Forge","The host selects when to open Nest Forge.");return
	lobby_kind="forge";show_lobby();broadcast_lobby()
func start_forge_session() -> void:
	if not is_client() and not running:forge_session.start()
func enter_forge_editor() -> void:
	close_username_dialog();clear_held_input()
	var saved=Transform3D.IDENTITY
	if is_instance_valid(forge_editor):
		if is_instance_valid(forge_editor.camera):saved=forge_editor.camera.global_transform
		forge_editor.close_ui();forge_editor.queue_free()
	forge_editor=load("res://scripts/forge_editor.gd").new();forge_editor.name="ForgeEditor";forge_editor.game=self;add_child(forge_editor);forge_editor.open_editor()
	if saved!=Transform3D.IDENTITY:forge_editor.camera.global_transform=saved
func leave_forge_editor_ui(show_lobby_after: bool=true) -> void:
	if is_instance_valid(forge_editor):forge_editor.close_ui();forge_editor.queue_free()
	forge_editor=null;clear_held_input();hud.visible=false;menu_camera.current=true
	if show_lobby_after:show_lobby()
func show_lobby() -> void:
	if matchmaking.browser_mode and not running:
		matchmaking.leave();open_server_browser();return
	if matchmaking.active:show_matchmaking();return
	NestLobbyScreen.show(self)
func lobby_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll=ScrollContainer.new(); scroll.name=tab_name; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; tabs.add_child(scroll)
	var margin=MarginContainer.new(); margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for edge in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+edge,16)
	scroll.add_child(margin)
	var body=VBoxContainer.new(); body.add_theme_constant_override("separation",12); margin.add_child(body); return body
func lobby_rules_summary() -> String:
	var duration="No time limit" if tuning.round_seconds<=0 else "%d:%02d time limit"%[int(tuning.round_seconds)/60,int(tuning.round_seconds)%60]
	var text="%s · First to %d · %s\n%s · %d players per team"%[MODE_NAMES[clampi(mode,0,4)],tuning.score_limit,duration,["Naki vs Annu","Naki vs Naki","Annu vs Annu","Annu vs Naki"][matchup],team_size]
	if mode==MODE_CS:text+="\nA/B bomb sites · One life · 3.2s plant · 40s fuse\nDefuse: "+("5s (kit)" if game_type.cs_defuse_kits else "10s")
	if mode==0:text+="\n%d gold bags per round"%tuning.bag_stock
	return text
func lobby_loadout_summary() -> String:
	var weapon_names=[]
	var character=NestCharacterCatalog.by_index(selected_character if selected_character>=0 else int(MATCHUPS[matchup][selected_faction]))
	for id in [NestCharacterTraits.value(game_type,character.id,"starting_primary"),NestCharacterTraits.value(game_type,character.id,"starting_secondary")]:
		weapon_names.append("Faction default" if id=="default" else "None" if id=="none" else NestWeaponCatalog.definition(id).get("title",id))
	var bots="Bots off" if not bot_fill else "Bots fill empty slots · %s · Objectives %s"%[bot_difficulty.capitalize(),"on" if bot_play_objectives else "off"]
	return "Your %s loadout\nPrimary: %s\nSecondary: %s\n%s"%[character.name,weapon_names[0],weapon_names[1],bots]
func open_game_type_settings() -> void:
	if not can_edit_match_traits():return
	if running and context!="pause":return
	if is_instance_valid(game_type_editor):game_type_editor.grab_focus();return
	clear_held_input();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().root.gui_embed_subwindows=true
	game_type_editor=NestGameTypeEditor.new();game_type_editor.game=self;add_child(game_type_editor)
	var available=get_viewport().get_visible_rect().size
	game_type_editor.popup_centered(Vector2i(minf(960,available.x*.9),minf(680,available.y*.86)))
func live_rules_changed() -> void:
	# Avoid leaving a connected client's read-only editor showing stale rules.
	if is_instance_valid(game_type_editor):
		game_type_editor.hide();game_type_editor.queue_free()
		if context=="pause":call_deferred("show_pause")
func refresh_lobby_network_ui() -> void:
	if current_screen!="lobby":return
	if is_instance_valid(lobby_host_badge):lobby_host_badge.text=lobby_network.host_badge_text() if lobby_network!=null else network_status
	NestLobbyScreen.refresh_roster(self)

func map_changed_ui() -> void:
	# Old world-bound references must not keep the deleted arena alive.
	if is_instance_valid(radar):radar.queue_redraw()
func reset_forge_layout() -> void:
	confirm("Use default map?","This removes the current unsaved layout from the lobby. Save it in Nest Forge first if you want to keep it.",func():forge_session.clear();broadcast_lobby();show_lobby(),"Use Default")
func load_forge_layout_from_lobby() -> void:
	var load_action=func():
		if forge_session.load_saved():broadcast_lobby();show_lobby()
		else:info("Nest Forge Layout","No compatible saved layout was found on this computer.")
	if forge_session.dirty:confirm("Load saved layout?","This replaces the current unsaved edits. Save them in Nest Forge first to keep them.",load_action,"Load Saved")
	else:load_action.call()
func leave_custom_lobby() -> void:
	forge_session.active=false
	if is_instance_valid(forge_editor):leave_forge_editor_ui(false)
	if lobby_network!=null: lobby_network.leave_lobby()
	show_main()

func row(parent: VBoxContainer, text: String, control: Control) -> void:
	var h=HBoxContainer.new(); h.add_theme_constant_override("separation",15); parent.add_child(h)
	var l=label(text,15); l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(l); control.custom_minimum_size.x=190; h.add_child(control)
func begin_match() -> void:
	if running or is_client(): return
	if lobby_kind=="custom" and not can_edit_match_traits() and not lobby_vote.complete():
		lobby_vote.start();return
	if lobby_vote.active():return
	close_username_dialog()
	clear_screen(); shade()
	var v=center_panel(520,260); header(v,arena.map_title().to_upper(), "Preparing arena")
	v.add_child(label("Loading local players and match rules…",16,MUTED))
	await get_tree().process_frame
	clear_screen(); start_game(); current_screen="playing"; results_shown=false
	create_hud(); hud.visible=true
func create_hud() -> void:
	hud_health_model=player.damage_model();hud_capacities=Vector3(player.tuning.health_capacity,player.tuning.shield_capacity,player.tuning.armor_capacity)
	var shield_hud=player.damage_model()=="naki" and player.tuning.shield_capacity>0
	for child in hud.get_children(): hud.remove_child(child); child.queue_free()
	hurt_overlay=NestShieldHUD.new(); hurt_overlay.game=self; hud.add_child(hurt_overlay); hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient=Gradient.new(); gradient.colors=PackedColorArray([Color(.015,.028,.035,.62),Color(.015,.028,.035,.38),Color(.015,.028,.035,0)]); gradient.offsets=PackedFloat32Array([0,.65,1])
	var texture=GradientTexture2D.new(); texture.gradient=gradient; texture.fill_from=Vector2(.5,0); texture.fill_to=Vector2(.5,1)
	var backing=TextureRect.new(); backing.texture=texture; backing.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(backing); backing.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); backing.offset_left=-400; backing.offset_right=400; backing.offset_top=0; backing.offset_bottom=188
	var rank_backing=ColorRect.new();rank_backing.color=Color(.015,.025,.03,.78);rank_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;rank_backing.position=Vector2(20,18);rank_backing.size=Vector2(310,84);hud.add_child(rank_backing)
	rank_badge=NestRankBadge.new();rank_badge.name="LiveRankBadge";hud.add_child(rank_badge);rank_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);rank_badge.position=Vector2(28,24)
	hud_top=RichTextLabel.new();hud_top.bbcode_enabled=true;hud_top.fit_content=true;hud_top.scroll_active=false;hud_top.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud_top.add_theme_font_size_override("normal_font_size",26)
	hud.add_child(hud_top); hud_top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hud_top.offset_left=-330; hud_top.offset_right=330; hud_top.offset_top=25;hud_top.offset_bottom=60
	hud_role=label("",13,GOLD); hud_role.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud_role); hud_role.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hud_role.offset_left=-330; hud_role.offset_right=330; hud_role.offset_top=65
	hud_protection=label("",17); hud.add_child(hud_protection)
	if shield_hud:
		hud_protection.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hud_protection.offset_left=-220; hud_protection.offset_right=220; hud_protection.offset_top=90; hud_protection.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	else:
		hud_protection.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); hud_protection.offset_left=40; hud_protection.offset_top=-80; hud_protection.offset_bottom=-30
	protection_bars.clear()
	for i in range(1 if player.damage_model()=="naki" else 2):
		var meter=ProgressBar.new(); meter.show_percentage=false; meter.max_value=maxf(1.0,player.tuning.shield_capacity if shield_hud else player.tuning.health_capacity if i==0 else player.tuning.armor_capacity); hud.add_child(meter); protection_bars.append(meter)
		var fill_style=StyleBoxFlat.new(); fill_style.bg_color=Color("52ed72") if shield_hud else (Color("80b17b") if i==0 else GOLD); fill_style.set_corner_radius_all(4); meter.add_theme_stylebox_override("fill",fill_style)
		if shield_hud:
			meter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); meter.offset_left=-180; meter.offset_right=180; meter.offset_top=116; meter.offset_bottom=125
		else:
			meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); meter.offset_left=40; meter.offset_right=270; meter.offset_top=-55+i*15; meter.offset_bottom=-46+i*15
	hud_over=ProgressBar.new();hud_over.show_percentage=false;hud_over.max_value=tuning.overshield_capacity;hud.add_child(hud_over);hud_over.visible=false
	var over_fill=StyleBoxFlat.new();over_fill.bg_color=Color("52ed72");over_fill.set_corner_radius_all(4);hud_over.add_theme_stylebox_override("fill",over_fill)
	if shield_hud:
		hud_over.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);hud_over.offset_left=-180;hud_over.offset_right=180;hud_over.offset_top=130;hud_over.offset_bottom=139
	else:
		hud_over.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);hud_over.offset_left=40;hud_over.offset_right=270;hud_over.offset_top=-25;hud_over.offset_bottom=-16
	hud_weapon=label("",21); hud_weapon.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hud_weapon); hud_weapon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); hud_weapon.offset_left=-420; hud_weapon.offset_right=-40; hud_weapon.offset_top=-135; hud_weapon.offset_bottom=-35
	hud_objective=label("",14,GOLD); hud_objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud_objective); hud_objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); hud_objective.offset_left=-500; hud_objective.offset_right=500; hud_objective.offset_top=144
	hud_prompt=label("",18); hud_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud_prompt); hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER); hud_prompt.offset_left=-350; hud_prompt.offset_right=350; hud_prompt.offset_top=72; hud_prompt.offset_bottom=108
	hud_interact=ProgressBar.new(); hud_interact.show_percentage=false
	hud.add_child(hud_interact); hud_interact.set_anchors_and_offsets_preset(Control.PRESET_CENTER); hud_interact.offset_left=-150; hud_interact.offset_right=150; hud_interact.offset_top=115; hud_interact.offset_bottom=122
	hud_crosshair=NestReticle.new(); hud_crosshair.game=self
	hud.add_child(hud_crosshair); hud_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	teammate_markers=NestTeamMarkers.new(); teammate_markers.game=self; hud.add_child(teammate_markers); teammate_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_death_backing=Panel.new();hud.add_child(hud_death_backing);hud_death_backing.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_death_backing.offset_left=-500;hud_death_backing.offset_right=500;hud_death_backing.offset_top=-160;hud_death_backing.offset_bottom=45
	var death_style=StyleBoxFlat.new();death_style.bg_color=Color(.025,.015,.02,.86);death_style.border_color=Color("9e272d");death_style.border_width_top=3;death_style.set_corner_radius_all(6);hud_death_backing.add_theme_stylebox_override("panel",death_style);hud_death_backing.visible=false
	hud_recap_panel=PanelContainer.new();hud_recap_panel.name="DamageExchangeRecap";hud.add_child(hud_recap_panel)
	hud_recap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);hud_recap_panel.offset_left=-390;hud_recap_panel.offset_right=-35;hud_recap_panel.offset_top=20;hud_recap_panel.offset_bottom=162
	var recap_style=StyleBoxFlat.new();recap_style.bg_color=Color(.025,.025,.03,.9);recap_style.border_color=GOLD;recap_style.border_width_top=2;recap_style.set_corner_radius_all(3);recap_style.content_margin_left=10;recap_style.content_margin_right=10;recap_style.content_margin_top=7;recap_style.content_margin_bottom=7;hud_recap_panel.add_theme_stylebox_override("panel",recap_style)
	hud_death_recap=RichTextLabel.new();hud_death_recap.bbcode_enabled=true;hud_death_recap.scroll_active=false;hud_death_recap.add_theme_font_size_override("normal_font_size",13);hud_death_recap.add_theme_font_override("bold_font",load("res://assets/body_bold.ttf"));hud_death_recap.add_theme_font_size_override("bold_font_size",13);hud_death_recap.add_theme_constant_override("line_separation",3);hud_recap_panel.add_child(hud_death_recap);hud_recap_panel.visible=false
	hud_death=label("",40);hud_death.add_theme_font_override("font",load("res://assets/body_bold.ttf")); hud_death.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud_death.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hud_death); hud_death.set_anchors_and_offsets_preset(Control.PRESET_CENTER); hud_death.offset_left=-450; hud_death.offset_right=450; hud_death.offset_top=-145; hud_death.offset_bottom=-35
	hud_death_status=label("",18);hud_death_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(hud_death_status)
	hud_death_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER);hud_death_status.offset_left=-480;hud_death_status.offset_right=480;hud_death_status.offset_top=-15;hud_death_status.offset_bottom=40
	hud_carry=label("",16,GOLD); hud_carry.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud_carry); hud_carry.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hud_carry.offset_left=-350; hud_carry.offset_right=350; hud_carry.offset_top=-70; hud_carry.offset_bottom=-30
	hud_feed=label("",13); hud_feed.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hud_feed); hud_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); hud_feed.offset_left=-500; hud_feed.offset_right=-35; hud_feed.offset_top=82
	hud_kill_notice=PanelContainer.new();hud_kill_notice.name="PersonalKillNotice";hud.add_child(hud_kill_notice)
	hud_kill_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);hud_kill_notice.offset_left=-390;hud_kill_notice.offset_right=-35;hud_kill_notice.offset_top=35;hud_kill_notice.offset_bottom=71
	var notice_style=StyleBoxFlat.new();notice_style.bg_color=Color(.025,.025,.03,.8);notice_style.set_corner_radius_all(3);notice_style.content_margin_left=10;notice_style.content_margin_right=6;notice_style.content_margin_top=4;notice_style.content_margin_bottom=4;hud_kill_notice.add_theme_stylebox_override("panel",notice_style)
	var notice_row=HBoxContainer.new();notice_row.add_theme_constant_override("separation",9);hud_kill_notice.add_child(notice_row)
	var notice_prefix=label("You killed",14);notice_row.add_child(notice_prefix)
	var name_highlight=PanelContainer.new();name_highlight.size_flags_horizontal=Control.SIZE_EXPAND_FILL;notice_row.add_child(name_highlight)
	var red=StyleBoxFlat.new();red.bg_color=Color("9e272d");red.set_corner_radius_all(3);red.content_margin_left=8;red.content_margin_right=8;name_highlight.add_theme_stylebox_override("panel",red)
	hud_kill_name=label("",14,Color.WHITE);hud_kill_name.clip_text=true;hud_kill_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name_highlight.add_child(hud_kill_name);hud_kill_notice.visible=false
	radar=Control.new(); radar.set_script(load("res://scripts/radar.gd")); radar.game=self; hud.add_child(radar)
	hud_chat=label("",14,MUTED); hud.add_child(hud_chat)
	hud_chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); hud_chat.offset_left=40; hud_chat.offset_right=540; hud_chat.offset_top=-315; hud_chat.offset_bottom=-235
	chat_panel=PanelContainer.new(); hud.add_child(chat_panel); chat_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); chat_panel.offset_left=40; chat_panel.offset_right=550; chat_panel.offset_top=-360; chat_panel.offset_bottom=-300
	var light=StyleBoxFlat.new(); light.bg_color=Color(0.02,0.04,0.05,0.22); light.content_margin_top=5; light.content_margin_bottom=5; chat_panel.add_theme_stylebox_override("panel",light)
	chat_entry=LineEdit.new(); chat_entry.placeholder_text="Message or God command…  Enter: send / Esc: cancel"; chat_entry.max_length=200; chat_panel.add_child(chat_entry); chat_panel.visible=false
	chat_entry.text_submitted.connect(func(text):
		if send_chat(text): close_chat_ui()
		elif text.strip_edges().is_empty(): close_chat_ui()
	)
	reference_hud=NestReferenceHud.new();reference_hud.game=self;hud.add_child(reference_hud)
	hud_top.visible=false;hud_weapon.visible=false;hud_role.offset_top=72
	scoreboard=NestScoreboard.new(); scoreboard.game=self; hud.add_child(scoreboard); scoreboard.anchor_left=.12;scoreboard.anchor_right=.88;scoreboard.anchor_top=.13;scoreboard.anchor_bottom=.88;scoreboard.offset_left=0;scoreboard.offset_right=0;scoreboard.offset_top=0;scoreboard.offset_bottom=0
	scoreboard.visible=false
	make_hud_passthrough(hud)
	set_hud_preferences()
func local_character_changed() -> void:
	# Protection HUD layout depends on the character (shields vs health/armor).
	if running and is_instance_valid(hud) and is_instance_valid(hud_top): create_hud(); hud.visible=true
func make_hud_passthrough(node: Node) -> void:
	# The chat entry is interactive when shown; every other HUD element is read-only.
	if node==chat_panel: return
	if node is Control: node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.focus_mode=Control.FOCUS_NONE
	for child in node.get_children(): make_hud_passthrough(child)
func set_hud_preferences() -> void:
	if not running or not is_instance_valid(radar): return
	var prefix="naki" if player.character==0 else "annu"
	var radar_size=prefs.values[prefix+"_radar_size"]*prefs.values.hud_scale
	var radar_width=radar_size*1.35 if prefix=="annu" else radar_size
	var radar_height=radar_size*1.1 if prefix=="annu" else radar_size
	var corner=prefs.values[prefix+"_radar_corner"]
	var presets=[Control.PRESET_BOTTOM_LEFT,Control.PRESET_TOP_LEFT,Control.PRESET_BOTTOM_RIGHT,Control.PRESET_TOP_RIGHT]
	radar.set_anchors_and_offsets_preset(presets[corner])
	radar.offset_left=35 if corner<2 else -35-radar_width
	radar.offset_right=35+radar_width if corner<2 else -35
	radar.offset_top=-35-radar_height if corner in [0,2] else (125 if corner==1 and prefix=="annu" else 35)
	radar.offset_bottom=-35 if corner in [0,2] else radar.offset_top+radar_height
	radar.visible=prefs.values.radar
	hud_crosshair.visible=true
	hud.modulate.a=prefs.values.hud_opacity
	if is_instance_valid(reference_hud):reference_hud.layout()
	hud_top.add_theme_font_size_override("normal_font_size",int(26*prefs.values.hud_scale))
	for item in [hud_role,hud_protection,hud_weapon,hud_objective,hud_prompt,hud_carry,hud_feed,hud_chat]: item.add_theme_font_size_override("font_size",int((26 if item==hud_top else 16)*prefs.values.hud_scale))
func _process(delta: float) -> void:
	if matchmaking!=null and matchmaking.dedicated:return
	if window_save_at>0 and Time.get_ticks_msec()/1000.0>=window_save_at:
		window_save_at=0
		if display_until==0:prefs.save()
	update_join_notifications()
	update_menu_music(delta)
	if current_screen=="results" and is_instance_valid(rating_result_label):rating_result_label.text=ranked.result_text()
	if is_instance_valid(forge_editor) and forge_editor.editing:return
	if current_screen=="lobby": refresh_lobby_network_ui()
	if current_screen=="armory" and is_instance_valid(armory_pivot):armory_pivot.rotation.y+=delta*.22
	if not running:
		menu_camera.position=Vector3(-48+sin(Time.get_ticks_msec()*0.00006)*2,35,49)
		menu_camera.look_at(Vector3(2,7,0))
	if display_until>0:
		if is_instance_valid(modal): modal.dialog_text="Keep these display settings?\nReverting in %d seconds."%ceil(display_until-Time.get_ticks_msec()/1000.0)
		if Time.get_ticks_msec()/1000.0>=display_until: revert_display()
	if not running or not is_instance_valid(player): return
	if is_instance_valid(hud_top) and (hud_health_model!=player.damage_model() or hud_capacities!=Vector3(player.tuning.health_capacity,player.tuning.shield_capacity,player.tuning.armor_capacity)):create_hud()
	update_flag_visuals()
	if finished and not results_shown and not replay_active: results_shown=true; show_results()
	if not is_instance_valid(hud_top): return
	if is_instance_valid(rank_badge):rank_badge.update_rating(player.rank_human if ranked.channel=="human" else player.rank_practice,ranked.channel,player.kills,player.deaths,not matchmaking.active)
	if hud_top.visible:
		var remaining=maxf(0,(float(site_states[bomb_site].bomb_at) if mode==MODE_CS and cs_planted() else deadline)-now)
		var left_color="b73535" if team_characters[0]==1 else "7da680"
		var right_color="b73535" if team_characters[1]==1 else "7da680"
		var clock_text=("%02d:%02d"%[int(remaining)/60,int(remaining)%60]) if is_finite(remaining) else "NO LIMIT"
		hud_top.text="[center][color=#%s]%s  %02d[/color]      %s      [color=#%s]%02d  %s[/color][/center]"%[left_color,team_name(0),scores[0],clock_text,right_color,scores[1],team_name(1)]
	hud_role.text="ROUND %d  ·  %s  ·  FIRST TO %d"%[round_number,("ATTACKERS" if player.is_attacker() else "DEFENDERS") if mode in [0,MODE_CS] else MODE_NAMES[mode],tuning.score_limit]+"  ·  "+["BOTTOM","MIDDLE","TOP"][arena.level_at(player.global_position.y)]
	var protection_text=""
	if player.damage_model()=="naki" and player.tuning.shield_capacity<=0:
		protection_text="HEALTH  %d"%roundi(player.health)
		protection_bars[0].value=player.health
	elif player.damage_model()=="naki":
		protection_text="SHIELD" # bar only: no shield number
		protection_bars[0].value=player.shield
		if player.shield<player.tuning.shield_capacity and now-player.last_damage>=player.tuning.shield_delay: protection_text+="  ·  RECHARGING"
		if player.overshield>0: protection_text+="  ·  SHIELD"
	else:
		protection_text="HEALTH  %d     ARMOR  %d"%[roundi(player.health),roundi(player.armor)]
		protection_bars[0].value=player.health; protection_bars[1].value=player.armor
		if player.overshield>0: protection_text+="  ·  BONUS %d"%player.overshield
	if is_instance_valid(hud_over):
		hud_over.visible=player.overshield>0;hud_over.value=player.overshield
		if player.overshield>0:
			var over_seconds=maxi(0,ceili(player.over_deadline-now))
			protection_text+="  ·  %d:%02d"%[over_seconds/60,over_seconds%60]
	if hud_protection.text!=protection_text:hud_protection.text=protection_text
	if hud_weapon.visible:
		var w=player.weapons[player.slot]
		var ready_text="RELOADING" if player.action_state=="reloading" else "READY"
		var scoped_config=NestWeaponCatalog.for_kind(w.kind)
		var levels=maxi(scoped_config.get("scope_fov",[]).size(),scoped_config.get("zoom_factors",[]).size())
		if levels>0 and player.action_state=="ready": ready_text=("ZOOM %d/%d · " %[player.scope_level,levels] if player.is_scoped() else "")+"RMB / "+prefs.key_label("zoom")+": zoom"
		hud_weapon.text=w.title.to_upper()+"\n%s / %s   ·   %s"%[("∞" if player.traits.infinite_ammo==2 else "%02d"%player.ammo[player.slot]),("∞" if player.traits.infinite_ammo>0 else "%03d"%player.reserve[player.slot]),ready_text]+"\n%s  %d  ·  %s: switch"%["STICKY" if player.grenade_kind==1 else "FRAG",player.grenades[player.grenade_kind],prefs.key_label("grenade_type")]
		if w.kind=="none": hud_weapon.text="UNARMED\nMelee / grenades available"
	hud_prompt.text=interaction_text
	hud_interact.visible=interaction_progress>0
	hud_interact.max_value=maxf(interaction_duration,0.01); hud_interact.value=interaction_progress
	hud_recap_panel.visible=not player.alive and not player.death_recap.is_empty()
	hud_death_recap.text=player.death_recap_hud_text() if hud_recap_panel.visible else ""
	hud_kill_notice.offset_top=174 if hud_recap_panel.visible else 35;hud_kill_notice.offset_bottom=hud_kill_notice.offset_top+36
	hud_feed.offset_top=221 if hud_recap_panel.visible else 82
	hud_death_backing.visible=not player.alive or break_until>now
	var death_color=Color("ff5656") if not player.alive and not str(player.death_recap.get("killer","")).is_empty() else IVORY
	if hud_death.get_theme_color("font_color")!=death_color:hud_death.add_theme_color_override("font_color",death_color)
	var death_text="";var death_status=""
	if not player.alive:
		var killer=str(player.death_recap.get("killer",""))
		death_text="KILLED BY\n"+killer if not killer.is_empty() and not player.death_recap.get("environment",false) else "YOU WERE ELIMINATED"
		death_status="Next life at the next round" if mode==MODE_CS else "Respawn in %.1f"%maxf(0,player.respawn_at-now)
	if break_until>now:
		if player.alive:death_text=round_reason.to_upper()
		death_status="Next round in %d"%ceil(break_until-now)
	if hud_death.text!=death_text:hud_death.text=death_text
	if hud_death_status.text!=death_status:hud_death_status.text=death_status
	hud_kill_notice.visible=local_kill_notice_until>now and not local_kill_notice.is_empty()
	hud_kill_name.text=local_kill_notice
	hud_carry.text="GOLD BAG 1 / 1  ·  Movement 80%  ·  Return to base ship" if player.carrying else ""
	if player.flag_carry>=0:
		hud_carry.text="CARRYING THE %s FLAG  ·  Bring it to your base"%team_name(player.flag_carry)
		if flags.size()==2 and flags[player.faction].state!="home": hud_carry.text+="  ·  Your flag must be home to score"
	hud_objective.text=objective_summary()
	var feed_text=""
	for item in kill_feed:
		if item.until>now:feed_text+=item.text+"\n"
	if hud_feed.text!=feed_text:hud_feed.text=feed_text
	var show_board=bool(replay_state.get("scoreboard",false)) if replay_active else (context=="scoreboard" or (context=="playing" and Input.is_action_pressed("scoreboard")))
	if scoreboard.visible!=show_board:
		scoreboard.visible=show_board
		if show_board:scoreboard.refresh(true)
	# The scoreboard owns its existing 5Hz refresh; do not bypass it at render Hz.
	# The text entry also accepts the local God command when chat display is off.
	hud_chat.visible=prefs.values.chat
	hud_chat.text="\n".join(messages)+"\n"+prefs.key_label("chat")+(" — Match chat" if network_active else " — Local chat log (offline)")
	var falling=player.alive and player.global_position.y< -3 and player.velocity.y< -5
	if player.combat_audio!=null: player.combat_audio.set_loop("fall_loop",falling)
func bar(value: float, capacity: float) -> String:
	var fill=clampi(roundi(value/capacity*18),0,18)
	return "━".repeat(fill)+"─".repeat(18-fill)
func objective_summary() -> String:
	if mode==MODE_CS:return cs_summary(player)
	if mode==MODE_CTF: return ctf_summary(player)
	if mode!=0: return arena.map_title().to_upper()+"  ·  "+("Individual eliminations" if mode==1 else "Team eliminations")
	if bomb_site<0: return "Plant bomb at A (middle) or B (bottom)" if player.is_attacker() else "Defend the gold deposits · A middle / B bottom"
	var state=site_states[bomb_site]
	var name="A" if bomb_site==0 else "B"
	match state.stage:
		"planted": return "SITE %s · BOMB  %02d s · %s"%[name,ceil(state.bomb_at-now),"Protect the bomb" if player.is_attacker() else "Defuse the bomb"]
		"off": return "SITE %s · DRILL OFF · %.0f / 45 s"%[name,state.work]
		"starting": return "SITE %s · DRILL STARTING  %.1f s"%[name,maxf(0,state.start_at-now)]
		"drilling": return "SITE %s · DRILLING  %.0f / 45 s"%[name,state.work]
		"complete": return "SITE %s · LOAD AND EXTRACT · %d / %d bags delivered"%[name,delivered_bags,tuning.bag_stock]
	return ""
func scoreboard_summary() -> String:
	var text=arena.map_title().to_upper()+"  /  "+MODE_NAMES[mode]+"  /  ROUND %d\n\n"%round_number
	for f in [0,1]:
		text+=team_name(f)+"  ·  "+str(scores[f])+" POINTS"
		if mode==0: text+="  ·  "+("ATTACKERS" if f==attacking_faction else "DEFENDERS")
		text+="\nPlayer                         Kills   Deaths   Assists   Gold   Bombs\n"
		for actor in actors:
			if actor.faction==f: text+="%s%s        %d          %d          %d          %d          %d\n"%[actor.username," [HOST]" if actor.local_player else " [BOT]",actor.kills,actor.deaths,actor.assists,actor.delivered,actor.detonations]
		text+="\n"
	return text
func _input(event: InputEvent) -> void:
	if is_instance_valid(film_viewer):
		if film_viewer.input(event):get_viewport().set_input_as_handled()
		return
	if AncientNestDiscordShortcut.is_open(): return
	if running and context=="scoreboard" and is_escape_key(event):
		if is_instance_valid(accounts.service_dialog):accounts.service_dialog.queue_free()
		scoreboard.end_inspection();get_viewport().set_input_as_handled();return
	if running and context=="playing" and is_instance_valid(scoreboard) and scoreboard.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
		scoreboard.begin_inspection();get_viewport().set_input_as_handled();return
	if NestDisplaySettings.is_fullscreen_shortcut(event):
		if display_until>0:revert_display()
		prefs.values.fullscreen=not prefs.values.fullscreen
		prefs.apply();prefs.save()
		if not draft.is_empty():draft.fullscreen=prefs.values.fullscreen
		if current_screen=="settings":show_settings()
		get_viewport().set_input_as_handled();return
	if is_instance_valid(forge_editor) and forge_editor.editing:return
	if is_instance_valid(match_setup) and match_setup.visible:
		if is_escape_key(event):match_setup.dismiss();get_viewport().set_input_as_handled()
		return
	if is_instance_valid(game_type_editor) and game_type_editor.visible:
		if is_escape_key(event):game_type_editor.dismiss_back();get_viewport().set_input_as_handled()
		return
	if binding_action!="" and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)):
		if event is InputEventKey and event.keycode==KEY_ESCAPE: binding_action=""; get_viewport().set_input_as_handled(); show_settings(); return
		if event is InputEventKey:
			var code=event.physical_keycode
			if code==KEY_I:
				binding_action="";show_settings();info("Reserved shortcut","I opens the Discord dashboard. Choose another key for this action.");get_viewport().set_input_as_handled();return
			for action in draft_keys:
				if action!=binding_action and draft_keys[action]==code:
					binding_action=""; show_settings(); info("Binding conflict",OS.get_keycode_string(code)+" is assigned to "+action+". Choose another key."); get_viewport().set_input_as_handled(); return
			draft_keys[binding_action]=code; binding_action=""; show_settings()
		get_viewport().set_input_as_handled(); return
	if current_screen=="settings" and binding_action.is_empty() and not (is_instance_valid(modal) and modal.visible):
		if event is InputEventKey and event.pressed and event.keycode==KEY_F and (event.ctrl_pressed or event.meta_pressed):
			preferences_search.grab_focus();preferences_search.select_all();get_viewport().set_input_as_handled();return
		if is_escape_key(event) and not preferences_query.is_empty():
			preferences_query="";preferences_search.text="";filter_preferences();get_viewport().set_input_as_handled();return
	if context=="chat":
		if is_escape_key(event): close_chat_ui(); get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or (context!="playing" and is_escape_key(event)):
		get_viewport().set_input_as_handled()
		if is_instance_valid(modal) and modal.visible:
			if modal.has_signal("canceled"): modal.emit_signal("canceled")
			else: modal.hide()
			return
		match current_screen:
			"playing": show_pause()
			"pause": resume_game()
			"settings": settings_back()
			"lobby": leave_custom_lobby()
			"character": show_lobby()
			"rating", "play", "armory", "player": show_main()
			"matchmaking", "server_browser":leave_matchmaking()
			"matchmaking_ranks":set_meta("rank_guide",false);show_matchmaking()
		return
	if context=="playing" and event.is_action_pressed("chat"):
		open_chat(); get_viewport().set_input_as_handled(); return
	if context=="playing" and event.is_action_pressed("connections"):
		show_pause(); show_connection_details(); get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		input_window_focused=false
		if is_instance_valid(forge_editor):forge_editor.cancel_move();forge_editor.release_mouse()
		if running and context in ["playing","chat"]:show_pause()
		else:clear_held_input()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:input_window_focused=true
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		if forge_session!=null and forge_session.dirty:forge_session.save()
		if lobby_network!=null: lobby_network.shutdown()
		get_tree().quit()
func open_chat() -> void:
	context="chat"; interaction_progress=0; cancel_uncommitted_input()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	chat_panel.visible=true; chat_entry.text=""; chat_entry.grab_focus()
func close_chat_ui() -> void:
	chat_panel.visible=false; chat_entry.release_focus(); chat_entry.text=""; close_chat()
func open_match_setup() -> void:
	open_game_type_settings()
func show_pause() -> void:
	if context=="chat": close_chat_ui()
	current_screen="pause"; context="pause"; clear_screen(); shade(0.65); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	interaction_progress=0; cancel_uncommitted_input()
	if is_instance_valid(scoreboard):scoreboard.visible=false
	var v=center_panel(minf(680,get_viewport().get_visible_rect().size.x-32),minf(660,get_viewport().get_visible_rect().size.y-32)); header(v,arena.map_title().to_upper()+" · "+("CLIENT" if is_client() else "HOST" if network_active else "OFFLINE"), "Pause Menu")
	v.add_child(label("The match continues while this menu is open.",14,MUTED))
	v.add_child(label("GOD MODE "+("ON · Trait editor unlocked" if can_edit_match_traits() else "OFF"),13,GOLD if can_edit_match_traits() else MUTED))
	var resume_button=button("Resume Game",resume_game); v.add_child(resume_button)
	v.add_child(button("Settings",func(): open_settings("pause")))
	if can_edit_match_traits():
		var traits_button=button("God Mode · Traits / Bots / Weapons",open_game_type_settings);traits_button.name="PauseGameTypeSettings";v.add_child(traits_button)
	v.add_child(button("Back to Nest Forge" if is_instance_valid(forge_editor) else "Return to Lobby",leave_dialog))
	v.add_child(button("Quit Game",quit_dialog))
	v.add_child(button("Connection Details",show_connection_details))
	v.add_child(label("Nu: %s · Grenade type: %s · Melee weapon: %s\nMove: %s / %s / %s / %s · Jump: %s · Crouch: %s\nReload: %s · Interact: %s · Melee: %s · Grenade: %s\nCycle weapons: %s / Wheel · Primary: %s · Secondary: %s · Scoreboard: %s · Chat: %s"%[prefs.key_label("nu"),prefs.key_label("grenade_type"),prefs.key_label("sword"),prefs.key_label("forward"),prefs.key_label("left"),prefs.key_label("backward"),prefs.key_label("right"),prefs.key_label("jump"),prefs.key_label("crouch"),prefs.key_label("reload"),prefs.key_label("interact"),prefs.key_label("melee"),prefs.key_label("grenade"),prefs.key_label("switch_weapon"),prefs.key_label("primary_weapon"),prefs.key_label("secondary_weapon"),prefs.key_label("scoreboard"),prefs.key_label("chat")],13,MUTED))
	focus_later(resume_button)
func resume_game() -> void:
	clear_screen(); current_screen="playing"; context="playing"; clear_held_input(); capture_mouse()
func leave_dialog() -> void:
	if matchmaking.active:
		confirm("Leave matchmaking?","A bot will hold your slot until you reconnect or the match ends.",leave_matchmaking,"Leave Match");return
	if forge_session.testing:
		if is_client():info("Nest Forge Playtest","The host returns everyone to the editor.")
		else:forge_session.return_to_editing()
		return
	confirm("Return to Lobby?","Leaving as host ends the match for all connected players." if network_active and multiplayer.is_server() else "Leave this match and return to the lobby?",func():
		stop_game();
		if is_client(): close_connection()
		hud.visible=false; menu_camera.current=true; show_lobby(),"Return to Lobby")
func quit_dialog() -> void:
	restore_focus="Quit Game"
	confirm("Quit Game?","Are you sure you want to quit?",shutdown_and_quit,"Quit Game")
func shutdown_and_quit() -> void:
	if forge_session.dirty:forge_session.save()
	if lobby_network!=null: lobby_network.shutdown()
	get_tree().quit()
func confirm(name: String, text: String, action: Callable, ok: String="Confirm") -> void:
	var origin=get_viewport().gui_get_focus_owner()
	var origin_id=origin.get_instance_id() if origin!=null else 0
	var dialog=ConfirmationDialog.new(); dialog.title=name; dialog.dialog_text=text; dialog.ok_button_text=ok; dialog.cancel_button_text="Cancel"
	canvas.add_child(dialog); modal=dialog
	dialog.confirmed.connect(func(): action.call(); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free(); call_deferred("focus_existing",origin_id))
	dialog.popup_centered(Vector2i(500,180))
func info(name: String, text: String) -> void:
	var dialog=AcceptDialog.new(); dialog.title=name; dialog.dialog_text=text; canvas.add_child(dialog); modal=dialog; dialog.confirmed.connect(dialog.queue_free); dialog.popup_centered(Vector2i(570,190))
func show_results() -> void:
	if chat_panel!=null: chat_panel.visible=false; chat_entry.release_focus(); chat_entry.text=""
	context="results"; current_screen="results"; clear_screen(); shade(0.78); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var v=center_panel(1050,700); header(v,"MATCH COMPLETE", "Results")
	var winner="Draw" if scores[0]==scores[1] else (team_name(0)+" wins" if scores[0]>scores[1] else team_name(1)+" wins")
	if mode==1:
		var sorted=actors.duplicate(); sorted.sort_custom(func(a,b): return a.kills>b.kills); winner="Draw — tied eliminations" if sorted.size()>1 and sorted[0].kills==sorted[1].kills else sorted[0].username+" wins Iso Deathmatch"
	v.add_child(title(winner,28));rating_result_label=label(ranked.result_text(),15,GOLD);rating_result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;v.add_child(rating_result_label)
	var results_table=NestScoreboard.new();results_table.name="ResultsScoreboard";results_table.game=self;results_table.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(results_table);results_table.refresh(true)
	var f=HBoxContainer.new();v.add_child(f); f.add_child(button("Return to Lobby",func(): stop_game(); hud.visible=false; menu_camera.current=true; show_lobby())); f.add_child(button("Quit Game",quit_dialog))
func open_settings(caller: String) -> void:
	settings_caller=caller; settings_tab="Controls";preferences_query=""
	draft=prefs.values.duplicate(true); draft_keys=prefs.keys.duplicate(true)
	show_settings()
func open_discord_settings(caller: String) -> void:
	open_settings(caller)
	settings_tab="Discord"
	filter_preferences()
func open_discord_dashboard() -> void:
	AncientNestDiscordShortcut.open_dashboard(self)
func show_settings() -> void:
	current_screen="settings"; context="settings"; clear_screen(); shade(0.82); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var viewport_size=get_viewport().get_visible_rect().size
	var v=center_panel(minf(1080,viewport_size.x-32),minf(790,viewport_size.y-32)); header(v,"PERSONAL PREFERENCES", "Settings")
	if viewport_size.y<650:
		v.add_theme_constant_override("separation",8);v.get_child(0).hide();v.get_child(1).add_theme_font_size_override("font_size",28)
	preferences_groups.clear();preferences_headings.clear();preferences_buttons.clear()
	preferences_search=LineEdit.new();preferences_search.name="PreferencesSearch";preferences_search.placeholder_text="Search all preferences · sensitivity, resolution, sound, radar…";preferences_search.clear_button_enabled=true;preferences_search.text=preferences_query;v.add_child(preferences_search)
	preferences_search.add_theme_color_override("font_placeholder_color",Color("3f5448"))
	preferences_search.text_changed.connect(func(value):preferences_query=value;filter_preferences())
	preferences_results=label("",12,MUTED);v.add_child(preferences_results)
	var tabs=HFlowContainer.new(); tabs.add_theme_constant_override("h_separation",12); v.add_child(tabs)
	for tab_name in ["Controls","Video","Audio","HUD","Discord"]:
		var b=button(tab_name,func(): settings_tab=tab_name;preferences_query="";preferences_search.text="";filter_preferences(),90 if viewport_size.x<800 else 130)
		if tab_name==settings_tab: b.add_theme_color_override("font_color",GOLD)
		tabs.add_child(b);preferences_buttons[tab_name]=b
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; v.add_child(scroll)
	var groups=VBoxContainer.new();groups.size_flags_horizontal=Control.SIZE_EXPAND_FILL;groups.add_theme_constant_override("separation",16);scroll.add_child(groups)
	for category in ["Controls","Video","Audio","HUD","Discord"]:
		var heading=label(category.to_upper(),16,GOLD);groups.add_child(heading);preferences_headings[category]=heading
		var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);groups.add_child(body);preferences_groups[category]=body
		build_preferences_category(body,category)
	filter_preferences()
	var f=footer(v,false)
	f.add_child(button("Back",settings_back))
	preferences_reset=button("Reset "+settings_tab+" Defaults",restore_tab);f.add_child(preferences_reset)
	var spacer=Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; f.add_child(spacer)
	f.add_child(button("Apply",apply_draft,190))
func filter_preferences() -> void:
	var dashboard_only=settings_tab=="Discord" and preferences_query.strip_edges().is_empty()
	preferences_search.visible=not dashboard_only;preferences_results.visible=not dashboard_only
	if is_instance_valid(preferences_reset):preferences_reset.text="Reset "+settings_tab+" Defaults"
	var total=0
	for category in preferences_groups:
		var group: Control=preferences_groups[category]
		var count=NestMenuSearch.filter_group(group,preferences_query,category)
		group.visible=(category==settings_tab) if preferences_query.strip_edges().is_empty() else count>0
		preferences_headings[category].visible=group.visible and not (dashboard_only and category=="Discord")
		if group.visible:total+=count
		preferences_buttons[category].add_theme_color_override("font_color",Color("5c491c") if category==settings_tab and preferences_query.is_empty() else Color("124c38"))
	preferences_results.text="Choose a category, or search across all preferences." if preferences_query.strip_edges().is_empty() else ("%d matching entries across all preferences"%total if total>0 else "No matching preferences. Try another term or clear search.")
func build_preferences_category(body: VBoxContainer, category: String) -> void:
	if category=="Discord":
		var dashboard=load("res://addons/ancient_nest/discord_dashboard.gd").new();dashboard.game=self;body.add_child(dashboard);return
	match category:
		"Controls":
			check_row(body,"Allow my PC to host online matches","allow_host")
			check_row(body,"Record films and my local perspective (29 Hz)","record_films")
			slider_row(body,"Mouse sensitivity","sensitivity",0.1,20,0.05)
			slider_row(body,"Zoom sensitivity multiplier","aim_sensitivity",0.5,1.5,0.05)
			slider_row(body,"Zoom feel tweak","zoom_feel_tweak",0.5,1.5,0.05)
			slider_row(body,"Enemy-hover sensitivity multiplier","hover_sensitivity_multiplier",0.2375,1.0,0.0025)
			slider_row(body,"Nu mouse sensitivity","nu_sensitivity",0.1,20.0,0.1)
			check_row(body,"Nu flight assist · easier steering and level cruise","nu_flight_assist")
			check_row(body,"Invert mouse Y","invert_y")
			body.add_child(label("KEYBOARD BINDINGS · Click an entry, then press a key. Esc cancels.",13,GOLD))
			var grid=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",20); body.add_child(grid)
			for action in NestPreferences.KEYS:
				var h=HBoxContainer.new(); h.custom_minimum_size.x=450; grid.add_child(h)
				var l=label("Melee weapon" if action=="sword" else action.replace("_"," ").capitalize(),15); l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(l)
				var bind=button(OS.get_keycode_string(draft_keys[action]),func(): binding_action=action; binding_button=bind_button_for(action),165)
				bind.set_meta("action",action); h.add_child(bind)
			body.add_child(label("Aim with the mouse · Fire: Left Mouse · Wheel: switch weapon\nZoom: Right Mouse or Zoom key · Battle rifle 2× · Sniper 5× / 10×.\nZoom sensitivity follows tan(FOV/2), so 2× is ~0.5 speed and 10× is ~0.1 speed at multiplier 1.00.\nEnemy-hover slowdown stacks on top and never moves the aim for you.",13,MUTED))
			check_row(body,"Enable game chat","chat")
		"Video":
			var quality=OptionButton.new();quality.name="GraphicsQuality"
			for preset in NestGraphicsQuality.LABELS:quality.add_item(preset)
			quality.select(int(draft.graphics_quality));row(body,"Graphics quality",quality)
			quality.item_selected.connect(func(index):draft.graphics_quality=index)
			body.add_child(button("Light performance preset",func():draft.graphics_quality=0;draft.shadows=false;draft.antialiasing=1;draft.render_scale=1.0;draft.vsync=false;draft.fps_limit=120;show_settings()))
			body.add_child(label("Light: Low detail, full 3D resolution, no AA/shadows, 120 FPS cap. Click Apply to keep.\nThe screen and interface stay at your chosen display size.",13,MUTED))
			body.add_child(label("Low reduces shadows, antialiasing and decorative effects.\nChoose Balanced or High for smoother edges and optional shadows.",13,MUTED))
			add_display_controls(body)
			slider_row(body,"3D render scale","render_scale",0.5,1.0,0.05)
			var aa=OptionButton.new()
			for option in ["Preset default","Off","MSAA 2×","MSAA 4×","MSAA 8×"]:aa.add_item(option)
			aa.select(draft.antialiasing);aa.item_selected.connect(func(index):draft.antialiasing=index)
			row(body,"Antialiasing",aa)
			check_row(body,"V-sync","vsync")
			check_row(body,"Shadows · Balanced / High only","shadows")
			slider_row(body,"FPS limit","fps_limit",30,240,30)
			slider_row(body,"Field of view · vertical degrees","fov",60,110,1)
			body.add_child(label("Fullscreen fills your entire display without side bars. F11 / Alt+Enter toggles fullscreen.\nFullscreen fills the desktop; resolution caps 3D rendering while the interface stays crisp.\nRender scale further lowers 3D resolution for performance. Fixed aspect applies windowed.\nDisplay changes require confirmation within 15 seconds.",14,MUTED))
		"Audio":
			for bus in prefs.audio_buses: slider_row(body,bus.slider.label+" volume",bus.slider.key,float(bus.slider.min),float(bus.slider.max),float(bus.slider.step))
			slider_row(body,"Effects volume","effects",0,1,0.05)
			body.add_child(button("Test weapon sound",func(): sound("shot",Vector3.ZERO,true),250))
			body.add_child(label("Weapon layers, grenade collisions, movement, protection and announcer audio.\nEach channel can be adjusted independently.",14,MUTED))
		"HUD":
			slider_row(body,"Interface text scale","hud_scale",0.75,1.35,0.05)
			slider_row(body,"Interface opacity","hud_opacity",0.45,1,0.05)
			check_row(body,"Crosshair visible","crosshair")
			check_row(body,"Dynamic reticle · firing bloom","dynamic_crosshair")
			slider_row(body,"Reticle size","crosshair_size",3,14,1)
			slider_row(body,"Reticle spacing","crosshair_gap",0,12,1)
			var crosshair_color=OptionButton.new()
			for name in ["Green","Cyan","White","Gold"]: crosshair_color.add_item(name)
			crosshair_color.select(draft.crosshair_color); crosshair_color.item_selected.connect(func(index): draft.crosshair_color=index)
			row(body,"Crosshair color",crosshair_color)
			check_row(body,"Radar / minimap visible","radar")
			slider_row(body,"Radar background opacity","radar_background_opacity",0,1,0.05)
			check_row(body,"Radar sweep line","radar_sweep")
			check_row(body,"Radar colorblind shapes / colors","radar_colorblind")
			var faction_tabs=HBoxContainer.new(); body.add_child(faction_tabs)
			faction_tabs.add_child(button("Naki HUD",func(): hud_faction=0; show_settings(),220))
			faction_tabs.add_child(button("Annu HUD",func(): hud_faction=1; show_settings(),220))
			var prefix="naki" if hud_faction==0 else "annu"
			slider_row(body,"Radar size · "+prefix.capitalize(),prefix+"_radar_size",130,240,10)
			var corner=OptionButton.new()
			for name in ["Bottom left","Top left","Bottom right","Top right"]: corner.add_item(name)
			corner.select(draft[prefix+"_radar_corner"]); corner.item_selected.connect(func(index): draft[prefix+"_radar_corner"]=index)
			row(body,"Radar position · "+prefix.capitalize(),corner)
			var preview_row=HBoxContainer.new(); body.add_child(preview_row)
			var preview=Control.new(); preview.set_script(load("res://scripts/radar.gd")); preview.preview=true; preview.preview_faction=hud_faction; preview.game=self; preview.custom_minimum_size=Vector2(160,160); preview_row.add_child(preview)
			var copy=label("NAKI\nSHIELD  ━━━━━━━━━━━━━━━\nNo visible health bar · Motion tracker" if hud_faction==0 else "ANNU\nHEALTH 100 · ARMOR 100\nMapped walkways · Team-spotted enemies",16,GOLD)
			copy.size_flags_vertical=Control.SIZE_SHRINK_CENTER; preview_row.add_child(copy)
			body.add_child(label("Preview faction does not change your match faction or abilities.",13,MUTED))
func bind_button_for(action: String) -> Button:
	var pending: Array[Node]=[screen]
	while not pending.is_empty():
		var node=pending.pop_front()
		if node is Button and node.get_meta("action","")==action: node.text="Press a key…"; return node
		for child in node.get_children(): pending.append(child)
	return null
func add_display_controls(body: VBoxContainer) -> void:
	var modes=OptionButton.new();modes.name="DisplayWindowMode";modes.add_item("Windowed");modes.add_item("Borderless fullscreen");modes.add_item("Exclusive fullscreen");modes.select((2 if draft.exclusive_fullscreen else 1) if draft.fullscreen else 0)
	row(body,"Window mode",modes)
	var resolutions=OptionButton.new();resolutions.name="DisplayResolution"
	var wanted=Vector2i(draft.resolution_width,draft.resolution_height);var sizes=NestDisplaySettings.RESOLUTIONS.duplicate()
	if not wanted in sizes:sizes.append(wanted)
	for size in sizes:
		resolutions.add_item("%d × %d"%[size.x,size.y]);resolutions.set_item_metadata(resolutions.item_count-1,size)
		if size==wanted:resolutions.select(resolutions.item_count-1)
	resolutions.disabled=false
	resolutions.item_selected.connect(func(index):var size=resolutions.get_item_metadata(index);draft.resolution_width=size.x;draft.resolution_height=size.y)
	row(body,"Resolution · 1920 × 1080 = Full HD",resolutions)
	var ratios=OptionButton.new();ratios.name="DisplayAspectRatio"
	for text in NestDisplaySettings.ASPECT_LABELS:ratios.add_item(text)
	ratios.select(0 if draft.fullscreen else draft.aspect_ratio);ratios.disabled=draft.fullscreen
	ratios.item_selected.connect(func(index):draft.aspect_ratio=index)
	modes.item_selected.connect(func(index):draft.fullscreen=index>0;draft.exclusive_fullscreen=index==2;resolutions.disabled=false;ratios.disabled=draft.fullscreen;ratios.select(0 if draft.fullscreen else draft.aspect_ratio))
	row(body,"Aspect ratio",ratios)
func on_display_resized() -> void:
	# Godot updates anchored HUD/crosshair layout; avoid rebuilding it mid-input.
	if DisplayServer.get_name()!="headless" and display_until==0 and not prefs.values.fullscreen:
		var actual=DisplayServer.window_get_size()
		prefs.values.resolution_width=actual.x;prefs.values.resolution_height=actual.y
		NestDisplaySettings.last_values.resolution_width=actual.x;NestDisplaySettings.last_values.resolution_height=actual.y
		if current_screen=="settings":draft.resolution_width=actual.x;draft.resolution_height=actual.y
		window_save_at=Time.get_ticks_msec()/1000.0+.5
	if is_instance_valid(game_type_editor) and game_type_editor.visible:game_type_editor.move_to_center()
	if is_instance_valid(modal) and modal.visible:modal.move_to_center()
func slider_row(parent: VBoxContainer, name: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var h=HBoxContainer.new(); h.add_theme_constant_override("separation",15); parent.add_child(h)
	var text=label(name,15); text.custom_minimum_size.x=340; h.add_child(text)
	var slider=HSlider.new(); slider.min_value=minimum; slider.max_value=maximum; slider.step=step; slider.value=draft[key]; slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(slider)
	var number=label(str(slider.value),15,GOLD); number.custom_minimum_size.x=75; h.add_child(number)
	slider.value_changed.connect(func(value): draft[key]=int(value) if NestPreferences.DEFAULTS[key] is int else value; number.text=str(snappedf(value,minf(step,0.01))))
func check_row(parent: VBoxContainer, name: String, key: String) -> void:
	var check=CheckButton.new(); check.text=name; check.button_pressed=draft[key]; parent.add_child(check); check.toggled.connect(func(on): draft[key]=on)
func restore_tab() -> void:
	if settings_tab=="Discord":AncientNestDiscordVoice.reset_voice_preferences();show_settings();return
	var keys_for_tab={"Controls":["record_films","allow_host","nu_sensitivity","nu_flight_assist","sensitivity","aim_sensitivity","zoom_feel_tweak","hover_sensitivity_multiplier","invert_y","chat"],"Video":["exclusive_fullscreen","render_scale","antialiasing","graphics_quality","fullscreen","resolution_width","resolution_height","aspect_ratio","vsync","shadows","fps_limit","fov"],"Audio":["master","effects"],"HUD":["hud_scale","hud_opacity","radar","crosshair","crosshair_color","crosshair_size","crosshair_gap","dynamic_crosshair","naki_radar_size","annu_radar_size","naki_radar_corner","annu_radar_corner","radar_background_opacity","radar_sweep","radar_colorblind"]}
	if settings_tab=="Audio":
		for bus in prefs.audio_buses:
			if not bus.slider.key in keys_for_tab.Audio:keys_for_tab.Audio.append(bus.slider.key)
	for key in keys_for_tab[settings_tab]: draft[key]=NestPreferences.DEFAULTS.get(key,1.0)
	if settings_tab=="Controls": draft_keys=NestPreferences.KEYS.duplicate(true)
	show_settings()
func settings_dirty() -> bool:
	return draft!=prefs.values or draft_keys!=prefs.keys
func settings_back() -> void:
	if display_until>0: revert_display(); return
	if settings_dirty():
		var dialog=ConfirmationDialog.new(); dialog.title="Unsaved changes"; dialog.dialog_text="Apply your changes before returning?"; dialog.ok_button_text="Apply"; dialog.cancel_button_text="Cancel"
		var discard=dialog.add_button("Discard",true,"discard")
		canvas.add_child(dialog); modal=dialog
		dialog.confirmed.connect(func(): dialog.queue_free(); apply_draft(); if display_until==0: return_from_settings())
		discard.pressed.connect(func(): dialog.queue_free(); return_from_settings())
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(520,180))
	else: return_from_settings()
func return_from_settings() -> void:
	if settings_caller=="pause" and running: show_pause()
	elif settings_caller=="lobby":show_lobby()
	elif settings_caller=="matchmaking":show_matchmaking()
	else: restore_focus="Settings"; show_main()
func apply_draft() -> void:
	if display_until>0: return
	var display_changed=NestDisplaySettings.changed(draft,prefs.values)
	if display_changed:display_until=Time.get_ticks_msec()/1000.0+15
	display_old=prefs.values.duplicate(true)
	prefs.values=draft.duplicate(true); prefs.keys=draft_keys.duplicate(true); prefs.validate(); prefs.apply()
	NestGraphicsQuality.apply_arena(arena,prefs.values)
	if running: set_hud_preferences()
	if display_changed:
		display_until=Time.get_ticks_msec()/1000.0+15
		var dialog=ConfirmationDialog.new(); dialog.title="Keep display settings?"; dialog.ok_button_text="Keep"; dialog.cancel_button_text="Revert"
		canvas.add_child(dialog); modal=dialog
		dialog.confirmed.connect(func(): display_until=0; persist_preferences(); dialog.queue_free())
		dialog.canceled.connect(revert_display)
		dialog.popup_centered(Vector2i(500,190))
	else: persist_preferences()
func persist_preferences() -> void:
	var result=prefs.save()
	if result!=OK: info("Unable to save settings","Settings are applied for this session. The preferences file could not be saved.")
	else:
		draft=prefs.values.duplicate(true); draft_keys=prefs.keys.duplicate(true)
		if current_screen=="settings": show_settings()
func revert_display() -> void:
	if display_until==0: return
	display_until=0
	for key in NestDisplaySettings.KEYS:prefs.values[key]=display_old[key];draft[key]=display_old[key]
	prefs.apply()
	if is_instance_valid(modal): modal.queue_free()
	persist_preferences()
func show_connection(hosting: bool) -> void:
	var dialog=ConfirmationDialog.new(); dialog.title="Host direct match" if hosting else "Join direct match"; dialog.ok_button_text="Host" if hosting else "Connect"; dialog.cancel_button_text="Cancel";dialog.dialog_hide_on_ok=false
	var form=VBoxContainer.new(); form.custom_minimum_size=Vector2(570,300); dialog.add_child(form)
	form.add_child(label("No account needed · Direct ENet / UDP connection",15,GOLD))
	var alias=LineEdit.new(); alias.placeholder_text="Your display name"; alias.name="ConnectionUsername";alias.text=current_username(); alias.max_length=20; row(form,"Username",alias)
	var address=LineEdit.new(); address.placeholder_text="192.168.1.20:7777 or ancientnest://…"; address.text=connection_address if connection_address!="" else "127.0.0.1"
	if not hosting: row(form,"IP / hostname / join address",address)
	var port=SpinBox.new(); port.min_value=1; port.max_value=65535; port.value=connection_port; row(form,"UDP port",port)
	form.add_child(label("LAN: use the host's local IP.\nInternet: use its public IP and forward the selected UDP port.\nJoin addresses are pasted here; no relay or account service.",13,MUTED))
	canvas.add_child(dialog); modal=dialog
	var name_error=label("",13,Color("ffb2a7"));name_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(name_error)
	dialog.confirmed.connect(func():
		if dialog.is_queued_for_deletion():return
		if NestPreferences.normalize_username(alias.text).is_empty():name_error.text="Enter a username before connecting.";return
		var saved=save_username(alias.text)
		if saved!=OK:name_error.text="Couldn't save your username. Check available storage and try again.";return
		var err: Error
		var faction=lobby_faction.selected if is_instance_valid(lobby_faction) else selected_faction
		if hosting:
			err=host_direct(int(port.value),current_username(),faction)
		else:
			var parsed=parse_join_address(address.text,int(port.value))
			err=join_direct(parsed.address,parsed.port,current_username(),faction)
		dialog.queue_free(); show_lobby()
		if err!=OK: info("Connection could not start",network_status)
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(620,370))
func parse_join_address(text: String, default_port: int=7777) -> Dictionary:
	text=text.strip_edges().trim_prefix("ancientnest://").trim_suffix("/")
	var address=text
	var port=default_port
	if text.begins_with("[") and text.contains("]"):
		address=text.get_slice("]",0).trim_prefix("[")
		var tail=text.get_slice("]",1).trim_prefix(":")
		if tail.is_valid_int(): port=int(tail)
	elif text.count(":")==1:
		address=text.get_slice(":",0)
		if text.get_slice(":",1).is_valid_int(): port=int(text.get_slice(":",1))
	return {"address":address,"port":clampi(port,1,65535)}
func local_host_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."): return address
	return "127.0.0.1"
func copy_join_address() -> void:
	var address=local_host_address() if multiplayer.is_server() else connection_address
	DisplayServer.clipboard_set("ancientnest://%s:%d"%[address,connection_port])
	info("Join address copied","Paste this into another player's Join screen:\nancientnest://%s:%d\n\nUse your public IP instead for internet connections."%[address,connection_port])
func show_connection_details() -> void:
	if matchmaking.active:
		info("Matchmaking Connection","Server: %s:%d\n%s\nPlayer-hosted matches · choose 1v1 through 5v5\nBots only substitute for disconnected players."%[matchmaking.endpoint,matchmaking.port,matchmaking.phase.capitalize()]);return
	if not network_active: info("Connection","Offline session. Host or Join from Custom Lobby."); return
	info("Direct Connection",network_status+"\nUDP port: "+str(connection_port)+"\nPlayers: "+str(lobby_members.size())+"\nNo account or shared service is used.")
func broadcast_lobby() -> void:
	if matchmaking.active:return
	if network_active and multiplayer.is_server():
		if lobby_kind=="forge":update_lobby.rpc(lobby_members,active_config());return
		team_size=maxi(team_size,ceili(float(lobby_members.size())/2))
		var counts=[0,0]
		var ids=lobby_members.keys(); ids.sort()
		for id in ids:
			var member=lobby_members[id]
			if counts[member.faction]>=team_size: member.faction=1-member.faction
			counts[member.faction]+=1
		update_lobby.rpc(lobby_members,active_config())
func network_ui_changed() -> void:
	if matchmaking!=null and matchmaking.active:matchmaking_ui_changed();return
	if forge_session.active or forge_session.testing:return
	if not running: hud.visible=false; menu_camera.current=true; show_lobby()
func network_match_started() -> void:
	if matchmaking.dedicated:return
	if is_instance_valid(forge_editor):forge_editor.close_ui()
	close_username_dialog()
	clear_screen(); current_screen="playing"; context="playing"; results_shown=false; create_hud(); hud.visible=true
	# Frozen matchmaking UI can select the overhead camera after actors spawn.
	# Reclaim the local view on resume as well as on the initial actor creation.
	if is_instance_valid(player) and is_instance_valid(player.camera):player.camera.make_current()
func show_character(faction: int) -> void:
	current_screen="character"; context="menu"; clear_screen(); shade(0.86)
	var v=center_panel(1140,760)
	header(v,"STANDARD APPEARANCE", "Naki · Anki" if faction==0 else "Annu · Aven")
	var h=HBoxContainer.new(); h.add_theme_constant_override("separation",20); h.size_flags_vertical=Control.SIZE_EXPAND_FILL; v.add_child(h)
	var art=TextureRect.new(); art.texture=load("res://assets/characters/"+("naki" if faction==0 else "annu")+"_reference.png"); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.custom_minimum_size=Vector2(580,400); art.size_flags_vertical=Control.SIZE_EXPAND_FILL; h.add_child(art)
	var viewport_container=SubViewportContainer.new(); viewport_container.custom_minimum_size=Vector2(460,400); viewport_container.size_flags_vertical=Control.SIZE_EXPAND_FILL; viewport_container.stretch=true; h.add_child(viewport_container)
	var viewport=SubViewport.new(); viewport.size=Vector2i(460,480); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport_container.add_child(viewport)
	var stage=Node3D.new(); viewport.add_child(stage)
	var environment=WorldEnvironment.new(); var env=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("233137"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("dfddd2"); env.ambient_light_energy=0.32; environment.environment=env; stage.add_child(environment)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-35,150,0); light.light_energy=1.0; light.light_color=Color("fff1dd"); stage.add_child(light)
	var fill=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-20,-40,0); fill.light_energy=.65; fill.light_color=Color("b8d5e3"); stage.add_child(fill)
	var hero=load("res://models/"+("Naki" if faction==0 else "Annu")+".glb").instantiate(); stage.add_child(hero);NestReferenceGear.apply_trim(hero,faction)
	var plinth=CSGCylinder3D.new(); plinth.radius=.58; plinth.height=.055; plinth.sides=64; plinth.position.y=-.03; plinth.material=arena.kit.dark; stage.add_child(plinth)
	var camera=Camera3D.new(); stage.add_child(camera); camera.position=Vector3(.45,1.16,-3.25); camera.look_at(Vector3(0,.98,0)); camera.fov=37
	var animators=hero.find_children("*","AnimationPlayer",true,false)
	if not animators.is_empty():
		for name in animators[0].get_animation_list():
			if String(name).ends_with("idle"): animators[0].get_animation(name).loop_mode=Animation.LOOP_LINEAR; animators[0].play(name); break
	v.add_child(label("Reference artwork (left) · Animated in-game model (right)",13,MUTED))
	var f=footer(v,false); f.add_child(button("Back",show_lobby)); f.add_child(button("Front",func(): hero.rotation.y=0)); f.add_child(button("Back view",func(): hero.rotation.y=PI))
	f.add_child(label("Standard cosmetic · Equal gameplay bounds",13,GOLD))
func stop_game() -> void:
	if fall_audio!=null: fall_audio.stop()
	super.stop_game()
func close_chat() -> void:
	if chat_panel!=null:
		chat_panel.visible=false; chat_entry.release_focus(); chat_entry.text=""
	clear_held_input()
	super.close_chat()
func cancel_uncommitted_input() -> void:
	clear_held_input()
	if player==null: return
	player.cancel_scope()
	player.burst_left=0
	if player.action_state in ["melee","throwing"]: player.action_state="ready"; player.action_until=now
	if is_client(): request_remote_action("cancel_uncommitted",command_sequence)
func focus_later(control: Control) -> void:
	call_deferred("focus_existing",control.get_instance_id())
func focus_existing(instance_id: int) -> void:
	if context=="playing":return
	var control=instance_from_id(instance_id)
	if is_instance_valid(control) and control is Control and control.is_inside_tree() and control.focus_mode!=Control.FOCUS_NONE: control.grab_focus()
func is_escape_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE)

func update_menu_music(delta: float) -> void:
	var allowed=not running and current_screen in ["main","lobby"]
	if menu_music==null:
		menu_music=AudioStreamPlayer.new();menu_music.bus="Music";menu_music.stream=load("res://audio/music/menu_theme.ogg");menu_music.stream.loop=true;add_child(menu_music)
	if not allowed:
		menu_music.stop();menu_music_fade=0;return
	if not menu_music.playing:menu_music.play()
	menu_music_fade=move_toward(menu_music_fade,1,delta*.8)
	menu_music.volume_db=-8+linear_to_db(maxf(.001,menu_music_fade))

func show_username_dialog() -> void:
	if running:return
	if accounts != null and accounts.linked():accounts.show_panel();return
	if is_instance_valid(modal) and modal.visible:modal.grab_focus();return
	get_tree().root.gui_embed_subwindows=true
	var dialog=ConfirmationDialog.new();dialog.name="UsernameDialog";dialog.theme=screen.get_parent().theme;dialog.title="Choose Your Username";dialog.ok_button_text="Save Username";dialog.cancel_button_text="Cancel";dialog.dialog_hide_on_ok=false
	var form=VBoxContainer.new();form.add_theme_constant_override("separation",12);form.custom_minimum_size.x=420;dialog.add_child(form)
	var help=label("Your username is saved on this computer.\nNo account needed.",14);form.add_child(help)
	var entry=LineEdit.new();entry.name="UsernameInput";entry.placeholder_text="Choose a username";entry.max_length=20;entry.text=current_username();form.add_child(entry)
	var hint=label("Up to 20 characters.\nNames already in use get a number in that lobby.",12,MUTED);form.add_child(hint)
	var error=label("",13,Color("ffb2a7"));error.name="UsernameError";error.custom_minimum_size.x=420;error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(error)
	canvas.add_child(dialog);modal=dialog
	var commit=func():
		if dialog.is_queued_for_deletion():return
		if NestPreferences.normalize_username(entry.text).is_empty():error.text="Enter a username.";entry.grab_focus();return
		var result=save_username(entry.text)
		if result!=OK:error.text="Couldn't save your username. Check available storage and try again.";return
		dialog.queue_free()
		if current_screen=="lobby":call_deferred("show_lobby")
		elif current_screen=="main":call_deferred("show_main")
	dialog.confirmed.connect(commit);entry.text_submitted.connect(func(_text):commit.call());dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540,300));entry.grab_focus();entry.select_all()

func close_username_dialog() -> void:
	if is_instance_valid(modal) and modal.name=="UsernameDialog":
		modal.hide();modal.queue_free();modal=null

func round_restarted_ui() -> void:
	if is_instance_valid(match_setup):match_setup.hide();match_setup.queue_free();match_setup=null
	if is_instance_valid(game_type_editor):game_type_editor.hide();game_type_editor.queue_free();game_type_editor=null
	if is_instance_valid(modal):modal.hide();modal.queue_free();modal=null
	clear_screen();current_screen="playing";context="playing";results_shown=false
	create_hud();hud.visible=true;menu_camera.current=false
	if is_instance_valid(player) and player.camera!=null:player.camera.current=true
	clear_held_input();capture_mouse()

func open_matchmaking() -> void:
	if running:return
	if network_active and not film_retaining_transport:lobby_network.leave_lobby()
	matchmaking.active=true;matchmaking.phase="idle";matchmaking.open_party();show_matchmaking()
func open_server_browser() -> void:
	if running:return
	if network_active and not film_retaining_transport:lobby_network.leave_lobby()
	matchmaking.browser_mode=true;matchmaking.browser_lobbies.clear();matchmaking.browser_loaded=false;matchmaking.browser_refresh_at=0
	if not matchmaking.active:
		matchmaking.active=true;matchmaking.phase="idle";matchmaking.open_party()
	show_server_browser()
func show_server_browser() -> void:
	load("res://scripts/server_browser.gd").show(self)
func show_matchmaking() -> void:
	NestMatchmakingScreen.show(self)
func matchmaking_ui_changed() -> void:
	if replay_active:return
	if matchmaking.dedicated:return
	if current_screen=="settings":return
	if matchmaking.browser_mode and not running and matchmaking.phase in ["idle","party","connecting","error"]:
		show_server_browser();return
	if matchmaking.active and (not running or matchmaking.blocks_simulation()):show_matchmaking()
func leave_matchmaking() -> void:
	matchmaking.leave();hud.visible=false;show_main()

func select_normal_preset(mode_id: int,map_id: int,life: int=1,reset_vote: bool=true) -> void:
	if is_client() or running:return
	var rules=NestMatchPresets.create(mode_id,map_id,life)
	if training_session:
		rules.bots_fill_empty_slots=true;rules.max_players_per_team=2;rules.max_players=4;rules.game_type_name="Practice · "+rules.game_type_name
	fair_playing_field=false;selected_character=-1
	for member in lobby_members.values():member["character"]=-1
	if reset_vote and is_instance_valid(lobby_vote):lobby_vote.reset()
	apply_game_type_settings(rules)
func god_access_changed() -> void:
	if is_instance_valid(game_type_editor):game_type_editor.hide();game_type_editor.queue_free();game_type_editor=null
	if current_screen=="pause":show_pause()
	elif current_screen=="lobby":show_lobby()

func _exit_tree() -> void:
	if is_instance_valid(menu_music):
		menu_music.stop()
		menu_music.stream=null
	menu_music=null
