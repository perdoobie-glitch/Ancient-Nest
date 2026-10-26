extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://motorcycle-route-qa.json";c.begin_solo(false);c.journey.start_standalone(2);await physics_frame
 var controller=c.journey.motorcycles;var actor=game.player;game.running=false
 actor.global_position=controller.bikes[1].position;controller.interact(actor,"bike:mount:1")
 var b=controller.bikes[1];var ticks=0;var last_sector=-1;var completed=false
 # A deterministic virtual rider follows the authored lane with ordinary
 # throttle/steering inputs. No position or course-progress injection occurs.
 while ticks<30000 and not b.crashed:
  var d=-actor.global_position.z
  var lookahead=clampf(float(b.speed)*.65,7,18)
  var ramp_index=maxi(0,roundi((d+lookahead-180)/240))
  var ramp_start=180.0+ramp_index*240.0
  var lane=-3.6 if ramp_index%2==0 else 3.6
  var influence=clampf(1.0-absf((d+lookahead)-(ramp_start+5))/58.0,0,1)
  var target=NestCampaignMotorcycleWorld.point(d+lookahead,lane*influence)
  var desired=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z))
  var steering=clampf(-wrapf(desired-float(b.heading),-PI,PI)*3.2,-1,1)
  var throttle=-1.0 if actor.is_on_floor() or float(b.airtime)<.04 else 0.0
  actor.movement_step(Vector2(steering,throttle),false,0,actor.rotation.y,1.0/60.0)
  game.now+=1.0/60.0;ticks+=1
  var sector=mini(5,floori(maxf(0,d)/NestCampaignMotorcycleWorld.SECTOR_LENGTH))
  if sector>last_sector:print("ROUTE sector ",sector+1," at ",ticks/60.0,"s distance ",d);last_sector=sector
  if controller.completed():completed=true;break
  if ticks%180==0:await physics_frame
 print("ROUTE result complete=",completed," distance=",b.distance," riding_seconds=",b.ride_seconds," jumps=",b.jumps," crashed=",b.crashed," position=",actor.global_position)
 if not completed:print("FAIL Six-sector riding route did not complete");failures+=1
 if int(b.jumps)<10:print("FAIL Marked jump traversal did not produce ten stable landings");failures+=1
 if completed and int(b.jumps)>=10:print("PASS Actual steering, ramp jumps, landings and all 7900m complete after at least300s riding")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
