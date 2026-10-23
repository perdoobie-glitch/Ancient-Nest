extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=4):
 for i in range(n):await process_frame
func capture(name):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")==OK,"Rendered "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.lobby_network.set_process(false);game.lobby_network=null
 var forge=game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Nest Forge")[0];forge.pressed.emit();await frames()
 check(game.current_screen=="lobby" and game.lobby_kind=="forge","Main-menu Nest Forge opens the Nest Forge lobby")
 game.lobby_members={1:{"name":"Nest Forge Host","faction":0,"rating":{"human":900,"practice":1200}},2:{"name":"Map Builder","faction":1,"rating":{"human":2250,"practice":1500}}};game.refresh_lobby_network_ui();await frames()
 var players=game.screen.find_child("PlayersPanel",true,false);var settings=game.screen.find_child("LobbySettingsPanel",true,false)
 check(players.get_global_rect().position.x>=settings.get_global_rect().end.x,"Settings are left of ranked roster")
 check(players.get_global_rect().end.x<=root.get_visible_rect().size.x,"Roster fits screen")
 check(game.screen.find_child("MatchupPreview",true,false)==null,"Center character preview is removed")
 var names=game.screen.find_children("TeamHighlightedName","Label",true,false)
 check(names.size()==2 and names[0].get_theme_stylebox("normal").bg_color!=names[1].get_theme_stylebox("normal").bg_color,"Player names use distinct selected-team highlights")
 check(game.screen.find_children("LobbyRankBadge","HBoxContainer",true,false).size()==2,"Every roster player shows a rank medal")
 await capture("V34_Nest_Forge_Lobby")
 game.screen.find_child("StartGame",true,false).pressed.emit();await frames();var f=game.forge_editor
 check(f.editing and game.forge_session.active,"Nest Forge lobby Start opens shared editor")
 check(f.panel.get_global_rect().end.y<=root.get_visible_rect().size.y and f.toolbar.get_global_rect().end.x<=root.get_visible_rect().size.x,"Editor panel and toolbar fit viewport")
 f.ui.find_child("ForgeSpawnStructure",true,false).pressed.emit();await frames()
 var key=f.selected_key;var t=game.forge_session.model.pose(f.selected);t.p=[25,11.9,6];game.forge_session.submit("transform",{"key":key,"transform":t});f.frame_selection()
 var tabs=f.ui.find_child("ForgeInspectorTabs",true,false);tabs.current_tab=1;await frames()
 check(f.toolbar.get_global_rect().position.x>=f.panel.get_global_rect().end.x,"Toolbar does not overlap the inspector sidebar")
 check(f.position_fields.all(func(n):return n.get_global_rect().end.x<=f.panel.get_global_rect().end.x),"XYZ inspector fields fit inside editor sidebar")
 f.size_fields[0].value=6;f.size_fields[1].value=4;f.size_fields[2].value=.6;var before_pose=game.forge_session.model.pose(f.selected);f.ui.find_child("ForgeApplySize",true,false).pressed.emit();await frames()
 check(f.selected.global_position.is_equal_approx(NestForgeMap.v3(before_pose.p)),"Editing size preserves untouched precise position")
 check(game.forge_session.model.dimensions(key).is_equal_approx(Vector3(6,4,.6)),"Size controls apply exact independent dimensions")
 f.material_picker.select(NestForgeMap.MATERIALS.find("gold"));f.ui.find_child("ForgeApplyMaterial",true,false).pressed.emit();await frames()
 check(game.forge_session.model.records[key].material=="gold","Material selector applies installed gold skin")
 await capture("V34_Nest_Forge_Object_Inspector")
 f.spawn_item({"type":"light","kind":"point"});await frames();f.light_color.color=Color(.2,.5,1);f.light_energy.value=2;f.light_range.value=12;f.apply_light();await frames()
 check(f.selected is OmniLight3D and f.selected.light_color.is_equal_approx(Color(.2,.5,1)),"Light inspector edits real color and energy")
 # A text-field focus must not prevent world RMB fly controls.
 f.position_fields[0].get_line_edit().grab_focus();var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true;f._unhandled_input(click)
 var rotation=f.camera.rotation;var motion=InputEventMouseMotion.new();motion.screen_relative=Vector2(20,-10);f._input(motion)
 check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not f.camera.rotation.is_equal_approx(rotation),"RMB fly/look works after editing a numeric field")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Focus loss releases captured Nest Forge mouse")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 f.mode_picker.select(4);f.mode_picker.item_selected.emit(4);tabs.current_tab=2;f.select_key("point:4:bomb:0:0");await frames()
 check(game.forge_session.model.markers[f.selected_key].visible,"Mode selector reveals editable CS bomb site marker")
 game.forge_session.submit("transform",{"key":f.selected_key,"position":[13,6,0]});f.frame_selection();await capture("V34_Nest_Forge_Objectives")
 check(f.save_layout(),"Save Layout UI persists expanded Nest Forge format")
 var rules=game.game_type.duplicate_settings();rules.mode=4;rules.bots_fill_empty_slots=false;rules.time_limit_seconds=120;game.apply_game_type_settings(rules)
 f.start_test();await frames()
 check(game.running and game.forge_session.testing and not f.editing,"Nest Forge Playtest starts gameplay with current mode")
 check(game.mode==4 and game.arena.sites[0].is_equal_approx(Vector3(13,6,0)),"Playtest uses actual edited CS objective position")
 check(game.hud.visible and not game.ranked.eligible,"Nest Forge playtest has normal HUD and remains unrated")
 await capture("V34_Nest_Forge_Playtest")
 game.show_pause();await frames();var back=game.screen.find_children("*","Button",true,false).filter(func(b):return b.text=="Back to Nest Forge")[0];back.pressed.emit();await frames()
 check(not game.running and game.forge_editor.editing,"Pause Back to Nest Forge restores editor")
 game.forge_session.stop_editing();await frames();check(game.current_screen=="lobby" and game.lobby_kind=="forge","Editor returns to Nest Forge lobby with layout retained")
 game.open_custom_lobby();await frames();await capture("V26_Custom_Lobby")
 check(game.lobby_kind=="custom" and game.forge_session.model.records.has(key),"Same edited layout is usable in Custom Games")
 game.close_connection();game.queue_free();await frames();print("NEST FORGE V26 VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
