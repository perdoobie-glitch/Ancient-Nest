extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func freeze():
 game.set_physics_process(false);game.set_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();freeze()
 game.scores.assign([7,4]);game.round_number=3;game.player.kills=5;game.player.deaths=2
 check(is_equal_approx(game.tuning.ground_speed,5.94) and is_equal_approx(game.tuning.crouch_speed,2.97) and is_equal_approx(game.tuning.ground_acceleration,45),"Standing/crouch speeds decrease ten percent with acceleration unchanged")
 var old_session=game.match_session;var old_life=game.player.life_id
 game.create_hud();game.show_pause();check(game.find_child("RestartRound",true,false)!=null,"Host pause menu includes Restart Round")
 game.open_game_type_settings();await process_frame
 var editor=game.game_type_editor
 check(not editor.controls.mode.disabled and not editor.controls.matchup.disabled and editor.controls.max_players_per_team.editable,"All host settings including mode, faction and roster are editable mid-match")
 editor.set_draft_value("mode",4);editor.set_draft_value("matchup",3);editor.set_draft_value("max_players_per_team",2);editor.set_draft_value("gravity_percent",75);editor.set_draft_value("starting_primary","sniper_rifle");editor.set_draft_value("shields_enabled",false)
 editor.set_draft_value("health_type",2);editor.set_draft_value("bots_fill_empty_slots",true);editor.apply_changes();await process_frame
 check(game.pending_game_type!=null and game.pending_game_type.mode==4,"Save queues pending mode and traits")
 check(game.mode==2 and game.game_type.gravity_percent==100,"Saving pending rules leaves active mode and current life unchanged")
 check(game.player.traits.gravity_percent==100,"Current player life retains old trait object")
 game.player.respawn();freeze()
 check(game.player.traits.gravity_percent==75 and not game.player.traits.shields_enabled and game.player.weapons[0].kind=="sniper","Respawn installs queued gravity, shields and loadout")
 game._process(.016);check(game.protection_bars.size()==2 and game.hud_health_model=="annu","Respawn rebuilds HUD for newly selected health system before reading armor bars")
 check(game.mode==2 and game.actors.size()==1,"Respawn alone does not rebuild match mode or roster")
 check(game.restart_round_in_match(),"Host restarts round without returning to lobby")
 freeze();check(game.running and not game.finished and game.context=="playing","Restart keeps match running and resumes gameplay")
 check(game.match_session!=old_session and game.round_number==3 and game.scores==[7,4],"Restart rotates network session while preserving round number and score")
 check(game.player.kills==5 and game.player.deaths==2,"Restart preserves player scoreboard totals")
 check(game.pending_game_type==null and game.mode==4 and game.matchup==3 and game.team_size==2,"Restart commits pending mode, matchup and roster")
 check(game.actors.size()==4 and game.team_characters==[1,0],"Round rebuild applies new bot count and reverse matchup")
 check(game.actors.all(func(a):return a.alive and a.traits.gravity_percent==75),"All rebuilt actors get a fresh life with pending traits")
 check(is_equal_approx(game.deadline-game.now,120) and game.bomb_site<0 and game.cs_carrier!=0,"Restart resets objective state and starts new bomb clock")
 var epoch=game.match_session;check(game.restart_round_in_match() and game.match_session!=epoch,"Restart without further edits also works")
 freeze();var baseline=game.game_type.duplicate_settings();baseline.mode=2;baseline.gravity_percent=100;baseline.shields_enabled=true;baseline.bots_fill_empty_slots=false;baseline.starting_primary="rifle"
 game.apply_game_type_settings(baseline);game.restart_round_in_match();freeze();var p=game.player
 # Actual support geometry far from map. One corner of the foot footprint is enough.
 var block=StaticBody3D.new();var c=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,1,2);c.shape=box;block.add_child(c);game.add_child(block);block.global_position=Vector3(200,99.5,200);await physics_frame
 p.global_position=Vector3(201.27,100.02,201.27);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.reset_physics_interpolation();await physics_frame
 check(not p.is_on_floor() and p.can_jump_from_support(),"Partial diagonal corner support is jumpable without full capsule grounding")
 var y=p.global_position.y;check(p.movement_step(Vector2.ZERO,true,0,0,1.0/60) and p.controlled.y>0 and p.global_position.y>y,"Corner press produces real upward collision movement")
 check(not p.can_jump_from_support(),"Rising player cannot use nearby corner for a second air jump")
 p.global_position=Vector3(202,100.02,202);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO
 check(not p.can_jump_from_support(),"Ground outside the foot footprint does not create air jumps")
 p.global_position=Vector3(201.27,102.0,201.27)
 check(not p.can_jump_from_support(),"Ground far below player is rejected")
 p.global_position=Vector3(201.27,99.0,201.27)
 check(not p.can_jump_from_support(),"Vertical object side cannot act as floor support")
 p.global_position=Vector3(201.27,100.02,201.27);p.external=Vector3.UP*3
 check(not p.can_jump_from_support(),"Upward explosion momentum blocks corner double jumps")
 # Server commands exercise the same support consumer and consume once.
 p.external=Vector3.ZERO;p.controlled=Vector3.ZERO;p.global_position=Vector3(201.27,100.02,201.27);p.server_jump_buffer=0
 p.apply_remote_command({"seq":10,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"crouch":0,"interact":false,"jump":true},1.0/60)
 check(p.controlled.y>0 and p.server_jump_buffer==0,"Server consumes one corner jump from a sequenced input command")
 var before=p.controlled.y;p.apply_remote_command({"seq":11,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"crouch":0,"interact":false,"jump":false},1.0/60)
 check(p.controlled.y<before,"Following command does not duplicate the corner jump")
 p.global_position=Vector3(201.27,100.02,201.27);p.controlled=Vector3.ZERO;p.external=Vector3.ZERO
 check(p.movement_step(Vector2.ZERO,true,0,0,1.0/60,true),"Prediction replay uses the same corner support rule")
 # Actual map support and solid wall queries.
 var ramp=game.arena.up_routes.filter(func(v):return String(v.name).begins_with("J1"))
 check(ramp.size()==1 and String(ramp[0].name).contains("RAMP"),"Box stair route is replaced by a named continuous central ramp")
 for fraction in [.1,.5,.9]:
  var pt=Vector3(0,0,-18.7).lerp(Vector3(0,7,-6.6),fraction)*NestArena.MAP_SCALE
  var hit=game.trace(pt+Vector3.UP,pt-Vector3.UP,1)
  check(not hit.is_empty() and hit.normal.y>cos(deg_to_rad(45)),"Central ramp provides walkable support at "+str(fraction))
 var wall=game.arena.get_node_or_null("EastRampOuterWall");check(wall!=null,"Requested exterior ramp wall exists")
 for fraction in [.1,.5,.9]:
  var pt=Vector3(47,9,-6).lerp(Vector3(47,14,6),fraction)+Vector3.UP*1.4
  var hit=game.trace(pt*.85,(pt+Vector3.RIGHT*4)*.85,1)
  check(not hit.is_empty() and hit.normal.x<-.5,"Outer wall has solid cover at ramp fraction "+str(fraction))
 check(game.arena.get_node_or_null("TopFloorCoverDetails")!=null,"Top floor includes requested cover and jumping detail")
 # Observer flashes are larger and remain visible at 100 ms; local flash duration stays short.
 var art=p.weapon_art;p.update_weapon_art();art=p.weapon_art
 NestGunFeedback.update(art,p,.10,false);var f=art.get_meta("gun_feedback")
 check(f.flash.visible and f.flash.scale.x>1.0,"Observer muzzle flash remains large and visible 100 ms after shot")
 p.flash_render_pending=false;NestGunFeedback.update(art,p,.10,true);check(not f.flash.visible,"Own 100 ms flash remains off")
 NestGunFeedback.update(art,p,.13,false);check(not f.flash.visible,"Observer flash still expires promptly")
 game.stop_game();game.queue_free();await process_frame
 print("ROUND UPDATE: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
