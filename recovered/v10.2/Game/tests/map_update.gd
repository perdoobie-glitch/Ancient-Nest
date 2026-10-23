extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func physics(n=2):
 for i in range(n):await physics_frame
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func floor_hit(pos: Vector3) -> Dictionary:return game.trace(pos+Vector3.UP*.5,pos-Vector3.UP*.6,1)
func capsule_clear(pos: Vector3) -> bool:
 var shape=CapsuleShape3D.new();shape.height=NestActor.STAND_HEIGHT;shape.radius=NestActor.BODY_RADIUS
 var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*NestActor.STAND_HEIGHT*.5)
 return game.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
func swept_route(path: Array[Vector3]) -> bool:
 if path.is_empty():return false
 var shape=CapsuleShape3D.new();shape.height=NestActor.STAND_HEIGHT;shape.radius=NestActor.BODY_RADIUS
 for index in range(path.size()-1):
  var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.margin=.005
  query.transform=Transform3D(Basis.IDENTITY,path[index]+Vector3.UP*(NestActor.STAND_HEIGHT*.5+.08));query.motion=path[index+1]-path[index]
  var result=game.get_world_3d().direct_space_state.cast_motion(query)
  if not result.is_empty() and result[0]<.99:
   print("Blocked route segment: ",path[index]," -> ",path[index+1]," at ",result)
   query.transform.origin+=query.motion*(result[1]+.01);query.motion=Vector3.ZERO
   for hit in game.get_world_3d().direct_space_state.intersect_shape(query):print("Blocker: ",hit.collider.get_path()," origin ",hit.collider.global_position)
   return false
 return true
func freeze():
 game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null
 await frames();var rules=GameTypeSettings.new();rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);await physics()
 var a=game.arena
 check(is_equal_approx(a.scale.x,.85*1.35) and is_equal_approx(a.scale.z,.85) and is_equal_approx(a.scale.y,.85),"Sanctuary is exactly 35% wider with original height/depth")
 check(a.cannon_routes.size()==4 and a.floor_surfaces.any(func(f):return f.pos.is_equal_approx(Vector3(0,0,-8.5)) and is_equal_approx(f.size.x,44*.85*1.35)),"Sanctuary has north concourse and a second rafter approach")
 check(a.spawns.values().all(func(list):return list.all(func(p):return not floor_hit(p).is_empty())),"All Sanctuary team spawns have solid floor support")
 check(a.spawns.values().all(func(list):return list.all(capsule_clear)),"Sanctuary spawn capsules fit without overlapping structures")
 var bodies=a.find_children("*","StaticBody3D",true,false)
 check(bodies.all(func(b):return b.global_basis.is_equal_approx(Basis.IDENTITY)),"Stretched static collision uses orthonormal physics bodies")
 var ramp=a.up_routes[0];check(a.has_walk_support(ramp.start.lerp(ramp.end,.5),.2),"Widened ramp metadata agrees with its physical route")
 var copy=GameTypeSettings.new();copy.apply_network_dict({"map_selection":99});check(copy.map_selection==1 and copy.map_name=="Crossroads","Map IDs validate to supported maps")
 rules=rules.duplicate_settings();rules.map_selection=1;rules.mode=4;rules.max_players_per_team=2;rules.bots_fill_empty_slots=true;rules.bots_team_0=1;rules.bots_team_1=2
 check(game.apply_game_type_settings(rules),"Host can select Crossroads and Bomb Defusal")
 await frames();await physics();a=game.arena
 check(a.map_selection==1 and a.map_title()=="Crossroads" and a.get_node_or_null("U2Lift")==null,"Selected tactical map builds independently of Sanctuary mechanisms")
 check(a.sites.size()==2 and a.sites[0].distance_to(a.sites[1])>35,"Crossroads has two separated bombsites")
 check(a.pads.size()==8 and a.pad_meshes.size()==a.pads.size() and a.pad_kinds.size()==a.pads.size(),"Tactical weapon placements and visuals remain aligned")
 check(a.spawns.values().all(func(list):return list.all(func(p):return not floor_hit(p).is_empty())),"All Crossroads spawns have solid floor support")
 check(a.spawns.values().all(func(list):return list.all(capsule_clear)),"Crossroads spawn capsules fit without overlapping structures")
 check(a.pads.all(func(p):return not floor_hit(p).is_empty()),"All Crossroads pickups have solid floor support")
 var spawn0: Vector3=a.spawns[0][0];var spawn1: Vector3=a.spawns[1][0]
 check(a.spawns[0].all(func(p):return a.spawns[1].all(func(q):return not game.trace(p+Vector3.UP*1.5,q+Vector3.UP*1.5,1).is_empty())),"Mid cover prevents a direct spawn-to-spawn shot")
 for site in a.sites:
  for team in [0,1]:check(not a.route(a.spawns[team][0],site).is_empty(),"Team %d has a connected walking route to site %d"%[team,a.sites.find(site)])
 for waypoint in [Vector3(-31,0,8),Vector3(-18,0,8),Vector3(0,0,12),Vector3(30,0,14),Vector3(15,0,-16)]:
  check(a.has_walk_support(waypoint*Vector3(.85,.85,.85*1.35),.1) and not a.route(spawn0,waypoint*Vector3(.85,.85,.85*1.35)).is_empty(),"Long/palace/mid/tunnel/connector route is supported: "+str(waypoint))
 game.show_lobby();await frames()
 check(game.screen.find_child("LobbyMap",true,false)!=null and game.MODE_NAMES[4]=="BOMB DEFUSAL","Lobby exposes both map selection and Bomb Defusal")
 game.open_game_type_settings();await frames();var editor=game.game_type_editor
 check(editor.controls.has("map_selection") and editor.controls.mode.get_item_text(4)=="Bomb Defusal","Unified rules editor exposes map and clearly named game type")
 editor.close_editor();await frames();game.start_game();freeze();await physics()
 check(a.deposits.all(func(n):return not n.get_node("Sealed").visible),"Bomb Defusal uses clear planting courts rather than solid ore props")
 check(game.mode==4 and game.actors.size()==4 and game.deadline-game.now<=120,"Tactical bomb mode starts with requested bots and two-minute limit")
 for site in a.sites:
  for team in [0,1]:check(swept_route(a.route(a.spawns[team][0],site+Vector3(0,0,2.5))),"Standing capsule clears physical route from team %d to site %d"%[team,a.sites.find(site)])
 var attacker=game.actors.filter(func(p):return p.is_attacker())[0];var defender=game.actors.filter(func(p):return not p.is_attacker())[0]
 check(attacker.damage_model()=="naki" and defender.damage_model()=="annu","Faction shields versus armor/health remain unchanged")
 for index in range(2):
  game.reset_round();freeze();game.cs_carrier=attacker.net_id
  attacker.global_position=a.sites[index]+Vector3(0,.08,2.5);attacker.reset_physics_interpolation();await physics()
  var choice=game.cs_interaction(attacker)
  check(not choice.is_empty() and choice.site==index and is_equal_approx(choice.seconds,3.2),"Site %d allows a 3.2 second plant"%index)
  if choice.is_empty():continue
  check(game.complete_cs_interaction(attacker,choice) and game.cs_planted() and is_equal_approx(game.site_states[index].bomb_at-game.now,40),"Site %d plant arms the forty-second fuse"%index)
  defender.global_position=a.sites[index]+Vector3(0,.08,2.5);await physics();choice=game.cs_interaction(defender)
  check(not choice.is_empty() and is_equal_approx(choice.seconds,10),"Site %d supports a ten-second defuse"%index)
  if not choice.is_empty():check(game.complete_cs_interaction(defender,choice),"Site %d defuse completes authoritatively"%index)
 game.reset_round();freeze();attacker.alive=false;attacker.respawn_at=game.now;game.now+=5
 check(not game.can_respawn(attacker) if game.has_method("can_respawn") else game.game_type.lives_per_round==1,"Bomb Defusal retains one life per round")
 var next=game.game_type.duplicate_settings();next.map_selection=0;game.apply_game_type_settings(next)
 check(game.arena.map_selection==1,"In-match map edits stay pending until round restart")
 check(game.restart_round_in_match() and game.arena.map_selection==0,"Round restart installs the selected map without ending the match")
 freeze();await physics();check(game.player.global_position.x<60 and not floor_hit(game.player.global_position).is_empty(),"Restarted player spawns on the widened map")
 game.stop_game();await frames();next=game.game_type.duplicate_settings();next.map_selection=1;game.apply_game_type_settings(next);await frames()
 var model=game.forge_session.ensure_map();await physics()
 check(model.arena.map_selection==1 and model.validate(model.capture()),"Crossroads supports Nest Forge with a map-specific valid layout")
 check(model.map_id()=="crossroads-v31-market2" and model.save_path().contains("crossroads"),"Nest Forge saves cannot be applied to the wrong base map")
 check(game.forge_session.save() and game.forge_session.load_saved(),"Crossroads Nest Forge layout saves and reloads")
 game.forge_session.clear();game.queue_free();await frames(8)
 print("MAP UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
