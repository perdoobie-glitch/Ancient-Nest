extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func run():
 check(NestRatingProfile.kd_percent(3,1)==75 and NestRatingProfile.kd_percent(1,1)==50 and NestRatingProfile.kd_percent(0,0)==0,"KD percentage is bounded and handles zero deaths")
 check(NestRatingProfile.elo_after(1200,1200,1)==1216 and NestRatingProfile.elo_after(1200,1200,0)==1184 and NestRatingProfile.elo_after(1200,1200,.5)==1200,"Chess-style equal-rating win, loss and draw")
 check(NestRatingProfile.elo_after(1000,1800,1)>NestRatingProfile.elo_after(1000,1000,1),"Upsets award more Elo")
 check(NestRatingProfile.elo_after(3200,3200,1)==3200 and NestRatingProfile.elo_after(0,0,0)==0,"Elo cannot exceed 3200 or fall below zero")
 for number in range(1,22):
  var rank=NestRatingProfile.rank_for((number-1)*150)
  check(rank.number==number and rank.group==(number-1)/3 and rank.tier==(number-1)%3+1,"Rank boundary "+str(number)+" has correct group and tier")
 check(NestRatingProfile.rank_for(3200).number==21 and NestRatingProfile.rank_for(3200).progress==1,"Top rating is completed tier 21")
 var profile=NestRatingProfile.new();check(profile.data.human.elo==0 and profile.data.practice.elo==0 and NestRatingProfile.rank_for(profile.data.human.elo).number==1,"Both new ratings start at Forgebound I, rank 1, zero Elo")
 check(profile.apply_result("test-win","practice",{"before":0,"after":16,"score":1,"kills":3,"deaths":1}),"Completed result persists")
 check(profile.data.practice.elo==16 and profile.data.human.elo==0 and profile.data.practice.kills==3,"Human and practice ratings remain separate")
 check(not profile.apply_result("test-win","practice",{"before":16,"after":32,"score":1,"kills":3,"deaths":1}),"Duplicate result token cannot award twice")
 var loaded=NestRatingProfile.new();loaded.load_data();check(loaded.data.practice.elo==16 and loaded.data.practice.games==1,"Rating and deduplication history survive restart")
 check(not loaded.apply_result("bad","human",{"before":1200,"after":3200,"score":1,"kills":0,"deaths":0}),"Oversized or forged delta rejected")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.show_player_menu()
 check(game.screen.find_children("*","Button",true,false).any(func(b):return b.text=="Service Card"),"Player submenu exposes server service card")
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=true;rules.max_players_per_team=1;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
 check(not game.ranked.eligible,"Custom game with bots is unranked")
 var before=game.ranked.profile.data.practice.elo;game.player.kills=4;game.player.deaths=2;game.scores.assign([3,1]);game.finish_match()
 check(game.ranked.profile.data.practice.elo==before and game.ranked.profile.data.human.elo==0,"Custom win changes neither practice nor human Elo")
 check(game.ranked.profile.data.practice.kills==3,"Custom kills do not enter persistent ranked statistics")
 check(not game.ranked.accept({"token":game.ranked.token,"channel":game.ranked.channel,"eligible":true,"rows":[]}),"Host packets cannot grant custom ranked eligibility")
 check(game.ranked.result_text().contains("CUSTOM GAME") and game.ranked.result_text().contains("UNRANKED"),"Custom results explicitly explain that ranks do not change")
 var after=game.ranked.profile.data.practice.elo;game.finish_match();check(game.ranked.profile.data.practice.elo==after,"Repeated finish_match does not award another rating")
 game.stop_game();game.start_game();game.set_physics_process(false);game.context="pause"
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
 game.scores.assign([0,2]);before=game.ranked.profile.data.practice.elo;game.finish_match();check(game.ranked.profile.data.practice.elo==before,"Custom loss leaves Elo unchanged")
 game.stop_game();game.bot_fill=false;game.start_game();game.set_physics_process(false);check(not game.ranked.eligible,"Solo match is unrated");game.stop_game()
 game.sandbox_mode=true;game.bot_fill=true;game.start_game();game.set_physics_process(false);check(not game.ranked.eligible,"Nest Forge sandbox cannot earn Elo");game.stop_game();game.sandbox_mode=false
 game.show_rating();check(is_instance_valid(game.accounts.service_dialog) and game.find_child("LearnMyMoves",true,false)==null,"Legacy rating entry opens server service card")
 game.show_main();game.queue_free();await create_timer(.12).timeout;print("RATING: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
