extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: ",message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 check(not game.god_mode and not game.can_edit_match_traits(),"God mode defaults off")
 game.open_game_type_settings();await frames();check(not is_instance_valid(game.game_type_editor),"Direct editor entry is locked")
 game.show_lobby();await frames();check(game.screen.find_child("EditGameTypeSettings",true,false)==null,"Trait/bot menu is absent from normal lobby")
 check(game.lobby_character.disabled,"Normal player cannot bypass life type through character picker")
 game.send_chat("God");check(not game.god_mode,"Lobby command cannot unlock match editor")
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();await frames()
 game.show_pause();check(game.screen.find_child("PauseGameTypeSettings",true,false)==null,"Pause menu hides trait editor while locked")
 game.resume_game();game.prefs.values.chat=false;var previous=game.messages.size();game.send_chat(" God ");await frames()
 check(game.god_mode and game.can_edit_match_traits(),"Case-insensitive God command unlocks host even with chat display off")
 check(not game.ranked.eligible,"Editor-enabled match does not update rating")
 check(game.messages.back().begins_with("GOD MODE ON"),"Command produces local confirmation instead of chat broadcast")
 game.show_pause();await frames();check(game.screen.find_child("PauseGameTypeSettings",true,false)!=null,"Unlocked pause exposes traits/bots/weapons")
 game.open_game_type_settings();await frames();check(is_instance_valid(game.game_type_editor),"Unlocked editor opens")
 check(game.game_type_editor.weapon_controls.size()>=13 and game.game_type_editor.controls.has("naki_shield_capacity") and game.game_type_editor.controls.has("annu_body_armor") and game.game_type_editor.controls.has("bot_difficulty"),"All damage, defenses and bot controls remain available to God host")
 game.pending_game_type=GameTypeSettings.new();game.send_chat(":god");await frames()
 check(not game.god_mode and game.pending_game_type==null and not is_instance_valid(game.game_type_editor),"Second command locks editor and discards unapplied changes")
 game.send_chat("goddess");check(not game.god_mode,"Partial word is not a God command")
 game.matchmaking.active=true;game.send_chat("God");check(not game.god_mode,"Matchmaking cannot be unlocked by command");game.matchmaking.active=false
 game.stop_game();game.show_lobby();await frames()
 var signatures=[]
 for mode in NestMatchPresets.MODES:
  var rules=NestMatchPresets.create(mode,0,2)
  check(rules.mode==mode and rules.character_traits.is_empty() and rules.weapon_damage_percent.is_empty(),"Clean independent preset for "+str(mode))
  check(not rules.bots_fill_empty_slots,"Normal preset has no editable bot fills "+str(mode))
  check(rules.matchup==(3 if mode==0 else 2),"Preset life type enforced "+str(mode))
  signatures.append(str([rules.score_to_win,rules.time_limit_seconds,rules.teams_enabled,rules.lives_per_round,rules.mode]))
 check(signatures.size()==5 and signatures[0]!=signatures[1],"Five mode-specific presets exist")
 var vote=game.lobby_vote;check(vote.start(),"Host starts custom lobby vote")
 check(vote.state.stage=="map","Map is first vote")
 await frames()
 var panel=game.screen.find_child("LobbyVotePanel",true,false)
 check(panel!=null and panel.get_parent().get_children().filter(func(child):return child.visible).size()==1,"Active vote hides old preset controls after lobby filtering")
 var epoch=int(vote.state.epoch);check(not vote.record(99,epoch,0),"Nonmember vote rejected")
 vote.vote(1);check(vote.state.stage=="mode","All ballots advance to game type")
 check(not vote.record(1,epoch,2),"Stale-stage vote rejected")
 vote.vote(2);check(vote.state.stage=="life","Non-Extraction enters life vote")
 check(not vote.record(1,int(vote.state.epoch),3),"Cross-faction life ballot rejected")
 vote.vote(2);await frames();check(vote.complete() and game.mode==2 and game.matchup==2 and game.game_type.map_selection==1,"Resolved votes apply map, Team Deathmatch preset and Annu-only life")
 vote.start();vote.vote(0);vote.vote(0);await frames()
 check(vote.complete() and game.mode==0 and game.matchup==3,"Extraction skips life stage and uses Annu vs Naki")
 game.show_lobby();await frames();var life=game.screen.find_child("LobbyLifeType",true,false)
 check(life.disabled and life.item_count==1,"Extraction life selector is fixed")
 var random=RandomNumberGenerator.new();random.seed=77
 check(NestLobbyVote.winner([2,2,1],[1,2],3,random)==2,"Strict connected-player majority wins")
 check(NestLobbyVote.winner([1,2],[1,2],2,random) in [1,2],"No majority chooses valid random option")
 game.reference_mode_lobby(1,true);vote.start();vote.vote(0);vote.vote(1);vote.vote(1);await frames()
 check(game.bot_fill and game.team_size==2 and game.game_type.max_players==4,"Training retains fixed practice bots after voting")
 check(not game.can_edit_match_traits(),"Practice bots do not unlock bot menus automatically")
 game.close_connection();check(not game.god_mode,"Disconnect resets God access")
 game.queue_free();await frames(8);print("GOD & VOTE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
