extends SceneTree
var failures=0
var game
var campaign
var actor
var bikes
func _initialize():call_deferred("run")
func check(value: bool,message: String):
 print(("PASS " if value else "FAIL ")+message)
 if not value:failures+=1
func trial(distance: float,duck: bool,hop: bool) -> Dictionary:
 var b=bikes.bikes[1];b.mounted=false;b.crashed=false;b.duck=false;b.position=NestCampaignMotorcycleWorld.point(distance-24)+Vector3.UP*.25;b.heading=NestCampaignMotorcycleWorld.heading(distance-24);b.speed=0;b.pitch=0;b.airtime=0;b.jump_lock=0;b.last_ramp=-1
 actor.global_position=b.position;actor.controlled=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.reset_crouch();actor.alive=true;actor.health=100;actor.shield=100;campaign.downed.clear()
 bikes.interact(actor,"bike:mount:1")
 for i in range(20):actor.movement_step(Vector2.ZERO,false,1 if duck else 0,actor.rotation.y,1.0/60)
 b.speed=NestCampaignMotorcycles.max_speed(actor)
 var hopped=false;var lowered=false
 for i in range(210):
  var d=-actor.global_position.z;var at=NestCampaignMotorcycleWorld.point(d+7);var yaw=atan2(-(at.x-actor.global_position.x),-(at.z-actor.global_position.z));var turn=clampf(-wrapf(yaw-float(b.heading),-PI,PI)*5,-1,1)
  var gap=distance-d;var jump=hop and not hopped and gap<9 and gap>4
  var jumped=actor.movement_step(Vector2(turn,-1 if actor.is_on_floor() or b.airtime<.04 else 0),jump,1 if duck else 0,actor.rotation.y,1.0/60)
  if jumped and jump:hopped=true
  if duck and absf(gap)<2:lowered=actor.capsule.shape.height<=NestActor.CROUCH_HEIGHT+.01 and actor.eye.position.y<=NestActor.CROUCH_EYE_HEIGHT+.01 and b.duck
  if b.crashed or -actor.global_position.z>distance+9:break
 return {"crashed":bool(b.crashed),"passed":not b.crashed and -actor.global_position.z>distance+8,"lowered":lowered,"hopped":hopped,"position":actor.global_position}
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true;campaign=game.campaign;campaign.save_store.path="user://motorcycle-hazard-qa.json";campaign.begin_solo(false);campaign.journey.start_standalone(2);campaign.journey.finish_cinematic();await physics_frame;game.running=false
 actor=game.player;bikes=campaign.journey.motorcycles
 var standing=trial(300,false,false)
 check(standing.crashed,"Unducked rider physically collides with overhead branch and crashes")
 var ducking=trial(300,true,false)
 check(ducking.passed and ducking.lowered,"Crouch lowers physical head/capsule/camera and passes the same overhead branch")
 var grounded=trial(540,false,false)
 check(grounded.crashed,"Rider without jump physically hits the low timber")
 var jumping=trial(540,false,true)
 check(jumping.passed and jumping.hopped,"Timed hop clears the same low timber with ordinary movement physics")
 var uphill=trial(1020,false,true)
 check(uphill.passed,"Uphill hop carries slope momentum and clears the rising-ground branch")
 check(campaign.world.get_meta("road_dodge_tree_count",0)>=790,"At least ten times the former maximum79 actual road-trunk hazards")
 var b=bikes.bikes[1];b.mounted=false;b.crashed=false;b.position=NestCampaignMotorcycleWorld.point(130)+Vector3.UP*.25;actor.global_position=b.position;actor.reset_crouch();bikes.interact(actor,"bike:mount:1");b.speed=NestCampaignMotorcycles.max_speed(actor);b.heading=NestCampaignMotorcycleWorld.heading(130)
 for i in range(110):
  var d=-actor.global_position.z;var target=NestCampaignMotorcycleWorld.point(d+6);var yaw=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z));var steer=clampf(-wrapf(yaw-float(b.heading),-PI,PI)*5,-1,1)
  actor.movement_step(Vector2(steer,-1),false,0,actor.rotation.y,1.0/60)
  if b.crashed:break
 check(b.crashed,"Blind straight-center riding crashes into the new mandatory slalom trees")
 print("HAZARDS standing=",standing," duck=",ducking," grounded=",grounded," hop=",jumping," uphill=",uphill)
 campaign.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
