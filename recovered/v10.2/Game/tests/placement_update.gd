extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func wait():
 await physics_frame;await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for map in [0,1]:
  var rules=NestMatchPresets.create(0,map);game.apply_game_type_settings(rules);await wait()
  check(NestPlacementSafety.prepare(game),"Both-team / objective placement prepared on map "+str(map))
  print("REPAIRS map ",map," ",game.arena.get_meta("placement_repairs")," SPAWNS ",game.arena.spawns)
  await wait()
  for team in [0,1]:
   for point in game.arena.spawns[team]:
    check(NestPlacementSafety.ground(game,point,NestActor.BODY_RADIUS+.05).is_finite(),"Spawn has supported footprint")
    check(NestPlacementSafety.clear(game,point,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT),"Standing spawn volume is clear")
  for i in range(2):
   var exclude: Array[RID]=[]
   for body in game.arena.deposits[i].find_children("*","StaticBody3D",true,false):exclude.append(body.get_rid())
   var point=game.arena.sites[i]+Vector3.UP*.045
   check(NestPlacementSafety.clear(game,point,1.3,2.6,exclude,true),"Mine / bomb site clear of other structures")
   check(NestPlacementSafety.ground(game,point,1.3,exclude).is_finite(),"Mine / bomb site on actual floor")
   check(NestPlacementSafety.clear(game,game.flag_bases[i],.8,2.5),"Flag clear of walls / structures")
  # A new full-height structure blocks an otherwise-valid spawn.
  var original: Vector3=game.arena.spawns[0][0]
  var wall=StaticBody3D.new();wall.collision_layer=1;var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,4,2);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.global_position=original+Vector3.UP*1.9
  await wait()
  check(not NestPlacementSafety.clear(game,original,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT),"Inserted structure blocks original spawn")
  var repaired=NestPlacementSafety.find(game,original,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT)
  check(repaired.is_finite() and repaired.distance_to(original)>1,"Blocked spawn relocated")
  check(absf(repaired.y-original.y)<.2,"Repair retains original floor")
  check(NestPlacementSafety.clear(game,repaired,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT),"Repaired spawn is outside collision")
  var roof=original+Vector3.UP*45
  check(not NestPlacementSafety.ground(game,roof,.5).is_finite(),"Roof / sky marker rejected")
  var safe=NestPlacementSafety.find(game,roof,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT)
  check(safe.is_finite() and game.arena.has_walk_support(safe,.2),"Invalid roof marker falls back to supported playable floor")
  var drop=NestPlacementSafety.dropped(game,wall.global_position,.3,.65,original)
  check(drop.is_finite() and NestPlacementSafety.clear(game,drop,.3,.65),"Dropped bomb avoids structure volume")
  check(game.arena.has_walk_support(drop,.2),"Dropped bomb avoids nonplayable roof")
  game.arena.sites[0]=original;game.flag_bases[0]=original
  check(NestPlacementSafety.prepare(game),"Obstructed mine and flag anchors repair successfully")
  await wait()
  var own: Array[RID]=[]
  for body in game.arena.deposits[0].find_children("*","StaticBody3D",true,false):own.append(body.get_rid())
  check(NestPlacementSafety.clear(game,game.arena.sites[0]+Vector3.UP*.045,1.3,2.6,own,true),"Relocated mine is outside structure")
  check(NestPlacementSafety.clear(game,game.flag_bases[0],.8,2.5),"Relocated flag is outside structure and mine")
  check(game.arena.sites[0].distance_to(game.flag_bases[0])>1.8,"Mine and flag reserve separate objective spaces")
  wall.queue_free();await wait()
 game.game_type=NestMatchPresets.create(2,1);game.mode=2;game.bot_fill=true;game.team_size=5;game.game_type.bots_team_0=4;game.game_type.bots_team_1=5;game.start_game();game.set_physics_process(false)
 check(game.actors.size()==10,"Full 5v5 practice roster is present")
 for actor in game.actors:actor.set_physics_process(false)
 await wait()
 for actor in game.actors:
  check(actor.alive and actor.global_position.is_finite(),"Ten-player start places each human / bot")
  check(NestPlacementSafety.clear(game,actor.global_position,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT),"Actual respawn clear of world")
  for other in game.actors:
   if other.net_id<=actor.net_id:continue
   check(absf(actor.global_position.y-other.global_position.y)>NestActor.STAND_HEIGHT or Vector2(actor.global_position.x-other.global_position.x,actor.global_position.z-other.global_position.z).length()>NestActor.BODY_RADIUS*2,"Players do not share spawn volume")
 for cycle in range(3):
  for actor in game.actors:
   actor.respawn()
   check(actor.alive and actor.placement_retry_at==0,"Repeated respawn succeeds")
   check(NestPlacementSafety.clear(game,actor.global_position,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT) and game.arena.has_walk_support(actor.global_position,.2),"Repeated respawn has ground and body clearance")
 game.stop_game()
 for map in [0,1]:
  game.apply_game_type_settings(NestMatchPresets.create(2,map));game.bot_fill=false;game.mode=2;game.start_game();game.set_physics_process(false);game.player.set_physics_process(false)
  check(game.player.alive and game.player.placement_retry_at==0,"Fresh map can spawn immediately without waiting for physics")
  await wait()
  check(NestPlacementSafety.clear(game,game.player.global_position,NestActor.BODY_RADIUS+.05,NestActor.STAND_HEIGHT),"Fresh map first spawn remains clear after physics settles")
  game.stop_game()
 game.queue_free();await create_timer(.3).timeout
 print("PLACEMENT UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
