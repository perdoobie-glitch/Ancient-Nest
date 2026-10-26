extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func brute_blocked(world,p: Vector3) -> bool:
 for box in world.floor_cover:
  if box.position.y+box.size.y*.5<=.45 or box.position.y-box.size.y*.5>1.7:continue
  var d=p-box.position
  if absf(d.x)<box.size.x*.5+.55 and absf(d.z)<box.size.z*.5+.55:return true
 return false
func run():
 for setup in [["preparation",0],["forest",0],["preparation",2],["forest",2]]:
  var region=str(setup[0]);var world=NestCampaignWorld.new();world.region=region;world.quality=int(setup[1]);root.add_child(world);await process_frame
  print("SCENERY QUALITY "+str(setup[1]))
  var landscape=world.get_meta("landscape_stats",{})
  check(int(landscape.get("mountain_chunks",0))==36,region+": three complete mountain layers are built at every quality")
  check(int(landscape.get("structures",0))>=4,region+": modular structures preserve regional variety")
  check(world.ship_root.find_child("BoardingRamp",false,false)!=null,region+": continuous boarding/escape ramp is attached to the hull")
  if region=="forest":
   await physics_frame
   var ray=PhysicsRayQueryParameters3D.create(Vector3(168,2.4,0),Vector3(176,2.4,0),1)
   check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Tree trunk blocks shots/perception above the former low root collider")
  var rng=RandomNumberGenerator.new();rng.seed=1934;var equivalent=true
  for i in range(2500):
   var p=Vector3(rng.randf_range(-75,75),0,rng.randf_range(-75,75))
   if world.blocked_point(p)!=brute_blocked(world,p):equivalent=false
  check(equivalent,region+": spatial cover index matches exhaustive collision footprints (2500 points)")
  equivalent=true
  for i in range(world.nav_points.size()):
   for j in range(i):
    var expected=world.nav_points[i].distance_squared_to(world.nav_points[j])<=32.1 and world.segment_open(world.nav_points[i],world.nav_points[j])
    if world.nav_graph.are_points_connected(i,j)!=expected:equivalent=false
  check(equivalent,region+": neighbour graph matches every original pairwise edge")
  check(world.batch_stats.original_meshes>world.batch_stats.batches*2,region+": static scenery submission count reduced by over half")
  var collision_count=world.find_children("*","StaticBody3D",true,false).size()
  var before=world.ship_root.get_child(0).global_position;world.ship_root.position+=Vector3(3,2,-1)
  check(world.ship_root.get_child(0).global_position.is_equal_approx(before+Vector3(3,2,-1)),region+": batched expedition hull follows cinematic parent")
  check(world.find_children("*","StaticBody3D",true,false).size()==collision_count,region+": batching preserves collision bodies")
  if region=="forest":
   check(is_instance_valid(world.charge_mesh) and is_instance_valid(world.secure_mesh) and is_instance_valid(world.ancient_light),"Charge, locker and ending remain separate dynamic meshes")
   world.charge_mesh.visible=false;world.secure_mesh.visible=true;world.ancient_light.visible=true
   check(not world.charge_mesh.visible and world.secure_mesh.visible and world.ancient_light.visible,"Mission objects retain independent visibility")
  world.queue_free();await process_frame
 quit(1 if failures else 0)
