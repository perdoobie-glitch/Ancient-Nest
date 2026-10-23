extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v24/screenshots/"+name+".png")==OK,"Rendered "+name)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.current_screen="playing";game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false)
 var enemy=game.actors.filter(func(a):return not a.local_player)[0];enemy.username="Enemy [gold]"
 game.scoreboard.refresh(true)
 var banners=game.scoreboard.content.get_children().filter(func(c):return c.name.begins_with("TeamBanner"))
 check(banners.size()==2,"Two full-width team color banners")
 check(game.scoreboard.team_color(0)==Color("7da680") and game.scoreboard.team_color(1)==Color("b73535"),"Naki green and Annu red match HUD")
 var rows=game.scoreboard.content.get_children().filter(func(c):return c.has_meta("actor"))
 check(rows.size()==game.actors.size(),"Every actor retains one stat row")
 for row in rows:
  var actor=row.get_meta("actor");check(row.get_theme_stylebox("panel").border_color==game.scoreboard.team_color(actor.faction),"Row accent follows actor's team")
 check(rows[0].get_child(0).get_child_count()==7,"Stats remain in seven distinct columns in team deathmatch")
 game.team_characters.assign([1,0]);game.scoreboard.refresh()
 check(game.scoreboard.team_color(0)==Color("b73535") and game.scoreboard.team_color(1)==Color("7da680"),"Team colors follow swapped character sides")
 game.team_characters.assign([0,1]);game.scoreboard.refresh();Input.action_press("scoreboard");await capture("V24_Team_Scoreboard");Input.action_release("scoreboard")
 enemy.die(game.player,"battle rifle");game._process(0)
 check(game.hud_kill_notice.visible and game.hud_kill_name.text==enemy.username,"Confirmed local kill immediately shows exact victim name")
 check(game.hud_kill_name.get_theme_color("font_color")==Color.WHITE,"Victim username is white text")
 check(game.hud_kill_name.get_parent().get_theme_stylebox("panel").bg_color==Color("9e272d"),"Victim username has red highlight")
 check(game.hud_kill_notice.anchor_right==1 and game.hud_kill_notice.offset_top==35,"Notice is anchored in top-right corner")
 check(game.hud_feed.offset_top>=game.hud_kill_notice.offset_bottom,"Existing kill feed stays below personal notice")
 check(game.hud_kill_notice.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.hud_kill_name.mouse_filter==Control.MOUSE_FILTER_IGNORE,"New notice does not capture gameplay input")
 check(game.hud_kill_name.clip_text and game.hud_kill_name.text.contains("[gold]"),"Long names clip and markup remains plain text")
 await capture("V24_You_Killed")
 var expires=game.local_kill_notice_until;game.now+=.1;game.receive_kill_notice(enemy.username,enemy.net_id,enemy.life_id,game.match_session,game.round_number)
 check(game.local_kill_notice_until==expires,"Duplicate confirmation cannot retrigger or extend notice")
 game.receive_kill_notice("stale",999,1,game.match_session-1,game.round_number);check(game.local_kill_notice==enemy.username,"Wrong-session notice ignored")
 game.receive_kill_notice("stale",999,1,game.match_session,game.round_number-1);check(game.local_kill_notice==enemy.username,"Wrong-round notice ignored")
 game.now=expires+.1;game._process(0);check(not game.hud_kill_notice.visible,"Personal kill notice expires")
 enemy.respawn();enemy.global_position=Vector3(100,100,100);enemy.username="Crimson Sentinel";game.player.die(enemy,"sniper");game._process(0)
 check(game.hud_death.text=="KILLED BY\nCrimson Sentinel","Death displays large killer name")
 check(game.hud_death_backing.visible and game.hud_death_backing.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Death backdrop improves readability without consuming input")
 check(game.hud_death.get_theme_font_size("font_size")==40,"Death headline uses large type")
 check(game.hud_death_status.text.begins_with("Respawn in"),"Respawn information remains separate and readable")
 check(game.hud_recap_panel.visible and game.hud_death_recap.text.contains("You took:"),"Damage recap retained in compact top-right panel")
 await capture("V24_Killed_By")
 game.break_until=game.now+3;game._process(0);check(game.hud_death.text.contains("Crimson Sentinel") and game.hud_death_status.text.begins_with("Next round"),"Round break retains killer while showing next round countdown")
 game.break_until=0;game.player.respawn();game._process(0);check(game.hud_death.text.is_empty(),"Respawn clears death headline")
 game.player.die(null,"fell off the map");game._process(0);check(game.hud_death.text=="YOU WERE ELIMINATED" and not game.hud_death.text.contains("Sentinel"),"Environment death cannot show stale killer")
 game.reset_round();game._process(0);check(game.local_kill_notice.is_empty() and not game.hud_kill_notice.visible,"Round restart clears personal notices")
 game.stop_game();game.queue_free();await frames();print("COMBAT HUD: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
