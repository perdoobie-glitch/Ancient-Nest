extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.current_screen="playing";game.context="playing"
 game.set_process(false);game.set_physics_process(false)
 for actor in game.actors:actor.set_physics_process(false)
 game.player.kills=7;game.scores.assign([23,12]);game.now=10;game.deadline=100
 var checks=0
 for mode in [0,1,2,3,4]:
  game.mode=mode;game.reference_hud.refresh()
  assert(game.reference_hud.left_name.text==("LEADER" if mode==1 else game.team_name(0).to_upper()))
  assert(game.reference_hud.right_name.text==("YOU" if mode==1 else game.team_name(1).to_upper()))
  assert(game.reference_hud.left_score.text==("7" if mode==1 else "23"))
  assert(game.reference_hud.right_score.text==("7" if mode==1 else "12"));checks+=4
 game.mode=1;game.kill_feed.assign([{"until":20.,"text":"Test elimination"}])
 game._process(1./120)
 assert(game.hud_feed.text=="Test elimination\n");checks+=1
 game.player.alive=false;game.player.death_recap={"killer":"Test opponent"};game.player.respawn_at=12
 game._process(1./120)
 assert(game.hud_death.text=="KILLED BY\nTest opponent")
 assert(game.hud_death_status.text=="Respawn in 2.0");checks+=2
 game.kill_feed.clear();game.player.alive=true;game.player.death_recap.clear();game._process(1./120)
 assert(game.hud_feed.text=="" and game.hud_death.text=="" and game.hud_death_status.text=="");checks+=1
 assert(not game.hud_top.visible and not game.hud_weapon.visible and game.reference_hud.visible);checks+=1
 print("HUD REFRESH: ",checks," checks passed")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit()
