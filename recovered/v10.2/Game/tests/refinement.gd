extends SceneTree
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 checks+=1
 if not value:failures+=1;push_error(label)
 else:print("PASS "+label)
func run():
 check(NestMatchPresets.create(1).score_to_win==21,"ISO preset 21")
 check(NestMatchPresets.create(2).score_to_win==42,"TDM preset 42")
 check(NestGameTypeLibrary.load_type("builtin:1").score_to_win==21 and NestGameTypeLibrary.load_type("builtin:2").score_to_win==42,"Custom lobby built-in score presets")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.mode=2;game.start_game();game.set_process(false);game.set_physics_process(false)
 for actor in game.actors:actor.set_physics_process(false)
 var player=game.player
 game.tuning.score_limit=42;game.scores[0]=40;game.scores[1]=0;player.faction=0
 game.register_kill(player,player,"test");check(not game.finished and game.scores[0]==41,"TDM continues at 41")
 game.register_kill(player,player,"test");check(game.finished,"TDM ends at 42")
 game.finished=false;game.mode=1;game.tuning.score_limit=21;game.scores[0]=0;game.scores[1]=0;player.kills=20
 game.register_kill(player,player,"test");check(not game.finished,"ISO continues at 20")
 player.kills=21;game.register_kill(player,player,"test");check(game.finished,"ISO ends at 21")
 game.bomb_impact(Vector3.ZERO)
 var effect=game.effects.get_child(game.effects.get_child_count()-1)
 check(effect.scale.is_equal_approx(Vector3.ONE*10),"Objective explosion visual scale 10x")
 var normal=NestBlastFX.new();game.effects.add_child(normal)
 check(normal.scale.is_equal_approx(Vector3.ONE),"Ordinary explosion unchanged")
 check(effect.smoke.size()==normal.smoke.size() and effect.fragments.size()==normal.fragments.size(),"Explosion particle budget unchanged")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_manifest.json"))
 check(manifest.sounds.bomb_armed_tick.spatial and manifest.sounds.bomb_armed_tick.max_distance==48,"Bomb beeps distance attenuated")
 for key in ["drill_commencing","drill_complete","bomb_ten_seconds","bomb_five_seconds"]:
  check(ResourceLoader.load(manifest.sounds["announcer_"+key].files[0]) is AudioStream,"Voice exists: "+key)
 var movement=NestBotMovement.new(player);player.health=player.tuning.health_capacity*.2
 check(movement.vulnerable(),"Low health triggers defensive movement")
 player.health=player.tuning.health_capacity;player.shield=player.tuning.shield_capacity
 check(not movement.vulnerable(),"Healthy bot stays aggressive")
 game.finished=false;game.mode=game.MODE_CS;game.break_until=0
 game.site_states[0].stage="planted";game.site_states[0].bomb_at=game.now+40;game.bomb_site=0;game.attacking_faction=1
 player.faction=0;player.net_id=1;player.global_position=game.arena.sites[0]+Vector3(-2,0,0)
 var bot=NestActor.new();bot.game=game;bot.faction=0;bot.net_id=2;game.add_child(bot);game.actors.append(bot);bot.respawn();bot.set_physics_process(false);bot.global_position=player.global_position+Vector3(6,0,0)
 check(game.nearest_objective_actor(player,game.arena.sites[0]) and not game.nearest_objective_actor(bot,game.arena.sites[0]),"Closest defender assigned defuse")
 check(game.cs_bot_goal(player).distance_to(game.cs_bot_goal(bot))>2,"Other defender holds separate guard position")
 game.game_type.weapon_pickups=false
 for x in [-2.5,0,2.5]:
  for z in [-2.5,0,2.5]:
   player.global_position=game.arena.sites[0]+Vector3(x,0,z)
   if not game.cs_interaction(player).is_empty():break
  if not game.cs_interaction(player).is_empty():break
 var holder=NestBotMovement.new(player)
 check(holder.holding_objective(),"Defuser recognizes objective hold")
 check(holder.update(.016).move==Vector2.ZERO,"Defuser stands still to finish interaction")
 game.game_type.bots_stand_still=true;game.game_type.bots_dont_shoot=true
 var before=bot.ammo[bot.slot];var intent=bot.bot_intent(.016)
 check(intent.move==Vector2.ZERO and bot.ammo[bot.slot]==before,"Standstill and do-not-shoot toggles preserved")
 game.queue_free();await process_frame;await process_frame
 print("REFINEMENT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
