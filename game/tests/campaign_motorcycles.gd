extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(value: bool,message: String):
 print(("PASS " if value else "FAIL ")+message)
 if not value:failures+=1
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://motorcycle-qa.json";c.begin_solo(false);c.journey.start_standalone(2);await physics_frame;await process_frame
 var bikes=c.journey.motorcycles;var actor=game.player;game.running=false
 check(bikes!=null and bikes.bikes.size()==4 and bikes.visuals.size()==4,"Exactly four physical motorcycle models / no companion riders")
 check(game.actors.filter(func(a):return a.faction==0).size()==1,"Solo retains exactly one existing Naki actor")
 check(not bikes.interact(actor,"bike:mount:2"),"Player cannot claim another expedition seat's machine")
 actor.global_position=bikes.bikes[1].position
 check(bikes.interact(actor,"bike:mount:1"),"Interact mounts the assigned motorcycle")
 check(bikes.interaction(actor).is_empty(),"Holding Interact after mounting cannot immediately dismount again")
 check(not actor.fire_trigger(),"Mounted rider cannot also fire a held weapon")
 actor.update_visual(1.0/60);actor.update_aim(1.0/60);actor.presentation.update_view(1.0/60)
 check(not actor.weapon_view.visible,"Visual and aim updates cannot re-show the rifle over the motorcycle cockpit")
 var top=NestCampaignMotorcycles.max_speed(actor)
 check(is_equal_approx(top,NestCampaignMotorcycles.normal_speed(actor)*4),"Top speed is exactly four times current ordinary ground speed")
 # Follow the actual clear center lane while testing basic acceleration.
 actor.global_position=NestCampaignMotorcycleWorld.point(20);bikes.bikes[1].heading=NestCampaignMotorcycleWorld.heading(20)
 for tick in range(150):
  var d=-actor.global_position.z;var target=NestCampaignMotorcycleWorld.point(d+10);var desired=atan2(-(target.x-actor.global_position.x),-(target.z-actor.global_position.z));var steer=clampf(-wrapf(desired-float(bikes.bikes[1].heading),-PI,PI)*3.2,-1,1)
  actor.movement_step(Vector2(steer,-1),false,0,0,1.0/60.0)
 check(float(bikes.bikes[1].speed)>top*.98,"Throttle reaches full 4x speed through real CharacterBody movement")
 var old_yaw=actor.rotation.y;var old_heading=float(bikes.bikes[1].heading)
 actor.movement_step(Vector2(.5,-1),false,0,0,1.0/60)
 check(is_equal_approx(actor.rotation.y-old_yaw,float(bikes.bikes[1].heading)-old_heading),"Steering carries the local camera heading while preserving mouse-look offset")
 check(not bikes.interact(actor,"bike:dismount:1"),"High speed dismount rejected; braking required")
 var recorded=float(bikes.bikes[1].ride_seconds)
 for tick in range(100):actor.movement_step(Vector2(0,1),false,0,0,1.0/60.0)
 check(float(bikes.bikes[1].speed)<.01,"Brake stops the motorcycle")
 var stationary=float(bikes.bikes[1].ride_seconds)
 for tick in range(30):actor.movement_step(Vector2.ZERO,false,0,0,1.0/60.0)
 check(is_equal_approx(stationary,float(bikes.bikes[1].ride_seconds)),"Idling cannot advance the five-minute active riding requirement")
 check(recorded>0,"Forward riding earns elapsed course time")
 check(bikes.interact(actor,"bike:dismount:1") and not bikes.handles(actor),"Stopped rider dismounts into normal on-foot movement")
 bikes.interact(actor,"bike:mount:1")
 var b=bikes.bikes[1];b.speed=top;b.pitch=1.3;b.airtime=.8
 for tick in range(12):
  actor.movement_step(Vector2.ZERO,false,0,0,1.0/60.0)
  if b.crashed:break
 check(b.crashed and not b.mounted,"Unbalanced landing throws rider and leaves recoverable overturned bike")
 check(not bikes.interact(actor,"bike:recover:1"),"Crash cannot be recovered before minimum exposure interval")
 game.now+=2
 check(bikes.interact(actor,"bike:recover:1") and not b.crashed,"Valid nearby recovery rights the bike without a new player")
 b.distance=NestCampaignMotorcycleWorld.ROAD_LENGTH;b.ride_seconds=299.9
 check(not bikes.completed(),"Finishing distance alone cannot skip the riding duration")
 b.ride_seconds=300
 check(bikes.completed(),"Course and full active riding time complete level two")
 b.distance=100;b.ride_seconds=350
 check(not bikes.completed(),"Elapsed time alone cannot finish the course")
 check(NestCampaignMotorcycleWorld.encounter_spawns(0).size()==8,"Each sector has authored Annu ambush positions")
 var at=NestCampaignMotorcycleWorld.point(180);var ramp=NestCampaignMotorcycleWorld.ramp_info(-at.z)
 check(not ramp.is_empty() and float(ramp.crest)>float(ramp.start),"Marked ramp has a physical approach and crest launch region")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
