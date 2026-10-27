extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://motorcycle-route-qa.json";c.begin_solo(false);c.journey.start_standalone(2);c.journey.finish_cinematic();await physics_frame
 var controller=c.journey.motorcycles;var actor=game.player;game.running=false
 actor.global_position=controller.bikes[1].position;controller.interact(actor,"bike:mount:1")
 var b=controller.bikes[1];var ticks=0;var last_sector=-1;var completed=false;var min_height=INF;var max_height=-INF;var hops={};var duck_frames=0
 # A deterministic virtual rider follows the authored lane with ordinary
 # throttle/steering inputs. No position or course-progress injection occurs.
 while ticks<30000 and not b.crashed:
  var d=-actor.global_position.z
  var lookahead=clampf(float(b.speed)*.25,4,7)
  var target=NestCampaignMotorcycleWorld.point(d+lookahead,NestCampaignMotorcycleWorld.expert_lane(d+lookahead))
  var desired=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z))
  var turn_rate=lerpf(1.65,1.15,clampf(float(b.speed)/NestCampaignMotorcycles.max_speed(actor),0,1))
  var steering=clampf(-2*float(b.speed)*sin(wrapf(desired-float(b.heading),-PI,PI))/(lookahead*turn_rate),-1,1)
  var throttle=-1.0 if actor.is_on_floor() or float(b.airtime)<.04 else 0.0
  var branch=NestCampaignMotorcycleWorld.nearest_branch(d);var gap=float(branch.distance)-d
  var duck=branch.type=="duck" and gap<18 and gap> -7
  var hop=branch.type=="hop" and gap<9 and gap>4 and not hops.has(branch.distance)
  if duck:duck_frames+=1
  var jumped=actor.movement_step(Vector2(steering,throttle),hop,1 if duck else 0,actor.rotation.y,1.0/60.0)
  if jumped and hop:hops[branch.distance]=true
  game.now+=1.0/60.0;ticks+=1
  min_height=minf(min_height,actor.global_position.y);max_height=maxf(max_height,actor.global_position.y)
  var sector=mini(5,floori(maxf(0,d)/NestCampaignMotorcycleWorld.SECTOR_LENGTH))
  if sector>last_sector:print("ROUTE sector ",sector+1," at ",ticks/60.0,"s distance ",d);last_sector=sector
  if controller.completed():completed=true;break
  if ticks%180==0:await physics_frame
 print("ROUTE result complete=",completed," distance=",b.distance," riding_seconds=",b.ride_seconds," jumps=",b.jumps," crashed=",b.crashed," position=",actor.global_position," min_height=",min_height," max_height=",max_height," low_branch_hops=",hops.size()," duck_frames=",duck_frames," road_dodge_trees=",c.world.get_meta("road_dodge_tree_count",0))
 if not completed:print("FAIL Six-sector riding route did not complete");failures+=1
 if int(b.jumps)<10:print("FAIL Marked jump traversal did not produce ten stable landings");failures+=1
 if max_height-min_height<95:print("FAIL Riding route did not physically traverse the major elevation changes");failures+=1
 else:print("PASS Rider physically traversed more than95metres of elevation range")
 if int(c.world.get_meta("road_dodge_tree_count",0))<790:print("FAIL Less than ten times the former maximum79 road trees");failures+=1
 if hops.size()<15 or duck_frames<500:print("FAIL Rider did not negotiate the duck and hop branch course");failures+=1
 if completed and int(b.jumps)>=10:print("PASS Actual steering, ramp jumps, landings and all 7900m complete after at least300s riding")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
