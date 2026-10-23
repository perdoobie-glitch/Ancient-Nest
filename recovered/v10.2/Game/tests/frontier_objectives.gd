extends SceneTree
var game
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String) -> void:
 checks+=1
 assert(ok,text)
func start(mode: int,map: int) -> void:
 if game.running:game.stop_game();await process_frame
 var rules=NestMatchPresets.create(mode,map,1);rules.bots_fill_empty_slots=true;rules.bots_team_0=4;rules.bots_team_1=5
 game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.context="playing";game.current_screen="playing"
 game.set_process(false);game.set_physics_process(false)
 for actor in game.actors:actor.set_process(false);actor.set_physics_process(false)
 for i in range(3):await physics_frame
 check(game.actors.size()==10,"Ten actors in objective fixture")
func move(actor,p: Vector3) -> void:
 actor.global_position=p+Vector3(0,.08,0);actor.velocity=Vector3.ZERO;actor.controlled=Vector3.ZERO;actor.reset_physics_interpolation()
 await physics_frame;await physics_frame
func action(actor,prefix: String) -> Dictionary:
 var choice=game.interaction_for(actor);check(not choice.is_empty() and str(choice.key).begins_with(prefix),"Expected "+prefix+", got "+str(choice))
 check(game.complete_interaction(actor,choice),"Objective action failed "+prefix);return choice
func run():
 Engine.max_fps=60;game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for map in [3,4,5]:
  for site in [0,1]:
   await start(4,map);var attacker=game.player;var defender=game.actors.filter(func(a):return a.faction==1)[0]
   game.cs_carrier=attacker.net_id;attacker.bomb_equipped=true;attacker.action_state="ready"
   await move(attacker,game.arena.sites[site]+Vector3(-2.6,0,0));action(attacker,"cs_plant:")
   check(game.cs_planted() and game.bomb_site==site,"Bomb planted at intended site")
   var snapshot=bytes_to_var(NestMigrationState.pack(game));check(NestMigrationState.valid(snapshot,game.NETWORK_VERSION),"New-map planted bomb checkpoint valid")
   check(snapshot.config.game_type.map_selection==map,"Checkpoint retains new map")
   await move(defender,game.arena.sites[site]+Vector3(2.6,0,0));action(defender,"defuse:")
   check(game.site_states[site].stage=="defused" and game.scores[1]==1,"Defuse scores correctly")
   print("OBJECTIVE_PASS ",NestArena.MAP_NAMES[map]," Bomb plant/defuse + migration state at site ",site)
   await start(0,map);attacker=game.player;await move(attacker,game.arena.sites[site]+Vector3(-2.6,0,0));action(attacker,"plant:")
   game.now=float(game.site_states[site].bomb_at)+.01;game.update_objectives(.01);check(game.site_states[site].stage=="off","Extraction blast opens deposit")
   action(attacker,"activate:");game.now=float(game.site_states[site].start_at)+.01;game.update_objectives(.01)
   game.site_states[site].work=game.tuning.drill_seconds;game.update_objectives(.01);check(game.site_states[site].stage=="complete","Drill completes")
   action(attacker,"load:");check(attacker.carrying,"Gold loaded")
   game.drop_bag(attacker);check(not attacker.carrying and game.bags.size()==1,"Gold drops to supported location")
   var bag=game.bags.values()[0];check(game.arena.has_walk_support(bag.position,.7),"Dropped gold supported")
   await move(attacker,bag.position);action(attacker,"recover:");check(attacker.carrying,"Dropped gold recovers")
   await move(attacker,game.arena.ship_position);action(attacker,"deliver");check(not attacker.carrying and game.delivered_bags==1,"Gold delivers at reachable berth")
   print("OBJECTIVE_PASS ",NestArena.MAP_NAMES[map]," Extraction open/drill/load/drop/recover/deliver at site ",site)
  await start(3,map);var actor=game.player;check(game.tuning.score_limit==3,"Flag target remains three")
  for capture in range(3):
   await move(actor,game.flag_bases[1]);game.update_ctf();check(actor.flag_carry==1,"Enemy flag taken")
   if capture==0:
    await move(actor,game.arena.nav_points[game.arena.nearest_nav(Vector3.ZERO)]);game.drop_flag(actor)
    check(game.flags[1].state=="dropped","Flag drops")
    check(game.arena.has_walk_support(game.flags[1].pos,.8),"Flag drops on supported ground")
    await move(actor,game.flags[1].pos);game.update_ctf();check(actor.flag_carry==1,"Flag recovers")
   await move(actor,game.flag_bases[0]);game.update_ctf();check(game.scores[0]==capture+1,"Capture counts")
  check(game.finished,"Three captures finish match")
  print("OBJECTIVE_PASS ",NestArena.MAP_NAMES[map]," CTF take/drop/recover/three captures/game over")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;print("FRONTIER OBJECTIVES: ",checks," checks passed");quit()
