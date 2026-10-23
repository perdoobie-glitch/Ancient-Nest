extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func frames(n=4):
 for i in range(n):await process_frame
func capture(name):
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v20_balance/screenshots/"+name+".png")==OK,"Rendered "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.open_game_type_settings();await frames();var editor=game.game_type_editor
 editor.jump_to_category("Weapon Damage");await frames()
 check(editor.tabs.get_tab_title(editor.tabs.current_tab)=="Weapon Damage" and editor.weapon_controls.size()==12,"All guns and grenades have controls in Weapon Damage tab")
 await capture("Weapon_Damage_Tab")
 editor.weapon_controls.ak47.get_line_edit().grab_focus();editor.weapon_controls.ak47.get_line_edit().text="175";editor.open_save_prompt();await frames()
 check(editor.draft.weapon_damage_scale("ak47")==1.75,"Typed weapon value commits before saving new game type")
 editor.name_dialog.hide();editor.jump_to_category("Annu Health");editor.set_draft_value("annu_body_health",150);editor.set_draft_value("annu_head_health",200);editor.set_draft_value("annu_body_armor",200);editor.set_draft_value("annu_head_armor",60);editor.sync_draft_controls();await frames()
 check(editor.controls.annu_head_health.is_visible_in_tree() and editor.controls.annu_head_armor.is_visible_in_tree(),"Head/body health and armour controls are shown separately")
 await capture("Annu_Health_Tab")
 editor.jump_to_category("Naki Shields");await frames()
 check(editor.controls.naki_body_shield_strength.is_visible_in_tree() and editor.controls.naki_head_shield_strength.is_visible_in_tree(),"Both Naki regional strength controls are visible")
 await capture("Naki_Shields_Tab")
 editor.trait_scope=String(NestCharacterCatalog.all()[0].id);editor.sync_draft_controls();editor.jump_to_category("Weapon Damage");await frames()
 check(editor.trait_scope.is_empty() and editor.tabs.get_tab_title(editor.tabs.current_tab)=="Weapon Damage","Jump-to-tab safely selects shared rules from character scope")
 editor.apply_changes();await frames();check(game.game_type.weapon_damage_scale("ak47")==1.75 and game.game_type.annu_body_health==150,"Apply commits edited weapon and faction values")
 game.mode=1;game.bot_fill=false;game.start_game();game.create_hud();game.show_pause();game.open_game_type_settings();await frames();editor=game.game_type_editor
 editor.jump_to_category("Naki Shields");editor.set_draft_value("naki_body_shield_strength",2.5);editor.apply_changes();await frames()
 check(game.pending_game_type!=null and is_equal_approx(game.pending_game_type.naki_body_shield_strength,2.5),"In-match tab edits stage pending values")
 await capture("Pending_Balance_In_Pause")
 game.restart_round_in_match();await frames();check(is_equal_approx(game.game_type.naki_body_shield_strength,2.5),"Pause round restart commits the new shield rule")
 game.stop_game();game.queue_free();await frames();print("BALANCE VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
