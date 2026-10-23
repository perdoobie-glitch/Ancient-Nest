extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for map in [0,1]:
  var rules=NestMatchPresets.create(2,map);game.apply_game_type_settings(rules);await physics_frame;await physics_frame
  for team in [0,1]:
   for p in game.arena.spawns[team]:
    var shape=CapsuleShape3D.new();shape.radius=NestActor.BODY_RADIUS+.03;shape.height=NestActor.STAND_HEIGHT
    var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*NestActor.STAND_CENTER)
    var hits=game.get_world_3d().direct_space_state.intersect_shape(query,10)
    var names=[]
    for hit in hits:names.append(str(hit.collider.name)+" / "+str(hit.collider.get_parent().name))
    print("SPAWN ",map," ",team," ",p," support ",game.arena.has_walk_support(p,.3)," hits ",names)
  print("OBJECTIVES ",map," sites ",game.arena.sites," flags ",game.arena.flag_positions)
 game.queue_free();await process_frame;quit()
