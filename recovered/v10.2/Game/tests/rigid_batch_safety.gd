extends SceneTree
func _initialize():call_deferred("run")
func geometry(root: Node3D) -> Dictionary:
 var triangles=0;var bounds=AABB();var first=true;var nodes=0
 for node in root.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null:continue
  nodes+=1
  var transform=Transform3D.IDENTITY;var cursor:Node3D=node
  while cursor!=root:transform=cursor.transform*transform;cursor=cursor.get_parent()
  var box=transform*node.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
  for surface in range(node.mesh.get_surface_count()):
   var arrays=node.mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices!=null and indices.size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
 return {"triangles":triangles,"bounds":bounds,"meshes":nodes}
func run():
 var removed=0;var checked=0
 for kind in ["rifle","ak47","burst_scoped","sidearm","sniper","shotgun","rocket","smg","plasma_br","plasma_auto","plasma_pistol","plasma_smg","plasma_sniper"]:
  var model=NestWeaponArt.create(kind,0);root.add_child(model)
  var animated=[]
  for node in model.find_children("*","Node3D",true,false):
   if NestRigidBatch.moving(String(node.name)):animated.append(node)
  var before=geometry(model);NestRigidBatch.build(model);var after=geometry(model)
  assert(before.triangles==after.triangles,"Lost weapon geometry: "+kind)
  assert(before.bounds.position.is_equal_approx(after.bounds.position) and before.bounds.size.is_equal_approx(after.bounds.size),"Changed weapon bounds: "+kind)
  for node in animated:assert(is_instance_valid(node) and node.is_inside_tree(),"Lost animated weapon part")
  removed+=before.meshes-after.meshes;checked+=1;model.queue_free();await process_frame
 var bird=NestFalconArt.create();root.add_child(bird);var before=geometry(bird);NestRigidBatch.build(bird);var after=geometry(bird)
 assert(before.triangles==after.triangles);assert(bird.has_node("WingLeft") and bird.has_node("WingRight"));NestFalconArt.animate(bird,1,true,.2);bird.queue_free()
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.bot_fill=false;game.start_game()
 var actor=game.player;var old_character=actor.character;actor.ray_exclusions();actor.set_character(1-old_character)
 var exclusions=actor.ray_exclusions();assert(exclusions.size()==actor.hitboxes.size()+1+(1 if actor.nu_perch_area!=null else 0))
 for area in actor.hitboxes:assert(area.get_rid() in exclusions)
 assert(actor.enemy_name_tag==null)
 print("PASS: ",checked," weapon models retain triangles/bounds/animated parts; ",removed," mesh draws merged; falcon wings animate; rebuilt model hitboxes refresh cached exclusions; no hidden world-name labels")
 game.stop_game();game.queue_free();for i in range(4):await process_frame
 quit()
