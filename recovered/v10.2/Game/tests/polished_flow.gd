extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: ",message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 check(game.team_size==game.game_type.max_players_per_team and game.game_type.max_players==game.team_size*2,"Fresh lobby roster and rule capacities agree")
 var nav=game.screen.find_child("MainNavigation",true,false)
 check(nav.find_children("*","Button",true,false).size()==5,"Main menu has five primary choices")
 game.show_player_menu();await frames();check(game.current_screen=="player","Player actions remain accessible")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape);await frames();check(game.current_screen=="main","Escape returns from Player menu")
 for map in [0,1]:
  var rules=GameTypeSettings.new();rules.map_selection=map;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);await physics_frame
  var arena=game.arena
  check(arena.kit.restrained_architecture,"Reduced repeated trim on "+arena.map_title())
  var polish=arena.get_meta("map_polish",{})
  check(polish.get("flush_inlays",0)>0 and polish.get("collision_added",-1)==0,"Flush markers add no collision on "+arena.map_title())
  for team in arena.spawns:
   for spawn in arena.spawns[team]:
    var query=PhysicsShapeQueryParameters3D.new();var cap=CapsuleShape3D.new();cap.height=NestActor.STAND_HEIGHT;cap.radius=NestActor.BODY_RADIUS;query.shape=cap;query.transform=Transform3D(Basis.IDENTITY,spawn+Vector3.UP*NestActor.STAND_CENTER);query.collision_mask=1
    check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),arena.map_title()+" standing spawn clear "+str(spawn))
    for destination in arena.sites:check(not arena.route(spawn,destination).is_empty(),arena.map_title()+" spawn routes to objective")
  for mode in range(5):
   rules.mode=mode;game.apply_game_type_settings(rules);game.clear_screen();game.start_game();await frames()
   check(game.running and game.mode==mode and is_instance_valid(game.player),arena.map_title()+" mode "+str(mode)+" starts with valid player")
   if mode==2:
    var pending=game.game_type.duplicate_settings();pending.weapon_damage_percent["smg"]=75.0;game.apply_game_type_settings(pending)
    check(game.pending_game_type!=null and game.restart_round_in_match(),"Round restarts with pending rules on "+arena.map_title())
    check(is_equal_approx(game.game_type.weapon_damage_scale("smg"),.75),"Weapon setting survives restart on "+arena.map_title())
   game.stop_game();await frames();game.show_main()
 game.queue_free();await frames(6);print("POLISHED FLOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
